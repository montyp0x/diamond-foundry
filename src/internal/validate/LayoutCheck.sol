// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../errors/Errors.sol";

/// @title LayoutCheck
/// @notice Append-only storage layout validator (namespace-scoped).
/// @dev This library is intentionally minimal. It expects the caller to provide
///      ordered Field descriptors (old vs new). It enforces:
///        - new length >= old length
///        - for every index i in [0..oldLen), new[i] == old[i] (typeId, slot, offset)
///      i.e., only appending new fields at the end is allowed.
library LayoutCheck {
    /// @notice Minimal field descriptor extracted from Solidity's storageLayout.
    /// @dev `typeId` should uniquely identify the field type (e.g., compiler "type" string).
    struct Field {
        string typeId; // e.g. "t_uint256", "t_mapping(t_address,t_uint256)", etc.
        uint256 slot; // absolute storage slot index
        uint256 offset; // byte offset within the slot (0..31)
            // NOTE: If you need more strictness later, you can extend with `bytes32 labelHash`, `bytes32 typeHash`, etc.
    }

    /// @notice Per-namespace input for an append-only check.
    struct NamespaceInput {
        string namespaceId; // e.g. "uniswap.v2"
        Field[] oldLayout; // accepted layout (from manifest)
        Field[] newLayout; // candidate layout (from current build)
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Single-namespace checks
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Ensures that `newLayout` is an append-only extension of `oldLayout`.
    /// @dev Reverts with StorageLayoutIncompatible(namespace, reason) if violated.
    function ensureAppendOnly(NamespaceInput memory ns) internal pure {
        _ensureAppendOnly(ns.namespaceId, ns.oldLayout, ns.newLayout);
    }

    /// @notice Compute a stable hash for a layout (order-sensitive).
    /// @dev Useful for recording in a manifest and quick equality checks.
    function computeLayoutHash(Field[] memory layout_) internal pure returns (bytes32 h) {
        bytes memory acc;
        // Pack as: keccak256(abi.encode(typeId, slot, offset)) per field, then hash the concatenation.
        for (uint256 i = 0; i < layout_.length; i++) {
            acc = abi.encodePacked(acc, keccak256(abi.encode(layout_[i].typeId, layout_[i].slot, layout_[i].offset)));
        }
        h = keccak256(acc);
    }

    /// @notice Return hash and count as a compact summary (for logs/UI).
    function summarize(Field[] memory layout_) internal pure returns (bytes32 hash_, uint256 count_) {
        return (computeLayoutHash(layout_), layout_.length);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Multi-namespace helpers
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Ensure append-only for multiple namespaces.
    function ensureAppendOnlyMany(NamespaceInput[] memory namespaces) internal pure {
        for (uint256 i = 0; i < namespaces.length; i++) {
            _ensureAppendOnly(namespaces[i].namespaceId, namespaces[i].oldLayout, namespaces[i].newLayout);
        }
    }

    /// @notice Compute layout hashes for multiple namespaces.
    function summarizeMany(NamespaceInput[] memory namespaces)
        internal
        pure
        returns (bytes32[] memory hashes, uint256[] memory counts)
    {
        hashes = new bytes32[](namespaces.length);
        counts = new uint256[](namespaces.length);
        for (uint256 i = 0; i < namespaces.length; i++) {
            (hashes[i], counts[i]) = summarize(namespaces[i].newLayout);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Internals
    // ─────────────────────────────────────────────────────────────────────────────

    function _ensureAppendOnly(string memory ns, Field[] memory oldLayout, Field[] memory newLayout) private pure {
        if (newLayout.length < oldLayout.length) {
            revert Errors.StorageLayoutIncompatible(ns, "new layout is shorter than old layout");
        }
        // prefix equality: every old field must match the new one at the same index
        for (uint256 i = 0; i < oldLayout.length; i++) {
            Field memory a = oldLayout[i];
            Field memory b = newLayout[i];

            // type check (exact match)
            if (keccak256(bytes(a.typeId)) != keccak256(bytes(b.typeId))) {
                revert Errors.StorageLayoutIncompatible(ns, _mismatchReason("typeId", i));
            }
            // slot check
            if (a.slot != b.slot) {
                revert Errors.StorageLayoutIncompatible(ns, _mismatchReason("slot", i));
            }
            // offset check
            if (a.offset != b.offset) {
                revert Errors.StorageLayoutIncompatible(ns, _mismatchReason("offset", i));
            }
        }
        // OK: any extra fields in newLayout are considered appended.
    }

    function _mismatchReason(string memory field, uint256 index) private pure returns (string memory) {
        // Builds a short reason string like: "mismatch: slot at index 3"
        return string(abi.encodePacked("mismatch: ", field, " at index ", _uToString(index)));
    }

    // Minimal uint -> string for reasons (no external deps here)
    function _uToString(uint256 v) private pure returns (string memory) {
        if (v == 0) return "0";
        uint256 temp = v;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (v != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (v % 10)));
            v /= 10;
        }
        return string(buffer);
    }
}
