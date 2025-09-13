// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Paths
/// @notice Helpers to build paths for .diamond-upgrades files.
/// @dev Keeps path conventions in one place. No IO here.
library Paths {
    /// @notice Root folder for diamond metadata.
    string internal constant ROOT = ".diamond-upgrades/";

    /// @notice `<ROOT><name>/facets.json`
    function facetsJson(string memory name) internal pure returns (string memory) {
        return string(abi.encodePacked(ROOT, name, "/facets.json"));
    }

    /// @notice `<ROOT><name>/manifest.json`
    function manifestJson(string memory name) internal pure returns (string memory) {
        return string(abi.encodePacked(ROOT, name, "/manifest.json"));
    }

    /// @notice `<ROOT><name>/storage.json`
    function storageJson(string memory name) internal pure returns (string memory) {
        return string(abi.encodePacked(ROOT, name, "/storage.json"));
    }

    /// @notice Join two path segments with a `/` if needed.
    function join(string memory a, string memory b) internal pure returns (string memory) {
        bytes memory A = bytes(a);
        if (A.length == 0) return b;
        bytes memory B = bytes(b);
        if (B.length == 0) return a;
        bool hasSlash = A[A.length - 1] == "/";
        return hasSlash ? string(abi.encodePacked(a, b)) : string(abi.encodePacked(a, "/", b));
    }
}
