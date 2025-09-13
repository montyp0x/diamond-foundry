// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
}
