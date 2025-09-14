// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";

import {Utils} from "../utils/Utils.sol";
import {StringUtils} from "../utils/StringUtils.sol";
import {Paths} from "../utils/Paths.sol";

import {DesiredFacetsIO} from "../io/DesiredFacets.sol";
import {StorageInit} from "../sync/StorageInit.sol";

/// @title FacetsPrepare
/// @notice One-shot helper: discover facets, ensure storage/facets files exist, sync selectors from ABI.
library FacetsPrepare {
    using StringUtils for string;
    using StringUtils for uint256;

    Vm internal constant VM = Vm(Utils.CHEATCODE_ADDRESS);

    // ─────────────────────────────────────────────────────────────────────────────
    // Public entry: ensure & sync
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Create missing `.diamond-upgrades/<name>/{storage,facets}.json` and always sync selectors from ABI.
    function ensureAndSync(string memory name) internal {
        // ensure dir
        string memory root = VM.projectRoot();
        string memory dir  = string.concat(root, "/.diamond-upgrades/", name);
        try VM.createDir(dir, true) {} catch {}

        // 1) ensure storage.json (minimal) — only if missing
        if (!_exists(Paths.storageJsonAbs(name))) {
            _writeEmptyStorage(name);
        }

        // 2) always discover facets to pick up user changes
        _discoverAndWrite(name);

        // 3) always sync selectors from ABI
        _syncSelectors(name);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Step A: storage.json (minimal)
    // ─────────────────────────────────────────────────────────────────────────────

    function _writeEmptyStorage(string memory name) private {
        // minimal empty config via StorageInit.ensure
        StorageInit.NamespaceSeed[] memory seeds = new StorageInit.NamespaceSeed[](0);
        StorageInit.ensure({
            name: name,
            seeds: seeds,
            appendOnlyPolicy: true,
            allowDualWrite: false
        });
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Step B: facets discovery → facets.json (create if missing)
    // ─────────────────────────────────────────────────────────────────────────────

    function _discoverAndWrite(string memory name) private {
        string[] memory srcFiles = _listSources(name);

        DesiredFacetsIO.DesiredState memory d;
        d.name   = name;
        d.init   = DesiredFacetsIO.InitSpec({target: address(0), data: ""});
        d.facets = _collectFacets(name, srcFiles);

        DesiredFacetsIO.save(d);
    }

    function _listSources(string memory name) private returns (string[] memory list) {
        string memory root = VM.projectRoot();
        string memory srcDirAbs = string.concat(root, "/src/", name, "/facets");

        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-lc";
        cmd[2] = string.concat("find ", Paths.quote(srcDirAbs), " -type f -name '*.sol' || true");

        Vm.FfiResult memory r = VM.tryFfi(cmd);
        if (r.exitCode != 0 && r.stdout.length == 0) return new string[](0);

        string memory out = string(r.stdout);
        if (bytes(out).length == 0) return new string[](0);

        list = VM.split(out, "\n");
        if (list.length > 0 && bytes(list[list.length - 1]).length == 0) {
            string[] memory trimmed = new string[](list.length - 1);
            for (uint256 i = 0; i < trimmed.length; i++) trimmed[i] = list[i];
            list = trimmed;
        }
    }

    function _collectFacets(string memory name, string[] memory srcFiles)
        private
        returns (DesiredFacetsIO.Facet[] memory out)
    {
        DesiredFacetsIO.Facet[] memory buf = new DesiredFacetsIO.Facet[](srcFiles.length * 4);
        uint256 w = 0;

        for (uint256 i = 0; i < srcFiles.length; i++) {
            w = _processSourceFile(srcFiles[i], buf, w, name);
        }

        out = new DesiredFacetsIO.Facet[](w);
        for (uint256 t = 0; t < w; t++) out[t] = buf[t];
    }

    function _processSourceFile(
        string memory src,
        DesiredFacetsIO.Facet[] memory buf,
        uint256 w,
        string memory name
    ) private returns (uint256 newW) {
        if (bytes(src).length == 0) return w;

        string[] memory artifacts = _getArtifactsForSource(src);
        if (artifacts.length == 0) return w;

        // normalize to relative project path (src/…)
        string memory root = VM.projectRoot();
        string memory relativeSrc = src;
        if (src.startsWith(root)) {
            bytes memory sb = bytes(src);
            bytes memory rb = bytes(root);
            if (sb.length > rb.length + 1 && sb[rb.length] == "/") {
                relativeSrc = string(StringUtils.slice(sb, rb.length + 1, sb.length - rb.length - 1));
            }
        }

        // accept only src/<name>/facets/**
        string memory srcPrefix = string.concat("src/", name, "/facets/");
        if (!relativeSrc.startsWith(srcPrefix)) return w;

        newW = w;
        for (uint256 j = 0; j < artifacts.length; j++) {
            DesiredFacetsIO.Facet memory facet = _createFacetFromArtifact(artifacts[j], src);
            if (bytes(facet.artifact).length > 0) buf[newW++] = facet;
        }
    }

    function _getArtifactsForSource(string memory src) private returns (string[] memory artifacts) {
        // artifacts live in <projectRoot>/<out>/<File>.sol/*.json
        string memory root   = VM.projectRoot();
        string memory outDir = Utils.getOutDir();
        string memory outAbs = string.concat(root, "/", outDir);

        string memory fileSol = src.basename();
        string memory dir     = string.concat(outAbs, "/", fileSol);

        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-lc";
        cmd[2] = string.concat("find ", Paths.quote(dir), " -type f -name '*.json' || true");

        Vm.FfiResult memory r = VM.tryFfi(cmd);
        if (r.exitCode != 0 && r.stdout.length == 0) return new string[](0);

        string memory outList = string(r.stdout);
        if (bytes(outList).length == 0) return new string[](0);

        artifacts = VM.split(outList, "\n");
        if (artifacts.length > 0 && bytes(artifacts[artifacts.length - 1]).length == 0) {
            string[] memory trimmed = new string[](artifacts.length - 1);
            for (uint256 k = 0; k < trimmed.length; k++) trimmed[k] = artifacts[k];
            artifacts = trimmed;
        }
    }

    function _createFacetFromArtifact(
        string memory artifactJsonPathAbs,
        string memory srcAbs
    ) private returns (DesiredFacetsIO.Facet memory facet)
    {
        if (bytes(artifactJsonPathAbs).length == 0 || !artifactJsonPathAbs.endsWith(".json")) return facet;

        string memory json;
        try VM.readFile(artifactJsonPathAbs) returns (string memory fileContent) { json = fileContent; } catch {
            return facet;
        }

        // We already filtered by path in _processSourceFile, so we can skip sourceName check

        // Build artifact id: "<File>.sol:<Contract>"
        string memory fileSol     = srcAbs.basename();
        string memory contractName= artifactJsonPathAbs.basename().chopSuffix(".json");
        string memory artifactId  = string.concat(fileSol, ":", contractName);

        // uses — from // @uses tags inside source (optional)
        string[] memory uses = _extractUsesTags(VM.readFile(srcAbs));

        facet = DesiredFacetsIO.Facet({
            artifact:  artifactId,
            selectors: new bytes4[](0),
            uses:      uses
        });
    }

    // // @uses <ns> parser (line-based)
    function _extractUsesTags(string memory src) private returns (string[] memory out) {
        bytes memory b = bytes(src);
        string[] memory tmp = new string[](8);
        uint256 w;
        for (uint256 i = 0; i + 7 < b.length; i++) {
            if (b[i] == "/" && b[i + 1] == "/") {
                uint256 j = i; while (j < b.length && b[j] != "\n") j++;
                string memory line = string(StringUtils.slice(b, i, j - i));
                if (line.contains("@uses")) {
                    string memory ns = line.lastToken();
                    if (bytes(ns).length > 0) {
                        if (w == tmp.length) tmp = StringUtils.grow(tmp, w + 8);
                        tmp[w++] = ns;
                    }
                }
                i = j;
            }
        }
        out = new string[](w);
        for (uint256 k = 0; k < w; k++) out[k] = tmp[k];
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Step C: sync selectors from ABI (always)
    // ─────────────────────────────────────────────────────────────────────────────

    function _syncSelectors(string memory name) private {
        DesiredFacetsIO.DesiredState memory d = DesiredFacetsIO.load(name);

        for (uint256 i = 0; i < d.facets.length; i++) {
            (string memory fileSol, string memory contractName) = _splitArtifact(d.facets[i].artifact);

            string memory jsonPath = string.concat(
                VM.projectRoot(), "/", Utils.getOutDir(), "/", fileSol, "/", contractName, ".json"
            );

            string memory raw = VM.readFile(jsonPath);
            bytes4[] memory sels = _selectorsFromAbi(raw);
            d.facets[i].selectors = _dedup(sels);
        }

        DesiredFacetsIO.save(d);
    }

    function _selectorsFromAbi(string memory raw) private pure returns (bytes4[] memory out) {
        bytes4[] memory acc = new bytes4[](0);

        for (uint256 i = 0;; i++) {
            string memory base = string.concat(".abi[", i.toString(), "]");
            string memory typ;
            try VM.parseJsonString(raw, string.concat(base, ".type")) returns (string memory t) {
                typ = t;
            } catch {
                break;
            }

            if (typ.eq("function")) {
                string memory fname = VM.parseJsonString(raw, string.concat(base, ".name"));

                string memory sig = string.concat(fname, "(");
                bool first = true;
                for (uint256 j = 0;; j++) {
                    string memory ip = string.concat(base, ".inputs[", j.toString(), "].type");
                    string memory tIn;
                    try VM.parseJsonString(raw, ip) returns (string memory t) { tIn = t; } catch { break; }
                    if (!first) sig = string.concat(sig, ",");
                    sig = string.concat(sig, tIn);
                    first = false;
                }
                sig = string.concat(sig, ")");

                acc = _append(acc, bytes4(keccak256(bytes(sig))));
            }
        }
        out = acc;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Small helpers
    // ─────────────────────────────────────────────────────────────────────────────

    function _splitArtifact(string memory artifact)
        private
        pure
        returns (string memory leftFile, string memory rightName)
    {
        bytes memory b = bytes(artifact);
        uint256 p = b.length;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ":") { p = i; break; }
        }
        require(p != b.length && p > 0, "FacetsPrepare: bad artifact");

        bytes memory L = new bytes(p);
        for (uint256 i2 = 0; i2 < p; i2++) L[i2] = b[i2];

        bytes memory R = new bytes(b.length - p - 1);
        for (uint256 j = 0; j < R.length; j++) R[j] = b[p + 1 + j];

        // normalize left to basename
        bytes memory lb = L;
        int256 lastSlash = -1;
        for (uint256 k = 0; k < lb.length; k++) if (lb[k] == "/") lastSlash = int256(k);
        if (lastSlash >= 0) {
            uint256 start = uint256(lastSlash) + 1;
            bytes memory base = new bytes(lb.length - start);
            for (uint256 t = 0; t < base.length; t++) base[t] = lb[start + t];
            leftFile = string(base);
        } else {
            leftFile = string(L);
        }
        rightName = string(R);
    }

    function _append(bytes4[] memory arr, bytes4 v) private pure returns (bytes4[] memory out) {
        uint256 n = arr.length;
        out = new bytes4[](n + 1);
        for (uint256 i = 0; i < n; i++) out[i] = arr[i];
        out[n] = v;
    }

    function _dedup(bytes4[] memory arr) private pure returns (bytes4[] memory out) {
        if (arr.length == 0) return arr;
        bytes4[] memory tmp = new bytes4[](arr.length);
        uint256 w = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            bytes4 s = arr[i];
            bool seen = false;
            for (uint256 j = 0; j < w; j++) {
                if (tmp[j] == s) { seen = true; break; }
            }
            if (!seen) tmp[w++] = s;
        }
        out = new bytes4[](w);
        for (uint256 k = 0; k < w; k++) out[k] = tmp[k];
    }

    function _exists(string memory absPath) private view returns (bool) {
        try VM.readFile(absPath) returns (string memory) { return true; } catch { return false; }
    }
}
