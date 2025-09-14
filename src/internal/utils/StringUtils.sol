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

    /// @notice Extract the basename (filename) from a path
    function basename(string memory p) internal pure returns (string memory) {
        bytes memory b = bytes(p);
        int256 last = -1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == "/") last = int256(i);
        }
        if (last < 0) return p;
        uint256 s = uint256(last) + 1;
        bytes memory out = new bytes(b.length - s);
        for (uint256 j = 0; j < out.length; j++) {
            out[j] = b[s + j];
        }
        return string(out);
    }

    /// @notice Remove suffix from string
    function chopSuffix(string memory s, string memory suf) internal pure returns (string memory) {
        bytes memory a = bytes(s);
        bytes memory b = bytes(suf);
        bytes memory out = new bytes(a.length - b.length);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = a[i];
        }
        return string(out);
    }

    /// @notice Check if two strings are equal
    function eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /// @notice Extract the last token from a line (space-separated)
    function lastToken(string memory line) internal pure returns (string memory) {
        bytes memory b = bytes(line);
        int256 e = int256(b.length) - 1;
        while (e >= 0 && (b[uint256(e)] == " " || b[uint256(e)] == "\t" || b[uint256(e)] == "\r")) e--;
        if (e < 0) return "";
        int256 s = e;
        while (s >= 0 && b[uint256(s)] != " ") s--;
        uint256 u = uint256(s + 1);
        bytes memory out = new bytes(uint256(e) - u + 1);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = b[u + i];
        }
        return string(out);
    }

    /// @notice Slice bytes array
    function slice(bytes memory b, uint256 off, uint256 len) internal pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = b[off + i];
        }
    }

    /// @notice Grow string array to new size
    function grow(string[] memory a, uint256 n) internal pure returns (string[] memory b) {
        b = new string[](n);
        for (uint256 i = 0; i < a.length; i++) {
            b[i] = a[i];
        }
    }
}
