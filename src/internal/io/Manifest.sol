// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../errors/Errors.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";
import {Paths} from "../utils/Paths.sol";
import {StringUtils} from "../utils/StringUtils.sol";
import {HexUtils} from "../utils/HexUtils.sol";

/// @title ManifestIO
/// @notice JSON I/O for `.diamond-upgrades/<name>.manifest.json` (current chain slice only).
library ManifestIO {
    using stdJson for string;

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct SelectorSnapshot { bytes4 selector; address facet; }
    struct FacetSnapshot { string artifact; address facet; bytes32 runtimeBytecodeHash; bytes4[] selectors; }
    struct BytecodeCacheEntry { bytes32 hash; address facet; }

    enum NamespaceStatus { Active, Deprecated, Replaced }
    struct NamespaceState {
        string namespaceId; bytes32 layoutHash; uint256 fieldsCount; NamespaceStatus status; string supersededBy;
    }

    struct HistoryEntry { bytes32 txHash; uint256 timestamp; uint256 addCount; uint256 replaceCount; uint256 removeCount; }

    struct ChainState {
        uint256 chainId;
        address diamond;
        SelectorSnapshot[] selectors;
        FacetSnapshot[] facets;
        BytecodeCacheEntry[] bytecodeCache;
        NamespaceState[] namespaces;
        HistoryEntry[] history;
        bytes32 stateHash;
    }

    struct Manifest { string name; ChainState state; }

    // ── Load (expects our save format) ──────────────────────────────────────────
    function load(string memory name) internal view returns (Manifest memory m) {
        string memory path = Paths.manifestJson(name);
        string memory raw;
        try VM.readFile(path) returns (string memory data) { raw = data; }
        catch { revert Errors.ManifestNotFound(name, block.chainid); }

        m.name = raw.readString(".name");

        // Find chain idx matching current chainId (iterate with try/catch)
        uint256 idx = type(uint256).max;
        for (uint256 i = 0; ; i++) {
            string memory chainBase = string.concat(".chains[", StringUtils.toString(i), "]");
            uint256 chainId;
            try VM.parseJsonUint(raw, string.concat(chainBase, ".chainId")) returns (uint256 cId) {
                chainId = cId;
            } catch {
                break; // No more chains
            }
            if (chainId == block.chainid) { idx = i; break; }
        }
        if (idx == type(uint256).max) revert Errors.ManifestNotFound(name, block.chainid);
        string memory base = string.concat(".chains[", StringUtils.toString(idx), "]");

        ChainState memory s;
        s.chainId = raw.readUint(string.concat(base, ".chainId"));
        s.diamond = raw.readAddress(string.concat(base, ".diamond"));

        // selectors (iterate with try/catch)
        SelectorSnapshot[] memory selectors = new SelectorSnapshot[](0);
        for (uint256 i2 = 0; ; i2++) {
            string memory sb = string.concat(base, ".selectors[", StringUtils.toString(i2), "]");
            bytes32 sel32;
            address facet;
            try VM.parseJsonBytes32(raw, string.concat(sb, ".selector")) returns (bytes32 s32) {
                sel32 = s32;
                facet = VM.parseJsonAddress(raw, string.concat(sb, ".facet"));
            } catch {
                break; // No more selectors
            }
            selectors = _appendSelector(selectors, SelectorSnapshot({selector: bytes4(sel32), facet: facet}));
        }
        s.selectors = selectors;

        // facets (iterate with try/catch)
        FacetSnapshot[] memory facets = new FacetSnapshot[](0);
        for (uint256 f = 0; ; f++) {
            string memory fb = string.concat(base, ".facets[", StringUtils.toString(f), "]");
            FacetSnapshot memory fs;
            try VM.parseJsonString(raw, string.concat(fb, ".artifact")) returns (string memory artifact) {
                fs.artifact = artifact;
                fs.facet = VM.parseJsonAddress(raw, string.concat(fb, ".facet"));
                fs.runtimeBytecodeHash = VM.parseJsonBytes32(raw, string.concat(fb, ".runtimeBytecodeHash"));
            } catch {
                break; // No more facets
            }

            // facet selectors (iterate with try/catch)
            bytes4[] memory fsSelectors = new bytes4[](0);
            for (uint256 j = 0; ; j++) {
                bytes32 b32;
                try VM.parseJsonBytes32(raw, string.concat(fb, ".selectors[", StringUtils.toString(j), "]")) returns (bytes32 sel32) {
                    b32 = sel32;
                } catch {
                    break; // No more selectors
                }
                fsSelectors = _appendBytes4(fsSelectors, bytes4(b32));
            }
            fs.selectors = fsSelectors;
            facets = _appendFacet(facets, fs);
        }
        s.facets = facets;

        // bytecodeCache (iterate with try/catch)
        BytecodeCacheEntry[] memory bytecodeCache = new BytecodeCacheEntry[](0);
        for (uint256 c = 0; ; c++) {
            string memory cb = string.concat(base, ".bytecodeCache[", StringUtils.toString(c), "]");
            bytes32 hash;
            address facet;
            try VM.parseJsonBytes32(raw, string.concat(cb, ".hash")) returns (bytes32 h) {
                hash = h;
                facet = VM.parseJsonAddress(raw, string.concat(cb, ".facet"));
            } catch {
                break; // No more entries
            }
            bytecodeCache = _appendBytecode(bytecodeCache, BytecodeCacheEntry({hash: hash, facet: facet}));
        }
        s.bytecodeCache = bytecodeCache;

        // namespaces (iterate with try/catch)
        NamespaceState[] memory namespaces = new NamespaceState[](0);
        for (uint256 n = 0; ; n++) {
            string memory nb = string.concat(base, ".namespaces[", StringUtils.toString(n), "]");
            NamespaceState memory ns;
            try VM.parseJsonString(raw, string.concat(nb, ".namespaceId")) returns (string memory nsId) {
                ns.namespaceId = nsId;
                ns.layoutHash = VM.parseJsonBytes32(raw, string.concat(nb, ".layoutHash"));
                ns.fieldsCount = VM.parseJsonUint(raw, string.concat(nb, ".fieldsCount"));
                ns.status = NamespaceStatus(VM.parseJsonUint(raw, string.concat(nb, ".status")));
                ns.supersededBy = VM.parseJsonString(raw, string.concat(nb, ".supersededBy"));
            } catch {
                break; // No more namespaces
            }
            namespaces = _appendNamespace(namespaces, ns);
        }
        s.namespaces = namespaces;

        // history (iterate with try/catch)
        HistoryEntry[] memory history = new HistoryEntry[](0);
        for (uint256 h = 0; ; h++) {
            string memory hb = string.concat(base, ".history[", StringUtils.toString(h), "]");
            HistoryEntry memory he;
            try VM.parseJsonBytes32(raw, string.concat(hb, ".txHash")) returns (bytes32 txHash) {
                he.txHash = txHash;
                he.timestamp = VM.parseJsonUint(raw, string.concat(hb, ".timestamp"));
                he.addCount = VM.parseJsonUint(raw, string.concat(hb, ".addCount"));
                he.replaceCount = VM.parseJsonUint(raw, string.concat(hb, ".replaceCount"));
                he.removeCount = VM.parseJsonUint(raw, string.concat(hb, ".removeCount"));
            } catch {
                break; // No more history entries
            }
            history = _appendHistory(history, he);
        }
        s.history = history;

        s.stateHash = raw.readBytes32(string.concat(base, ".stateHash"));
        m.state = s;
    }

    // ── Save (light pretty JSON build) ──────────────────────────────────────────
    function save(Manifest memory m) internal {
        string memory path = Paths.manifestJson(m.name);

        string memory json = string.concat(
            "{\n",
            "  \"name\": \"", m.name, "\",\n",
            "  \"chains\": [\n",
            "    ", _chainJsonCompact(m.state), "\n",
            "  ]\n",
            "}"
        );

        // Note: Используем light pretty formatting для избежания OOG на больших манифестах
        VM.writeFile(path, json);
    }

    // ── Helpers ─────────────────────────────────────────────────────────────────
    function ownerOf(ChainState memory s, bytes4 selector) internal pure returns (address) {
        for (uint256 i = 0; i < s.selectors.length; i++) if (s.selectors[i].selector == selector) return s.selectors[i].facet;
        return address(0);
    }
    function findFacetByArtifact(ChainState memory s, string memory artifact) internal pure returns (bool, uint256) {
        bytes32 k;
        assembly {
            k := keccak256(add(artifact, 0x20), mload(artifact))
        }
        for (uint256 i = 0; i < s.facets.length; i++) if (keccak256(bytes(s.facets[i].artifact)) == k) return (true, i);
        return (false, 0);
    }
    function resolveFacetByHash(ChainState memory s, bytes32 runtimeHash) internal pure returns (address) {
        for (uint256 i = 0; i < s.bytecodeCache.length; i++) if (s.bytecodeCache[i].hash == runtimeHash) return s.bytecodeCache[i].facet;
        return address(0);
    }
    function findNamespace(ChainState memory s, string memory nsId) internal pure returns (bool, uint256) {
        bytes32 k;
        assembly {
            k := keccak256(add(nsId, 0x20), mload(nsId))
        }
        for (uint256 i = 0; i < s.namespaces.length; i++) if (keccak256(bytes(s.namespaces[i].namespaceId)) == k) return (true, i);
        return (false, 0);
    }

    function computeStateHash(ChainState memory s) internal pure returns (bytes32) {
        bytes memory acc = abi.encodePacked(s.chainId, s.diamond);
        for (uint256 i = 0; i < s.selectors.length; i++) acc = abi.encodePacked(acc, s.selectors[i].selector, s.selectors[i].facet);
        for (uint256 f = 0; f < s.facets.length; f++) {
            acc = abi.encodePacked(acc, keccak256(bytes(s.facets[f].artifact)), s.facets[f].facet, s.facets[f].runtimeBytecodeHash);
            for (uint256 j = 0; j < s.facets[f].selectors.length; j++) acc = abi.encodePacked(acc, s.facets[f].selectors[j]);
        }
        for (uint256 c = 0; c < s.bytecodeCache.length; c++) {
            acc = abi.encodePacked(acc, s.bytecodeCache[c].hash, s.bytecodeCache[c].facet);
        }
        for (uint256 n = 0; n < s.namespaces.length; n++) {
            acc = abi.encodePacked(
                acc,
                keccak256(bytes(s.namespaces[n].namespaceId)),
                s.namespaces[n].layoutHash,
                s.namespaces[n].fieldsCount,
                uint8(s.namespaces[n].status),
                keccak256(bytes(s.namespaces[n].supersededBy))
            );
        }
        bytes32 result;
        assembly {
            result := keccak256(add(acc, 0x20), mload(acc))
        }
        return result;
    }

    // JSON building (compact version)
    function _chainJsonCompact(ChainState memory s) private pure returns (string memory) {
        return string.concat(
            "{\n",
            "      \"chainId\": ", StringUtils.toString(s.chainId), ",\n",
            "      \"diamond\": \"", VM.toString(s.diamond), "\",\n",
            "      \"selectors\": ", _selectorsJson(s.selectors), ",\n",
            "      \"facets\": ", _facetsJson(s.facets), ",\n",
            "      \"bytecodeCache\": ", _cacheJson(s.bytecodeCache), ",\n",
            "      \"namespaces\": ", _namespacesJson(s.namespaces), ",\n",
            "      \"history\": ", _historyJson(s.history), ",\n",
            "      \"stateHash\": \"", VM.toString(s.stateHash), "\"\n",
            "    }"
        );
    }

    function _selectorsJson(SelectorSnapshot[] memory arr) private pure returns (string memory) {
        if (arr.length == 0) return "[]";
        string memory out = "[\n";
        for (uint256 i = 0; i < arr.length; i++) {
            out = string.concat(
                out,
                "        {",
                "\"selector\":\"", VM.toString(bytes32(arr[i].selector)), "\",",
                "\"facet\":\"", VM.toString(arr[i].facet), "\"",
                "}",
                i + 1 == arr.length ? "\n" : ",\n"
            );
        }
        return string.concat(out, "      ]");
    }

    function _facetsJson(FacetSnapshot[] memory arr) private pure returns (string memory) {
        if (arr.length == 0) return "[]";
        string memory out = "[\n";
        for (uint256 i = 0; i < arr.length; i++) {
            out = string.concat(
                out,
                "        {",
                "\"artifact\":\"", arr[i].artifact, "\",",
                "\"facet\":\"", VM.toString(arr[i].facet), "\",",
                "\"runtimeBytecodeHash\":\"", VM.toString(arr[i].runtimeBytecodeHash), "\",",
                "\"selectors\":", _bytes4ArrayJson(arr[i].selectors),
                "}",
                i + 1 == arr.length ? "\n" : ",\n"
            );
        }
        return string.concat(out, "      ]");
    }

    function _cacheJson(BytecodeCacheEntry[] memory arr) private pure returns (string memory) {
        if (arr.length == 0) return "[]";
        string memory out = "[\n";
        for (uint256 i = 0; i < arr.length; i++) {
            out = string.concat(
                out,
                "        {",
                "\"hash\":\"", VM.toString(arr[i].hash), "\",",
                "\"facet\":\"", VM.toString(arr[i].facet), "\"",
                "}",
                i + 1 == arr.length ? "\n" : ",\n"
            );
        }
        return string.concat(out, "      ]");
    }

    function _namespacesJson(NamespaceState[] memory arr) private pure returns (string memory) {
        if (arr.length == 0) return "[]";
        string memory out = "[\n";
        for (uint256 i = 0; i < arr.length; i++) {
            out = string.concat(
                out,
                "        {",
                "\"namespaceId\":\"", arr[i].namespaceId, "\",",
                "\"layoutHash\":\"", HexUtils.toHexString(arr[i].layoutHash), "\",",
                "\"fieldsCount\":", StringUtils.toString(arr[i].fieldsCount), ",",
                "\"status\":", StringUtils.toString(uint256(arr[i].status)), ",",
                "\"supersededBy\":\"", arr[i].supersededBy, "\"",
                "}",
                i + 1 == arr.length ? "\n" : ",\n"
            );
        }
        return string.concat(out, "      ]");
    }

    function _historyJson(HistoryEntry[] memory arr) private pure returns (string memory) {
        if (arr.length == 0) return "[]";
        string memory out = "[\n";
        for (uint256 i = 0; i < arr.length; i++) {
            out = string.concat(
                out,
                "        {",
                "\"txHash\":\"", HexUtils.toHexString(arr[i].txHash), "\",",
                "\"timestamp\":", StringUtils.toString(arr[i].timestamp), ",",
                "\"addCount\":", StringUtils.toString(arr[i].addCount), ",",
                "\"replaceCount\":", StringUtils.toString(arr[i].replaceCount), ",",
                "\"removeCount\":", StringUtils.toString(arr[i].removeCount),
                "}",
                i + 1 == arr.length ? "\n" : ",\n"
            );
        }
        return string.concat(out, "      ]");
    }

    function _bytes4ArrayJson(bytes4[] memory arr) private pure returns (string memory) {
        if (arr.length == 0) return "[]";
        string memory out = "[";
        for (uint256 i = 0; i < arr.length; i++) {
            out = string.concat(out, "\"", VM.toString(bytes32(arr[i])), "\"", i + 1 == arr.length ? "" : ",");
        }
        return string.concat(out, "]");
    }


    // Array append helpers for iterative loading
    function _appendSelector(SelectorSnapshot[] memory arr, SelectorSnapshot memory item) private pure returns (SelectorSnapshot[] memory out) {
        uint256 n = arr.length;
        out = new SelectorSnapshot[](n + 1);
        for (uint256 i = 0; i < n; i++) out[i] = arr[i];
        out[n] = item;
    }

    function _appendFacet(FacetSnapshot[] memory arr, FacetSnapshot memory item) private pure returns (FacetSnapshot[] memory out) {
        uint256 n = arr.length;
        out = new FacetSnapshot[](n + 1);
        for (uint256 i = 0; i < n; i++) out[i] = arr[i];
        out[n] = item;
    }

    function _appendBytecode(BytecodeCacheEntry[] memory arr, BytecodeCacheEntry memory item) private pure returns (BytecodeCacheEntry[] memory out) {
        uint256 n = arr.length;
        out = new BytecodeCacheEntry[](n + 1);
        for (uint256 i = 0; i < n; i++) out[i] = arr[i];
        out[n] = item;
    }

    function _appendNamespace(NamespaceState[] memory arr, NamespaceState memory item) private pure returns (NamespaceState[] memory out) {
        uint256 n = arr.length;
        out = new NamespaceState[](n + 1);
        for (uint256 i = 0; i < n; i++) out[i] = arr[i];
        out[n] = item;
    }

    function _appendHistory(HistoryEntry[] memory arr, HistoryEntry memory item) private pure returns (HistoryEntry[] memory out) {
        uint256 n = arr.length;
        out = new HistoryEntry[](n + 1);
        for (uint256 i = 0; i < n; i++) out[i] = arr[i];
        out[n] = item;
    }

    function _appendBytes4(bytes4[] memory arr, bytes4 item) private pure returns (bytes4[] memory out) {
        uint256 n = arr.length;
        out = new bytes4[](n + 1);
        for (uint256 i = 0; i < n; i++) out[i] = arr[i];
        out[n] = item;
    }

}
