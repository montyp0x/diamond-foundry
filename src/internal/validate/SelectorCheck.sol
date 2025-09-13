// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../errors/Errors.sol";
import {IDiamondCut} from "../../interfaces/diamond/IDiamondCut.sol";
import {IDiamondLoupe} from "../../interfaces/diamond/IDiamondLoupe.sol";

/// @title SelectorCheck
/// @notice Pure helpers to validate selector sets before planning/executing a cut.
/// @dev Does not read chain state or files. Meant to be used by higher-level planners.
library SelectorCheck {
    // Core selectors we guard by default
    bytes4 internal constant SELECTOR_DIAMOND_CUT = IDiamondCut.diamondCut.selector;
    bytes4 internal constant SELECTOR_LOUPE_FACETS = IDiamondLoupe.facets.selector;
    bytes4 internal constant SELECTOR_LOUPE_FACET_FUNCTION_SELECTORS = IDiamondLoupe.facetFunctionSelectors.selector;
    bytes4 internal constant SELECTOR_LOUPE_FACET_ADDRESSES = IDiamondLoupe.facetAddresses.selector;
    bytes4 internal constant SELECTOR_LOUPE_FACET_ADDRESS = IDiamondLoupe.facetAddress.selector;

    /// @notice Thin struct describing a facet's desired selector set.
    struct FacetInput {
        string artifact; // e.g. "src/.../MyFacet.sol:MyFacet"
        bytes4[] selectors; // desired selectors for that facet
    }

    /// @notice Ensure there are no duplicate selectors across desired facets.
    /// @dev Reverts with Errors.SelectorCollision if any selector appears in more than one facet.
    function ensureNoCollisions(FacetInput[] memory facets) internal pure {
        // Simple O(n^2) check is fine for small sets; can be optimized later if needed.
        for (uint256 i = 0; i < facets.length; i++) {
            for (uint256 j = i + 1; j < facets.length; j++) {
                _checkPair(facets[i], facets[j]);
            }
        }
    }

    /// @notice Guard against touching core selectors unless explicitly allowed.
    /// @param selectors A list of selectors being removed/replaced (the risky ones).
    /// @param allowRemoveCore If false, reverts on any core selector.
    function ensureCoreGuard(bytes4[] memory selectors, bool allowRemoveCore) internal pure {
        if (allowRemoveCore) return;
        for (uint256 i = 0; i < selectors.length; i++) {
            if (isCoreSelector(selectors[i])) {
                revert Errors.CoreSelectorProtected(selectors[i]);
            }
        }
    }

    /// @notice Guard against touching core selectors across multiple groups (flattened).
    function ensureCoreGuardMulti(bytes4[][] memory groups, bool allowRemoveCore) internal pure {
        if (allowRemoveCore) return;
        for (uint256 g = 0; g < groups.length; g++) {
            bytes4[] memory sel = groups[g];
            for (uint256 i = 0; i < sel.length; i++) {
                if (isCoreSelector(sel[i])) {
                    revert Errors.CoreSelectorProtected(sel[i]);
                }
            }
        }
    }

    /// @notice Returns true if `selector` is one of the guarded core selectors.
    function isCoreSelector(bytes4 selector) internal pure returns (bool) {
        return (
            selector == SELECTOR_DIAMOND_CUT || selector == SELECTOR_LOUPE_FACETS
                || selector == SELECTOR_LOUPE_FACET_FUNCTION_SELECTORS || selector == SELECTOR_LOUPE_FACET_ADDRESSES
                || selector == SELECTOR_LOUPE_FACET_ADDRESS
        );
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Internals
    // ─────────────────────────────────────────────────────────────────────────────

    function _checkPair(FacetInput memory a, FacetInput memory b) private pure {
        for (uint256 i = 0; i < a.selectors.length; i++) {
            bytes4 s = a.selectors[i];
            for (uint256 j = 0; j < b.selectors.length; j++) {
                if (s == b.selectors[j]) {
                    revert Errors.SelectorCollision(s, a.artifact, b.artifact);
                }
            }
        }
    }
}
