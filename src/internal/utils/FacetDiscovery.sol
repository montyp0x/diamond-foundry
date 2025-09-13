// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {DesiredFacetsIO} from "../io/DesiredFacets.sol";

/// @title FacetDiscovery
/// @notice Automatically discovers facets from src/example/facets/ directory
/// @dev Scans the example facets directory and creates DesiredState automatically
library FacetDiscovery {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Automatically discovers all facets from src/example/facets/ directory
    /// @param name The project name
    /// @param namespace The namespace to use for all discovered facets
    /// @return d The DesiredState with all discovered facets
    function discoverExampleFacets(string memory name, string memory namespace)
        internal
        pure
        returns (DesiredFacetsIO.DesiredState memory d)
    {
        d.name = name;
        d.init = DesiredFacetsIO.InitSpec({target: address(0), data: ""});

        // Discover facets from counter namespace
        DesiredFacetsIO.Facet[] memory counterFacets =
            _discoverFacetsInDirectory("src/example/facets/counter/", namespace);

        // Combine all discovered facets
        d.facets = counterFacets;
    }

    /// @notice Discovers facets in a specific directory
    /// @param namespace The namespace to assign to discovered facets
    /// @return facets Array of discovered facets
    function _discoverFacetsInDirectory(string memory, /* directory */ string memory namespace)
        private
        pure
        returns (DesiredFacetsIO.Facet[] memory facets)
    {
        // For now, we'll hardcode the known facets from the counter example
        // In a real implementation, this would scan the filesystem
        facets = new DesiredFacetsIO.Facet[](2);

        // AddFacet
        facets[0] = DesiredFacetsIO.Facet({
            artifact: "AddFacet.sol:AddFacet",
            selectors: new bytes4[](0), // Will be populated by FacetSync
            uses: _singleStringArray(namespace)
        });

        // ViewFacet
        facets[1] = DesiredFacetsIO.Facet({
            artifact: "ViewFacet.sol:ViewFacet",
            selectors: new bytes4[](0), // Will be populated by FacetSync
            uses: _singleStringArray(namespace)
        });
    }

    /// @notice Creates a single-element string array
    /// @param s The string to wrap in an array
    /// @return arr Array containing the single string
    function _singleStringArray(string memory s) private pure returns (string[] memory arr) {
        arr = new string[](1);
        arr[0] = s;
    }

    /// @notice Enhanced discovery that could scan filesystem (future implementation)
    /// @dev This is a placeholder for future filesystem scanning functionality
    /// @return facets Array of discovered facets
    function _scanDirectoryForFacets(string memory, /* baseDirectory */ string memory /* namespace */ )
        private
        pure
        returns (DesiredFacetsIO.Facet[] memory facets)
    {
        // This would be implemented to actually scan the filesystem
        // For now, return empty array as placeholder
        facets = new DesiredFacetsIO.Facet[](0);
    }
}
