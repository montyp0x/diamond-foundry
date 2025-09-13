// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SelectorLib
/// @notice Utilities for computing and manipulating function selectors.
library SelectorLib {
    /// @notice Compute a function selector from a canonical signature string.
    /// @param sig Example: "transfer(address,uint256)"
    function selector(string memory sig) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(sig)));
    }

    /// @notice Compute selectors from a list of signature strings.
    function selectors(string[] memory sigs) internal pure returns (bytes4[] memory out) {
        out = new bytes4[](sigs.length);
        for (uint256 i = 0; i < sigs.length; i++) {
            out[i] = selector(sigs[i]);
        }
    }

    /// @notice True if `arr` contains `s`.
    function contains(bytes4[] memory arr, bytes4 s) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == s) return true;
        }
        return false;
    }

    /// @notice Return the first index of `s` in `arr` or `type(uint256).max` if not found.
    function indexOf(bytes4[] memory arr, bytes4 s) internal pure returns (uint256) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == s) return i;
        }
        return type(uint256).max;
    }

    /// @notice Remove duplicates in-place, preserving order. Returns a newly sized array.
    /// @dev O(n^2) but selector sets are typically small.
    function dedup(bytes4[] memory arr) internal pure returns (bytes4[] memory out) {
        if (arr.length == 0) return arr;
        bytes4[] memory tmp = new bytes4[](arr.length);
        uint256 w = 0;

        for (uint256 i = 0; i < arr.length; i++) {
            bytes4 s = arr[i];
            bool seen = false;
            for (uint256 j = 0; j < w; j++) {
                if (tmp[j] == s) {
                    seen = true;
                    break;
                }
            }
            if (!seen) tmp[w++] = s;
        }

        out = new bytes4[](w);
        for (uint256 k = 0; k < w; k++) {
            out[k] = tmp[k];
        }
    }

    /// @notice Concatenate two selector arrays.
    function concat(bytes4[] memory a, bytes4[] memory b) internal pure returns (bytes4[] memory out) {
        out = new bytes4[](a.length + b.length);
        uint256 w = 0;
        for (uint256 i = 0; i < a.length; i++) {
            out[w++] = a[i];
        }
        for (uint256 j = 0; j < b.length; j++) {
            out[w++] = b[j];
        }
    }

    /// @notice Filter selectors by excluding any that appear in `exclude`.
    function exclude(bytes4[] memory src, bytes4[] memory excludeArr) internal pure returns (bytes4[] memory out) {
        // Worst case same size as src
        bytes4[] memory tmp = new bytes4[](src.length);
        uint256 w = 0;
        for (uint256 i = 0; i < src.length; i++) {
            if (!contains(excludeArr, src[i])) tmp[w++] = src[i];
        }
        out = new bytes4[](w);
        for (uint256 k = 0; k < w; k++) {
            out[k] = tmp[k];
        }
    }
}
