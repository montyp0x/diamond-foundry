// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {DesiredFacetsIO} from "../io/DesiredFacets.sol";
import {StringUtils} from "../utils/StringUtils.sol";
import {Utils} from "../utils/Utils.sol";
import {FacetDiscovery} from "./FacetDiscovery.sol";

/// @title FacetSync
/// @notice Sync desired facets' selectors from compiled artifact ABIs in `out/`.
/// @dev Без `.length` в путях JSON: итерация по индексам через try/catch на Vm.parseJsonString.
library FacetSync {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Recompute selectors for every facet in `.diamond-upgrades/<name>.facets.json` from ABI.
    function syncSelectors(string memory name) internal {
        // Auto-discover facets if no facets.json exists
        _autoDiscoverFacetsIfNeeded(name);

        DesiredFacetsIO.DesiredState memory d = DesiredFacetsIO.load(name);

        for (uint256 i = 0; i < d.facets.length; i++) {
            string memory artifact = d.facets[i].artifact;
            (string memory fileSol, string memory contractName) = _splitArtifact(artifact);
            string memory root = VM.projectRoot();
            string memory outDir = Utils.getOutDir();
            string memory jsonPath = string.concat(root, "/", outDir, "/", fileSol, "/", contractName, ".json"); // e.g. projectRoot/out/AddFacet.sol/AddFacet.json

            // read artifact JSON
            string memory raw = VM.readFile(jsonPath);

            // walk ABI entries and compute selectors for every "function"
            bytes4[] memory sels = _selectorsFromAbi(raw);

            // overwrite desired selectors (dedup + stable order)
            d.facets[i].selectors = _dedup(sels);
        }

        DesiredFacetsIO.save(d);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Internals: ABI → selectors (через Vm.parseJsonString + try/catch)
    // ─────────────────────────────────────────────────────────────────────────────

    function _selectorsFromAbi(string memory raw) private pure returns (bytes4[] memory out) {
        bytes4[] memory acc = new bytes4[](0);

        // iterate abi[i]
        for (uint256 i = 0;; i++) {
            string memory base = string.concat(".abi[", StringUtils.toString(i), "]");
            string memory typ;
            // stop when no abi[i]
            try VM.parseJsonString(raw, string.concat(base, ".type")) returns (string memory t) {
                typ = t;
            } catch {
                break;
            }

            if (_eq(typ, "function")) {
                // name
                string memory fname = VM.parseJsonString(raw, string.concat(base, ".name"));

                // inputs: iterate inputs[j] until it stops existing
                string memory sig = string.concat(fname, "(");
                bool first = true;
                for (uint256 j = 0;; j++) {
                    string memory ip = string.concat(base, ".inputs[", StringUtils.toString(j), "].type");
                    string memory tIn;
                    try VM.parseJsonString(raw, ip) returns (string memory t) {
                        tIn = t;
                    } catch {
                        break;
                    }
                    if (!first) sig = string.concat(sig, ",");
                    sig = string.concat(sig, tIn);
                    first = false;
                }
                sig = string.concat(sig, ")");

                acc = _append(acc, bytes4(keccak256(bytes(sig))));
            }
        }

        // return trimmed
        out = acc;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Artifact helpers
    // ─────────────────────────────────────────────────────────────────────────────

    /// @dev Accepts "AddFacet.sol:AddFacet" or "src/.../AddFacet.sol:AddFacet" and returns ("AddFacet.sol","AddFacet").
    function _splitArtifact(string memory artifact)
        private
        pure
        returns (string memory leftFile, string memory rightName)
    {
        bytes memory b = bytes(artifact);
        uint256 p = b.length;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ":") {
                p = i;
                break;
            }
        }
        require(p != b.length && p > 0, "FacetSync: bad artifact");
        bytes memory L = new bytes(p);
        for (uint256 i2 = 0; i2 < p; i2++) {
            L[i2] = b[i2];
        }
        bytes memory R = new bytes(b.length - p - 1);
        for (uint256 j = 0; j < R.length; j++) {
            R[j] = b[p + 1 + j];
        }

        // normalize left to basename: ".../AddFacet.sol" -> "AddFacet.sol"
        bytes memory lb = L;
        int256 lastSlash = -1;
        for (uint256 k = 0; k < lb.length; k++) {
            if (lb[k] == "/") lastSlash = int256(k);
        }
        if (lastSlash >= 0) {
            uint256 start = uint256(lastSlash) + 1;
            bytes memory base = new bytes(lb.length - start);
            for (uint256 t = 0; t < base.length; t++) {
                base[t] = lb[start + t];
            }
            leftFile = string(base);
        } else {
            leftFile = string(L);
        }
        rightName = string(R);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Small utils
    // ─────────────────────────────────────────────────────────────────────────────

    function _append(bytes4[] memory arr, bytes4 v) private pure returns (bytes4[] memory out) {
        uint256 n = arr.length;
        out = new bytes4[](n + 1);
        for (uint256 i = 0; i < n; i++) {
            out[i] = arr[i];
        }
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
                if (tmp[j] == s) {
                    seen = true;
                    break;
                }
            }
            if (!seen) tmp[w++] = s;
        }
        out = new bytes4[](w);
        for (uint256 k = 0; k < w; k++) {
            out[k] = tmp[k];
        }
    }

    function _eq(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /// @notice Auto-discover facets from src/example/ if no facets.json exists
    /// @param name The project name
    function _autoDiscoverFacetsIfNeeded(string memory name) private {
        string memory root = VM.projectRoot();
        string memory facetsPath = string(abi.encodePacked(root, "/.diamond-upgrades/", name, "/facets.json"));

        // Check if facets.json exists
        try VM.readFile(facetsPath) returns (string memory) {
            // File exists, do nothing
            return;
        } catch {
            // File doesn't exist, auto-discover facets using the new FacetDiscovery
            FacetDiscovery.Options memory opts = FacetDiscovery.Options({
                overwrite: false, // Don't overwrite existing files
                autoSync: true, // Auto-sync selectors
                inferUsesFromTags: true, // Parse @uses tags from source code
                fallbackSingleNamespace: true // Use single namespace from storage.json as fallback
            });

            FacetDiscovery.discoverAndWrite(name, opts);
        }
    }
}
