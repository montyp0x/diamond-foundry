// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamond} from "../../interfaces/diamond/IDiamond.sol";
import {IDiamondCut} from "../../interfaces/diamond/IDiamondCut.sol";

/// @title CutPlanner
/// @notice Computes Add/Replace/Remove operations to transform a Diamond from current (manifest)
///         to desired (facets.json). Pure, manifest-only; no on-chain reads.
/// @dev This library is intentionally simple (O(n^2) scans). For typical facet/selector counts,
///      this is perfectly fine and keeps the code easy to audit.
library CutPlanner {
    // ─────────────────────────────────────────────────────────────────────────────
    // Types
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Current ownership of selectors (from manifest snapshot).
    struct Current {
        bytes4 selector;
        address facet; // zero means "unknown/unset" (shouldn't happen in a valid manifest)
    }

    /// @notice Desired facet declaration (from facets.json).
    struct Desired {
        string artifact;     // "src/.../MyFacet.sol:MyFacet"
        bytes4[] selectors;  // desired selectors routed to this facet
    }

    /// @notice (Optional) known facet addresses resolved per artifact (hash→address cache).
    struct FacetAddr {
        string artifact;
        address facet;       // address(0) => needs deploy / not resolved yet
    }

    /// @notice One selector-level diff op.
    struct SelectorOp {
        IDiamondCut.FacetCutAction action; // Add / Replace / Remove
        bytes4 selector;
        string artifact;                   // for Add/Replace: target facet artifact name
        address fromFacet;                 // for Replace/Remove: currently owned facet (if any)
    }

    /// @notice Grouped plan ready for diamondCut.
    struct Grouped {
        IDiamondCut.FacetCut[] cuts;
        uint256 addCount;
        uint256 replaceCount;
        uint256 removeCount;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Diff (selector-level)
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Build selector-level diff ops between current and desired.
    /// @dev `targets` is used to decide if something is a Replace vs no-op (when address is known).
    function diff(
        Current[] memory current,
        Desired[] memory desired,
        FacetAddr[] memory targets
    ) internal pure returns (SelectorOp[] memory ops, uint256 opCount) {
        // Upper bound: all desired selectors could be Add/Replace + all current could be Remove.
        uint256 desiredTotal = _desiredSelectorCount(desired);
        ops = new SelectorOp[](desiredTotal + current.length);
        opCount = 0;

        // Build desired map (selector -> artifact) for quick membership checks.
        // For simplicity we’ll scan linearly via helpers (counts are small).
        // 1) Adds / Replaces / No-ops
        for (uint256 d = 0; d < desired.length; d++) {
            for (uint256 si = 0; si < desired[d].selectors.length; si++) {
                bytes4 sel = desired[d].selectors[si];
                address curOwner = _findCurrentOwner(current, sel);
                address targetAddr = _resolveFacet(targets, desired[d].artifact);

                if (curOwner == address(0)) {
                    // Not present on-chain (per manifest) → Add
                    ops[opCount++] = SelectorOp({
                        action: IDiamond.FacetCutAction.Add,
                        selector: sel,
                        artifact: desired[d].artifact,
                        fromFacet: address(0)
                    });
                } else {
                    // Present; if targetAddr known and equals current → no-op, otherwise Replace
                    if (targetAddr != address(0) && targetAddr == curOwner) {
                        // no-op (already routed to the correct facet address)
                    } else {
                        ops[opCount++] = SelectorOp({
                            action: IDiamond.FacetCutAction.Replace,
                            selector: sel,
                            artifact: desired[d].artifact,
                            fromFacet: curOwner
                        });
                    }
                }
            }
        }

        // 2) Removes: selectors that exist currently but are NOT in desired.
        for (uint256 i = 0; i < current.length; i++) {
            // If this selector is not desired at all, schedule a Remove
            if (!_desiredContainsSelector(desired, current[i].selector)) {
                ops[opCount++] = SelectorOp({
                    action: IDiamond.FacetCutAction.Remove,
                    selector: current[i].selector,
                    artifact: "", // unused for Remove
                    fromFacet: current[i].facet
                });
            }
        }

        // Trim the ops array to opCount.
        assembly { mstore(ops, opCount) }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Grouping (selector ops → FacetCut[])
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Group selector-level ops into FacetCut batches (one per facet/action).
    /// @dev For Remove, the facetAddress must be address(0) as per EIP-2535 spec.
    function group(
        SelectorOp[] memory ops,
        FacetAddr[] memory targets
    ) internal pure returns (Grouped memory g) {
        // Count buckets first to size arrays deterministically.
        // We’ll group by (facetAddress, action). For Remove, facetAddress = address(0).
        // Simplicity over micro-optimizations: two passes with O(n^2) small scans.

        // First, compute unique (facet, action) pairs and their selector counts.
        address[] memory uniqFacet;
        uint8[] memory uniqAction;
        uint256[] memory counts;
        uint256 uniq = 0;

        // upper bound of unique groups is ops.length (all different)
        uniqFacet = new address[](ops.length);
        uniqAction = new uint8[](ops.length);
        counts = new uint256[](ops.length);

        for (uint256 i = 0; i < ops.length; i++) {
            (address f, uint8 a) = _groupKey(ops[i], targets);
            int256 idx = _findGroup(uniqFacet, uniqAction, uniq, f, a);
            if (idx < 0) {
                uniqFacet[uniq] = f;
                uniqAction[uniq] = a;
                counts[uniq] = 1;
                uniq++;
            } else {
                counts[uint256(idx)]++;
            }
        }

        // Prepare cuts with exact sizes
        g.cuts = new IDiamondCut.FacetCut[](uniq);
        for (uint256 gi = 0; gi < uniq; gi++) {
            g.cuts[gi].facetAddress = uniqFacet[gi];
            g.cuts[gi].action = IDiamond.FacetCutAction(uniqAction[gi]);
            g.cuts[gi].functionSelectors = new bytes4[](counts[gi]);
        }

        // Fill selectors
        // We need a per-group write index
        uint256[] memory w = new uint256[](uniq);
        for (uint256 i = 0; i < ops.length; i++) {
            (address f, uint8 a) = _groupKey(ops[i], targets);
            uint256 gi = uint256(_findGroup(uniqFacet, uniqAction, uniq, f, a));
            g.cuts[gi].functionSelectors[w[gi]++] = ops[i].selector;

            // Tally totals for UI/logging
            if (a == uint8(IDiamond.FacetCutAction.Add)) g.addCount++;
            else if (a == uint8(IDiamond.FacetCutAction.Replace)) g.replaceCount++;
            else if (a == uint8(IDiamond.FacetCutAction.Remove)) g.removeCount++;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────────

    function _desiredSelectorCount(Desired[] memory desired) private pure returns (uint256 n) {
        for (uint256 i = 0; i < desired.length; i++) {
            n += desired[i].selectors.length;
        }
    }

    function _findCurrentOwner(Current[] memory current, bytes4 sel) private pure returns (address) {
        for (uint256 i = 0; i < current.length; i++) {
            if (current[i].selector == sel) return current[i].facet;
        }
        return address(0);
    }

    function _desiredContainsSelector(Desired[] memory desired, bytes4 sel) private pure returns (bool) {
        for (uint256 i = 0; i < desired.length; i++) {
            for (uint256 j = 0; j < desired[i].selectors.length; j++) {
                if (desired[i].selectors[j] == sel) return true;
            }
        }
        return false;
    }

    function _resolveFacet(FacetAddr[] memory targets, string memory artifact) private pure returns (address) {
        bytes32 key;
        assembly {
            key := keccak256(add(artifact, 0x20), mload(artifact))
        }
        for (uint256 i = 0; i < targets.length; i++) {
            if (keccak256(bytes(targets[i].artifact)) == key) {
                return targets[i].facet;
            }
        }
        return address(0);
    }

    function _groupKey(SelectorOp memory op, FacetAddr[] memory targets) private pure returns (address facet, uint8 action) {
        action = uint8(op.action);
        if (op.action == IDiamond.FacetCutAction.Remove) {
            facet = address(0);
        } else {
            facet = _resolveFacet(targets, op.artifact); // may be address(0) until deployment happens
        }
    }

    function _findGroup(
        address[] memory uniqFacet,
        uint8[] memory uniqAction,
        uint256 uniq,
        address facet,
        uint8 action
    ) private pure returns (int256) {
        for (uint256 i = 0; i < uniq; i++) {
            if (uniqFacet[i] == facet && uniqAction[i] == action) {
                return int256(i);
            }
        }
        return -1;
    }
}
