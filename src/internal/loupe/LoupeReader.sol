// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamondLoupe} from "../../interfaces/diamond/IDiamondLoupe.sol";

/// @title LoupeReader
/// @notice Thin view helpers around EIP-2535 loupe for convenient reads in tests/scripts.
/// @dev Not used in manifest-only flow, but handy for verification and drift checks.
library LoupeReader {
    struct SelectorOwner {
        bytes4 selector;
        address facet;
    }

    /// @notice Return a flat mapping (selector -> facet) for a Diamond.
    function snapshotSelectorOwners(address diamond) internal view returns (SelectorOwner[] memory out) {
        IDiamondLoupe loupe = IDiamondLoupe(diamond);
        address[] memory facets = loupe.facetAddresses();

        // count total selectors first
        uint256 total = 0;
        for (uint256 i = 0; i < facets.length; i++) {
            total += loupe.facetFunctionSelectors(facets[i]).length;
        }

        out = new SelectorOwner[](total);
        uint256 w = 0;
        for (uint256 i = 0; i < facets.length; i++) {
            bytes4[] memory sels = loupe.facetFunctionSelectors(facets[i]);
            for (uint256 j = 0; j < sels.length; j++) {
                out[w++] = SelectorOwner({selector: sels[j], facet: facets[i]});
            }
        }
    }

    /// @notice Return all selectors for a given facet address.
    function selectorsOf(address diamond, address facet) internal view returns (bytes4[] memory) {
        return IDiamondLoupe(diamond).facetFunctionSelectors(facet);
    }

    /// @notice Return the facet address currently implementing `selector` (or address(0)).
    function facetOf(address diamond, bytes4 selector) internal view returns (address) {
        return IDiamondLoupe(diamond).facetAddress(selector);
    }
}
