// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibCounterStorage} from "src/example/libraries/counter/LibCounterStorage.sol";

/// @title EventFacet
/// @notice Facet with events for testing
contract EventFacet {
    event ValueChanged(uint256 oldValue, uint256 newValue);
    event SpecialEvent(string message, uint256 value);
    event ComplexEvent(uint256 indexed id, string data, uint256[] numbers);

    /// @notice Set value and emit event
    /// @param value The new value
    function setWithEvent(uint256 value) external {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        uint256 oldValue = cs.value;
        cs.value = value;
        emit ValueChanged(oldValue, value);
    }

    /// @notice Emit a special event
    /// @param message The message
    function emitSpecial(string memory message) external {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        emit SpecialEvent(message, cs.value);
    }

    /// @notice Emit a complex event
    /// @param id The event ID
    /// @param data The event data
    /// @param numbers Array of numbers
    function emitComplex(uint256 id, string memory data, uint256[] memory numbers) external {
        emit ComplexEvent(id, data, numbers);
    }
}
