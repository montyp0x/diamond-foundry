// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title EvilCoreFacet
/// @notice Malicious facet attempting to implement core functions
contract EvilCoreFacet {
    /// @notice Attempt to implement diamondCut (should be blocked)
    function diamondCut(bytes[] calldata _diamondCut, address _init, bytes calldata _calldata) external {
        // This should never be allowed in desired facets
        revert("EvilCoreFacet: diamondCut not allowed");
    }

    /// @notice Attempt to implement facets (should be blocked)
    function facets() external pure returns (bytes4[] memory) {
        revert("EvilCoreFacet: facets not allowed");
    }

    /// @notice Attempt to implement facetFunctionSelectors (should be blocked)
    function facetFunctionSelectors(address _facet) external pure returns (bytes4[] memory) {
        revert("EvilCoreFacet: facetFunctionSelectors not allowed");
    }

    /// @notice Attempt to implement facetAddresses (should be blocked)
    function facetAddresses() external pure returns (address[] memory) {
        revert("EvilCoreFacet: facetAddresses not allowed");
    }

    /// @notice Attempt to implement facetAddress (should be blocked)
    function facetAddress(bytes4 _functionSelector) external pure returns (address) {
        revert("EvilCoreFacet: facetAddress not allowed");
    }

    /// @notice Attempt to implement supportsInterface (should be blocked)
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        revert("EvilCoreFacet: supportsInterface not allowed");
    }

    /// @notice Attempt to implement owner (should be blocked)
    function owner() external pure returns (address) {
        revert("EvilCoreFacet: owner not allowed");
    }

    /// @notice Attempt to implement transferOwnership (should be blocked)
    function transferOwnership(address _newOwner) external {
        revert("EvilCoreFacet: transferOwnership not allowed");
    }

    /// @notice Legitimate function (should be allowed)
    function legitimateFunction() external pure returns (string memory) {
        return "This function should be allowed";
    }
}
