// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LegitimateFacet
/// @notice A facet with only legitimate (non-core) functions
contract LegitimateFacet {
    /// @notice A legitimate function that should be allowed
    function legitimateFunction() external pure returns (string memory) {
        return "This function should be allowed";
    }

    /// @notice Another legitimate function
    function anotherFunction() external pure returns (uint256) {
        return 42;
    }

    /// @notice A function that returns some data
    function getData() external pure returns (bytes32) {
        return keccak256("legitimate data");
    }
}
