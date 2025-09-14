// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DesiredFacetsIO} from "src/internal/io/DesiredFacets.sol";
import {StorageConfigIO} from "src/internal/io/StorageConfig.sol";
import {FacetDiscovery} from "src/internal/sync/FacetDiscovery.sol";

/// @title TestHelpers
/// @notice Common utility functions for diamond upgrade tests
/// @dev Provides helper functions for managing facets, arrays, and test data
///
/// Usage examples:
/// - Create a facet: TestHelpers.createFacetWithNamespace("MyFacet.sol:MyFacet", "mynamespace.v1")
/// - Append a facet: facets = TestHelpers.appendFacet(facets, facet)
/// - Remove a facet: facets = TestHelpers.removeFacetAt(facets, 0)
/// - Find a facet: (bool found, uint256 index) = TestHelpers.findFacetByArtifact(facets, "MyFacet.sol:MyFacet")
library TestHelpers {
    // ─────────────────────────────────────────────────────────────────────────────
    // Array utilities
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Creates a single-element string array
    /// @param s The string to wrap in an array
    /// @return arr Array containing the single string
    function one(string memory s) internal pure returns (string[] memory arr) {
        arr = new string[](1);
        arr[0] = s;
    }

    /// @notice Appends a facet to the end of a facets array
    /// @param arr The existing facets array
    /// @param x The facet to append
    /// @return out New array with the facet appended
    function appendFacet(DesiredFacetsIO.Facet[] memory arr, DesiredFacetsIO.Facet memory x)
        internal
        pure
        returns (DesiredFacetsIO.Facet[] memory out)
    {
        out = new DesiredFacetsIO.Facet[](arr.length + 1);
        for (uint256 i = 0; i < arr.length; i++) {
            out[i] = arr[i];
        }
        out[arr.length] = x;
    }

    /// @notice Removes a facet at the specified index
    /// @param arr The existing facets array
    /// @param idx The index to remove
    /// @return out New array with the facet at idx removed
    function removeFacetAt(DesiredFacetsIO.Facet[] memory arr, uint256 idx)
        internal
        pure
        returns (DesiredFacetsIO.Facet[] memory out)
    {
        require(idx < arr.length, "TestHelpers: Index out of bounds");
        out = new DesiredFacetsIO.Facet[](arr.length - 1);
        for (uint256 i = 0; i < idx; i++) {
            out[i] = arr[i];
        }
        for (uint256 i = idx + 1; i < arr.length; i++) {
            out[i - 1] = arr[i];
        }
    }

    /// @notice Finds a facet by artifact name
    /// @param facets The facets array to search
    /// @param artifact The artifact name to find
    /// @return found Whether the facet was found
    /// @return index The index of the found facet (0 if not found)
    function findFacetByArtifact(DesiredFacetsIO.Facet[] memory facets, string memory artifact)
        internal
        pure
        returns (bool found, uint256 index)
    {
        for (uint256 i = 0; i < facets.length; i++) {
            if (keccak256(bytes(facets[i].artifact)) == keccak256(bytes(artifact))) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test data utilities
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Creates a facet with default values
    /// @param artifact The artifact name
    /// @param uses The namespaces this facet uses
    /// @return facet A new facet with the specified artifact and uses
    function createFacet(string memory artifact, string[] memory uses)
        internal
        pure
        returns (DesiredFacetsIO.Facet memory facet)
    {
        return DesiredFacetsIO.Facet({artifact: artifact, selectors: new bytes4[](0), uses: uses});
    }

    /// @notice Creates a facet with a single namespace
    /// @param artifact The artifact name
    /// @param namespace The namespace this facet uses
    /// @return facet A new facet with the specified artifact and namespace
    function createFacetWithNamespace(string memory artifact, string memory namespace)
        internal
        pure
        returns (DesiredFacetsIO.Facet memory facet)
    {
        return createFacet(artifact, one(namespace));
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // String utilities
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Checks if two strings are equal
    /// @param a First string
    /// @param b Second string
    /// @return equal Whether the strings are equal
    function stringEquals(string memory a, string memory b) internal pure returns (bool equal) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /// @notice Concatenates two strings
    /// @param a First string
    /// @param b Second string
    /// @return result Concatenated string
    function stringConcat(string memory a, string memory b) internal pure returns (string memory result) {
        return string(abi.encodePacked(a, b));
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Storage upgrade utilities
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Creates a single-element string array
    /// @param a The string to wrap in an array
    /// @return x Array containing the single string
    function singleString(string memory a) internal pure returns (string[] memory x) {
        x = new string[](1);
        x[0] = a;
    }

    /// @notice Creates a two-element string array
    /// @param a First string
    /// @param b Second string
    /// @return x Array containing both strings
    function twoStrings(string memory a, string memory b) internal pure returns (string[] memory x) {
        x = new string[](2);
        x[0] = a;
        x[1] = b;
    }

    /// @notice Appends a namespace config to an array
    /// @param a The existing namespace configs array
    /// @param x The namespace config to append
    /// @return b New array with the namespace config appended
    function appendNamespace(StorageConfigIO.NamespaceConfig[] memory a, StorageConfigIO.NamespaceConfig memory x)
        internal
        pure
        returns (StorageConfigIO.NamespaceConfig[] memory b)
    {
        b = new StorageConfigIO.NamespaceConfig[](a.length + 1);
        for (uint256 i = 0; i < a.length; i++) {
            b[i] = a[i];
        }
        b[a.length] = x;
    }

    /// @notice Removes facets by artifact name
    /// @param a The existing facets array
    /// @param artifact The artifact name to remove
    /// @return b New array with facets matching the artifact removed
    function dropByArtifact(DesiredFacetsIO.Facet[] memory a, string memory artifact)
        internal
        pure
        returns (DesiredFacetsIO.Facet[] memory b)
    {
        uint256 keep = 0;
        bytes32 k = keccak256(bytes(artifact));
        for (uint256 i = 0; i < a.length; i++) {
            if (keccak256(bytes(a[i].artifact)) != k) keep++;
        }
        b = new DesiredFacetsIO.Facet[](keep);
        uint256 w = 0;
        for (uint256 i = 0; i < a.length; i++) {
            if (keccak256(bytes(a[i].artifact)) != k) b[w++] = a[i];
        }
    }

    /// @notice Sets the uses array for a specific facet to contain only one namespace
    /// @param d The desired state to modify
    /// @param artifact The artifact name to modify
    /// @param onlyNs The namespace to set as the only use
    function setUsesOnly(DesiredFacetsIO.DesiredState memory d, string memory artifact, string memory onlyNs)
        internal
        pure
    {
        for (uint256 i = 0; i < d.facets.length; i++) {
            if (stringEquals(d.facets[i].artifact, artifact)) {
                string[] memory singleUse = new string[](1);
                singleUse[0] = onlyNs;
                d.facets[i].uses = singleUse;
                return;
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Automatic facet discovery utilities
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Automatically creates a DesiredState by discovering facets from src/{name}/
    /// @param name The project name
    /// @return d The DesiredState with all discovered facets
    function createDesiredStateFromExample(string memory name)
        internal
        returns (DesiredFacetsIO.DesiredState memory d)
    {
        // Use the new FacetDiscovery (all options are now constants)
        // This will discover facets and save them to facets.json
        FacetDiscovery.discoverAndWrite(name);

        // Load the discovered facets
        return DesiredFacetsIO.load(name);
    }
}
