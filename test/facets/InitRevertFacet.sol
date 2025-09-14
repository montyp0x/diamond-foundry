// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title InitRevertFacet
/// @notice Test facet that reverts during initialization
contract InitRevertFacet {
    bool private shouldRevert;
    
    /// @notice Set revert flag
    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }
    
    /// @notice Initialize function that may revert
    function init() external {
        if (shouldRevert) {
            revert("InitRevertFacet: intentional revert");
        }
    }
    
    /// @notice Get revert flag
    function getShouldRevert() external view returns (bool) {
        return shouldRevert;
    }
}
