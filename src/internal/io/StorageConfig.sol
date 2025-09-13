// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../errors/Errors.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";
import {Paths} from "../utils/Paths.sol";
import {StringUtils} from "../utils/StringUtils.sol";
import {HexUtils} from "../utils/HexUtils.sol";

/// @title StorageConfigIO
/// @notice Types and JSON I/O for `.diamond-upgrades/<name>.storage.json`.
library StorageConfigIO {
    using stdJson for string;

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    enum NamespaceStatus {
        Active,
        Deprecated,
        Replaced
    }

    struct NamespaceConfig {
        string namespaceId;
        bytes32 slot;
        uint64 version;
        NamespaceStatus status;
        string supersededBy;
        string artifact;
        string libraryName;
    }

    struct StorageConfig {
        string name;
        NamespaceConfig[] namespaces;
        bool appendOnlyPolicy;
        bool allowDualWrite;
    }

    // ── Load (expects our save format) ──────────────────────────────────────────
    function load(string memory name) internal view returns (StorageConfig memory cfg) {
        string memory path = Paths.storageJson(name);
        string memory raw;
        try VM.readFile(path) returns (string memory data) {
            raw = data;
        } catch {
            revert Errors.StorageConfigNotFound(name);
        }

        cfg.name = raw.readString(".name");
        cfg.appendOnlyPolicy = raw.readBool(".appendOnlyPolicy");
        cfg.allowDualWrite = raw.readBool(".allowDualWrite");

        uint256 nlen = raw.readUint(".namespacesCount");
        cfg.namespaces = new NamespaceConfig[](nlen);

        for (uint256 i = 0; i < nlen; i++) {
            string memory base = string.concat(".namespaces[", StringUtils.toString(i), "]");
            NamespaceConfig memory ns;
            ns.namespaceId = raw.readString(string.concat(base, ".namespaceId"));
            ns.slot = raw.readBytes32(string.concat(base, ".slot"));
            ns.version = uint64(raw.readUint(string.concat(base, ".version")));
            ns.status = NamespaceStatus(raw.readUint(string.concat(base, ".status")));
            ns.supersededBy = raw.readString(string.concat(base, ".supersededBy"));
            ns.artifact = raw.readString(string.concat(base, ".artifact"));
            ns.libraryName = raw.readString(string.concat(base, ".libraryName"));
            cfg.namespaces[i] = ns;
        }
    }

    // ── Save (direct pretty JSON build) ─────────────────────────────────────────
    function save(StorageConfig memory cfg) internal {
        string memory path = Paths.storageJson(cfg.name);

        string memory json = string.concat(
            "{\n",
            "  \"name\": \"",
            cfg.name,
            "\",\n",
            "  \"appendOnlyPolicy\": ",
            cfg.appendOnlyPolicy ? "true" : "false",
            ",\n",
            "  \"allowDualWrite\": ",
            cfg.allowDualWrite ? "true" : "false",
            ",\n",
            "  \"namespacesCount\": ",
            StringUtils.toString(cfg.namespaces.length),
            ",\n",
            "  \"namespaces\": ",
            _namespacesJsonPretty(cfg.namespaces),
            "\n",
            "}"
        );

        VM.writeFile(path, json);
    }

    // ── Lookup helpers ──────────────────────────────────────────────────────────
    function find(StorageConfig memory cfg, string memory nsId) internal pure returns (bool, uint256) {
        bytes32 k;
        assembly {
            k := keccak256(add(nsId, 0x20), mload(nsId))
        }
        for (uint256 i = 0; i < cfg.namespaces.length; i++) {
            if (keccak256(bytes(cfg.namespaces[i].namespaceId)) == k) return (true, i);
        }
        return (false, 0);
    }

    function requireNamespace(StorageConfig memory cfg, string memory nsId)
        internal
        pure
        returns (NamespaceConfig memory ns)
    {
        (bool ok, uint256 idx) = find(cfg, nsId);
        if (!ok) revert Errors.NamespaceConfigMissing(nsId);
        return cfg.namespaces[idx];
    }

    function isReplacedBy(StorageConfig memory cfg, string memory nsId, string memory successorId)
        internal
        pure
        returns (bool)
    {
        (bool ok, uint256 idx) = find(cfg, nsId);
        if (!ok) return false;
        NamespaceConfig memory ns = cfg.namespaces[idx];
        return
            ns.status == NamespaceStatus.Replaced && keccak256(bytes(ns.supersededBy)) == keccak256(bytes(successorId));
    }

    function slotOf(StorageConfig memory cfg, string memory nsId) internal pure returns (bytes32) {
        return requireNamespace(cfg, nsId).slot;
    }

    // ── Internals (pretty JSON building) ────────────────────────────────────────
    function _namespacesJsonPretty(NamespaceConfig[] memory arr) private pure returns (string memory) {
        if (arr.length == 0) return "[]";

        string memory out = "[\n";
        for (uint256 i = 0; i < arr.length; i++) {
            out = string.concat(
                out,
                "    {\n",
                "      \"namespaceId\": \"",
                arr[i].namespaceId,
                "\",\n",
                "      \"slot\": \"",
                HexUtils.toHexString(arr[i].slot),
                "\",\n",
                "      \"version\": ",
                StringUtils.toString(arr[i].version),
                ",\n",
                "      \"status\": ",
                StringUtils.toString(uint256(arr[i].status)),
                ",\n",
                "      \"supersededBy\": \"",
                arr[i].supersededBy,
                "\",\n",
                "      \"artifact\": \"",
                arr[i].artifact,
                "\",\n",
                "      \"libraryName\": \"",
                arr[i].libraryName,
                "\"\n",
                "    }",
                i + 1 == arr.length ? "\n" : ",\n"
            );
        }
        return string.concat(out, "  ]");
    }
}
