// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibCounterStorage} from "src/example/libraries/counter/LibCounterStorage.sol";

/// @title AdminFacet
/// @notice Admin functions for testing access control
contract AdminFacet {
    address public admin;
    bool public paused;
    
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event Paused();
    event Unpaused();

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    /// @notice Set the admin address
    /// @param newAdmin The new admin address
    function setAdmin(address newAdmin) external onlyAdmin {
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }

    /// @notice Pause the contract
    function pause() external onlyAdmin {
        paused = true;
        emit Paused();
    }

    /// @notice Unpause the contract
    function unpause() external onlyAdmin {
        paused = false;
        emit Unpaused();
    }

    /// @notice Admin-only function to set value
    /// @param value The value to set
    function adminSetValue(uint256 value) external onlyAdmin whenNotPaused {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        cs.value = value;
    }

    /// @notice Initialize admin (only callable once)
    function initializeAdmin() external {
        require(admin == address(0), "Already initialized");
        admin = msg.sender;
    }
}
