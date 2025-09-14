// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";

/// @title Paths
/// @notice Helpers to build paths for .diamond-upgrades files.
/// @dev Keeps path conventions in one place. No IO here.
library Paths {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Root folder for diamond metadata.
    string internal constant ROOT = ".diamond-upgrades/";

    /// @notice `<ROOT><name>/facets.json` (relative to current directory)
    function facetsJson(string memory name) internal pure returns (string memory) {
        return string(abi.encodePacked(ROOT, name, "/facets.json"));
    }

    /// @notice `<ROOT><name>/manifest.json` (relative to current directory)
    function manifestJson(string memory name) internal pure returns (string memory) {
        return string(abi.encodePacked(ROOT, name, "/manifest.json"));
    }

    /// @notice `<ROOT><name>/storage.json` (relative to current directory)
    function storageJson(string memory name) internal pure returns (string memory) {
        return string(abi.encodePacked(ROOT, name, "/storage.json"));
    }

    /// @notice `<projectRoot>/<ROOT><name>/facets.json` (absolute path)
    function facetsJsonAbs(string memory name) internal view returns (string memory) {
        return string(abi.encodePacked(VM.projectRoot(), "/", ROOT, name, "/facets.json"));
    }

    /// @notice `<projectRoot>/<ROOT><name>/manifest.json` (absolute path)
    function manifestJsonAbs(string memory name) internal view returns (string memory) {
        return string(abi.encodePacked(VM.projectRoot(), "/", ROOT, name, "/manifest.json"));
    }

    /// @notice `<projectRoot>/<ROOT><name>/storage.json` (absolute path)
    function storageJsonAbs(string memory name) internal view returns (string memory) {
        return string(abi.encodePacked(VM.projectRoot(), "/", ROOT, name, "/storage.json"));
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

    /// @notice Quotes a path for use in shell commands
    function quote(string memory path) internal pure returns (string memory) {
        return string.concat('"', path, '"');
    }

}
