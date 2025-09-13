// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ManifestIO} from "../io/Manifest.sol";
import {DesiredFacetsIO} from "../io/DesiredFacets.sol";
import {CutPlanner} from "../plan/CutPlanner.sol";

/// @title ManifestApply
/// @notice Rebuilds the per-chain manifest snapshot after a successful diamondCut.
/// @dev Manifest-only: we trust the desired set + resolved facet addresses as the new truth.
library ManifestApply {
    /// @notice Recompute the selector/facet snapshot and facet list from desired + targets.
    /// @param current The previous chain slice (namespaces/history/stateHash may be reused/extended).
    /// @param desired The desired (lock-file) state used for this upgrade.
    /// @param targets Mapping artifact → facet address for each desired facet (must be nonzero after deploys).
    /// @param runtimeHashes keccak256(runtime bytecode) per desired facet (same index as `targets`/`desired.facets`).
    /// @return next Next chain slice with updated selectors, facets, and bytecode cache.
    function rebuildAfterUpgrade(
        ManifestIO.ChainState memory current,
        DesiredFacetsIO.DesiredState memory desired,
        CutPlanner.FacetAddr[] memory targets,
        bytes32[] memory runtimeHashes
    ) internal pure returns (ManifestIO.ChainState memory next) {
        // Keep diamond address and chainId
        next.chainId = current.chainId;
        next.diamond = current.diamond;

        // 1) Rebuild flat selector snapshot from desired (selector -> resolved facet)
        uint256 totalSelectors = _totalDesiredSelectors(desired);
        next.selectors = new ManifestIO.SelectorSnapshot[](totalSelectors);

        uint256 w = 0;
        for (uint256 i = 0; i < desired.facets.length; i++) {
            address facetAddr = _resolve(targets, desired.facets[i].artifact);
            // facetAddr must be resolved (nonzero) at this point in the flow
            require(facetAddr != address(0), "ManifestApply: unresolved facet address");

            for (uint256 j = 0; j < desired.facets[i].selectors.length; j++) {
                next.selectors[w++] = ManifestIO.SelectorSnapshot({
                    selector: desired.facets[i].selectors[j],
                    facet: facetAddr
                });
            }
        }

        // 2) Rebuild facet snapshots (artifact, address, runtime hash, selectors it owns)
        next.facets = new ManifestIO.FacetSnapshot[](desired.facets.length);
        for (uint256 i = 0; i < desired.facets.length; i++) {
            address facetAddr = _resolve(targets, desired.facets[i].artifact);
            bytes32 rhash = runtimeHashes[i];

            // copy selectors for this facet
            bytes4[] memory sels = new bytes4[](desired.facets[i].selectors.length);
            for (uint256 j = 0; j < sels.length; j++) {
                sels[j] = desired.facets[i].selectors[j];
            }

            next.facets[i] = ManifestIO.FacetSnapshot({
                artifact: desired.facets[i].artifact,
                facet: facetAddr,
                runtimeBytecodeHash: rhash,
                selectors: sels
            });
        }

        // 3) Merge/update bytecode cache (hash -> address), preserving existing entries
        next.bytecodeCache = _mergeBytecodeCache(current, runtimeHashes, targets);

        // 4) Namespaces: carry over as-is (layout acceptance is updated by a separate step)
        next.namespaces = current.namespaces;

        // 5) History: carry over; caller will append a new entry (tx hash, counts, timestamp)
        next.history = current.history;

        // 6) Recompute state hash (deterministic digest of snapshot parts)
        next.stateHash = ManifestIO.computeStateHash(next);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Internals
    // ─────────────────────────────────────────────────────────────────────────────

    function _totalDesiredSelectors(DesiredFacetsIO.DesiredState memory d) private pure returns (uint256 n) {
        for (uint256 i = 0; i < d.facets.length; i++) {
            n += d.facets[i].selectors.length;
        }
    }

    function _resolve(CutPlanner.FacetAddr[] memory targets, string memory artifact) private pure returns (address) {
        bytes32 key = keccak256(bytes(artifact));
        for (uint256 i = 0; i < targets.length; i++) {
            if (keccak256(bytes(targets[i].artifact)) == key) {
                return targets[i].facet;
            }
        }
        return address(0);
    }

    function _mergeBytecodeCache(
        ManifestIO.ChainState memory current,
        bytes32[] memory runtimeHashes,
        CutPlanner.FacetAddr[] memory targets
    ) private pure returns (ManifestIO.BytecodeCacheEntry[] memory out) {
        // Build a temp array with current cache + potential new entries
        uint256 extra = 0;
        // Count how many *new* (hash,addr) pairs we’ll add
        for (uint256 i = 0; i < runtimeHashes.length; i++) {
            if (_cacheLookup(current, runtimeHashes[i]) == address(0)) {
                // only add if target is resolved
                if (targets[i].facet != address(0)) extra++;
            }
        }

        out = new ManifestIO.BytecodeCacheEntry[](current.bytecodeCache.length + extra);
        // copy existing
        for (uint256 c = 0; c < current.bytecodeCache.length; c++) {
            out[c] = current.bytecodeCache[c];
        }

        // append new
        uint256 w = current.bytecodeCache.length;
        for (uint256 i = 0; i < runtimeHashes.length; i++) {
            bytes32 h = runtimeHashes[i];
            address a = _cacheLookup(current, h);
            if (a == address(0)) {
                address targetAddr = targets[i].facet;
                if (targetAddr != address(0)) {
                    out[w++] = ManifestIO.BytecodeCacheEntry({hash: h, facet: targetAddr});
                }
            }
        }

        // If we allocated more than we filled (shouldn't happen), trim
        assembly { mstore(out, w) }
    }

    function _cacheLookup(ManifestIO.ChainState memory s, bytes32 h) private pure returns (address) {
        for (uint256 i = 0; i < s.bytecodeCache.length; i++) {
            if (s.bytecodeCache[i].hash == h) return s.bytecodeCache[i].facet;
        }
        return address(0);
    }
}
