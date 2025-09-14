// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {Utils} from "./Utils.sol";

/// @title StringUtils
/// @notice Common string manipulation utilities.
/// @dev Shared utilities to avoid duplication across the codebase.
library StringUtils {
    /// @notice Convert uint256 to decimal string representation.
    /// @param v The number to convert.
    /// @return Decimal string representation of the number.
    function toString(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 t = v;
        uint256 d;
        while (t != 0) {
            d++;
            t /= 10;
        }
        bytes memory buf = new bytes(d);
        while (v != 0) {
            d--;
            buf[d] = bytes1(uint8(48 + (v % 10)));
            v /= 10;
        }
        return string(buf);
    }

    /**
     * Returns whether the subject string contains the search string.
     */
    function contains(string memory subject, string memory search) internal returns (bool) {
        Vm vm = Vm(Utils.CHEATCODE_ADDRESS);
        return vm.contains(subject, search);
    }

    /**
     * Returns whether the subject string starts with the search string.
     */
    function startsWith(string memory subject, string memory search) internal pure returns (bool) {
        Vm vm = Vm(Utils.CHEATCODE_ADDRESS);
        uint256 index = vm.indexOf(subject, search);
        return index == 0;
    }

    /**
     * Returns whether the subject string ends with the search string.
     */
    function endsWith(string memory subject, string memory search) internal pure returns (bool) {
        Vm vm = Vm(Utils.CHEATCODE_ADDRESS);
        string[] memory tokens = vm.split(subject, search);
        return tokens.length > 1 && bytes(tokens[tokens.length - 1]).length == 0;
    }

    /**
     * Returns the number of non-overlapping occurrences of the search string in the subject string.
     */
    function count(string memory subject, string memory search) internal pure returns (uint256) {
        Vm vm = Vm(Utils.CHEATCODE_ADDRESS);
        string[] memory tokens = vm.split(subject, search);
        return tokens.length - 1;
    }
}
