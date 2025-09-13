// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title HexUtils
/// @notice Utilities for converting bytes data to hex strings.
/// @dev Shared utilities to avoid duplication across the codebase.
library HexUtils {
    bytes private constant HEX = "0123456789abcdef";

    /// @notice Convert bytes32 to hex string with 0x prefix.
    /// @param b The bytes32 to convert.
    /// @return Hex string representation of the bytes32.
    function toHexString(bytes32 b) internal pure returns (string memory) {
        bytes memory out = new bytes(66);
        out[0] = "0";
        out[1] = "x";
        for (uint256 i = 0; i < 32; i++) {
            uint8 v = uint8(b[i]);
            out[2 + i * 2] = HEX[v >> 4];
            out[3 + i * 2] = HEX[v & 0x0f];
        }
        return string(out);
    }

    /// @notice Convert bytes to hex string with 0x prefix.
    /// @param data The bytes to convert.
    /// @return Hex string representation of the bytes.
    function toHexString(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "0x";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = HEX[uint8(data[i] >> 4)];
            str[2 + i * 2 + 1] = HEX[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }
}
