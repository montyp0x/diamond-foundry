// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamond} from "../../interfaces/diamond/IDiamond.sol";
import {IDiamondCut} from "../../interfaces/diamond/IDiamondCut.sol";
import {ManifestIO} from "../io/Manifest.sol";
import {DesiredFacetsIO} from "../io/DesiredFacets.sol";
import {CutPlanner} from "../plan/CutPlanner.sol";
import {SelectorCheck} from "../validate/SelectorCheck.sol";

/// @title PlanBuilder
/// @notice Manifest-only planner: validates desired facets, computes selector-level diff
///         against the manifest snapshot, applies core guards, and groups into FacetCut[].
/// @dev This library is pure/manifest-driven; higher layers provide `targets` (artifact→facet address),
///      typically resolved from manifest bytecode cache or set to address(0) for “needs deploy”.
library PlanBuilder {
    // ─────────────────────────────────────────────────────────────────────────────
    // Types
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Final grouped plan ready to pass into `diamondCut`.
    struct Plan {
        IDiamondCut.FacetCut[] cuts; // grouped by (facet, action), remove uses facet=address(0)
        uint256 addCount;
        uint256 replaceCount;
        uint256 removeCount;
    }

    /// @notice Options controlling core-guard behavior.
    struct Options {
        bool allowRemoveCore; // if false, Remove/Replace of core selectors will revert
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Entry point
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Build a grouped cut plan using only the manifest snapshot and desired facets.
    /// @param current Manifest snapshot for the current chain.
    /// @param desired Desired (lock-file) state.
    /// @param targets Mapping of facet artifact → facet address (address(0) if not yet deployed).
    /// @param opts Core guard options (no mass-remove policy here by request).
    function build(
        ManifestIO.ChainState memory current,
        DesiredFacetsIO.DesiredState memory desired,
        CutPlanner.FacetAddr[] memory targets,
        Options memory opts
    ) internal pure returns (Plan memory p) {
        // 1) Validate: no selector collisions across desired facets.
        SelectorCheck.FacetInput[] memory fin = _toFacetInputs(desired);
        SelectorCheck.ensureNoCollisions(fin);

        // 2) Compute selector-level diff ops (Add/Replace/Remove) vs manifest snapshot.
        (CutPlanner.SelectorOp[] memory ops, uint256 opCount) =
            CutPlanner.diff(_toCurrent(current), _toDesired(desired), targets);
        if (opCount == 0) {
            // Leave p.cuts empty; caller may treat as NoOp.
            return p;
        }

        // 3) Core guard: do not allow touching core selectors unless opted-in.
        //    We guard for Replace and Remove sets; Adds are always safe.
        bytes4[][] memory risky = _collectRiskySelectors(ops);
        SelectorCheck.ensureCoreGuardMulti(risky, opts.allowRemoveCore);

        // 4) Group into FacetCut[] (per (facet,address,action)) and tally totals.
        CutPlanner.Grouped memory g = CutPlanner.group(ops, targets);

        p.cuts = g.cuts;
        p.addCount = g.addCount;
        p.replaceCount = g.replaceCount;
        p.removeCount = g.removeCount;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Internals: adapters and helpers
    // ─────────────────────────────────────────────────────────────────────────────

    function _toFacetInputs(DesiredFacetsIO.DesiredState memory d)
        private
        pure
        returns (SelectorCheck.FacetInput[] memory out)
    {
        out = new SelectorCheck.FacetInput[](d.facets.length);
        for (uint256 i = 0; i < d.facets.length; i++) {
            out[i].artifact = d.facets[i].artifact;
            out[i].selectors = d.facets[i].selectors;
        }
    }

    function _toCurrent(ManifestIO.ChainState memory s) private pure returns (CutPlanner.Current[] memory out) {
        out = new CutPlanner.Current[](s.selectors.length);
        for (uint256 i = 0; i < s.selectors.length; i++) {
            out[i].selector = s.selectors[i].selector;
            out[i].facet = s.selectors[i].facet;
        }
    }

    function _toDesired(DesiredFacetsIO.DesiredState memory d) private pure returns (CutPlanner.Desired[] memory out) {
        out = new CutPlanner.Desired[](d.facets.length);
        for (uint256 i = 0; i < d.facets.length; i++) {
            out[i].artifact = d.facets[i].artifact;
            out[i].selectors = d.facets[i].selectors;
        }
    }

    /// @dev Collect Replace and Remove selectors into groups for core-guard checks.
    function _collectRiskySelectors(CutPlanner.SelectorOp[] memory ops)
        private
        pure
        returns (bytes4[][] memory groups)
    {
        // Count sizes first
        uint256 rpl = 0;
        uint256 rem = 0;
        for (uint256 i = 0; i < ops.length; i++) {
            if (ops[i].action == IDiamond.FacetCutAction.Replace) rpl++;
            else if (ops[i].action == IDiamond.FacetCutAction.Remove) rem++;
        }

        groups = new bytes4[][](2);
        groups[0] = new bytes4[](rpl); // Replace
        groups[1] = new bytes4[](rem); // Remove

        // Fill
        uint256 wR = 0;
        uint256 wD = 0;
        for (uint256 i = 0; i < ops.length; i++) {
            if (ops[i].action == IDiamond.FacetCutAction.Replace) {
                groups[0][wR++] = ops[i].selector;
            } else if (ops[i].action == IDiamond.FacetCutAction.Remove) {
                groups[1][wD++] = ops[i].selector;
            }
        }
    }
}
