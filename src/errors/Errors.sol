// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Errors
/// @notice Centralized custom errors for the Diamond upgrades library.
library Errors {
    // ─────────────────────────────────────────────────────────────────────────────
    // Generic / flow
    // ─────────────────────────────────────────────────────────────────────────────
    error Unsupported(string what);

    // ─────────────────────────────────────────────────────────────────────────────
    // JSON / I/O
    // ─────────────────────────────────────────────────────────────────────────────
    error DesiredFacetsNotFound(string name);
    error ManifestNotFound(string name, uint256 chainId);
    error StorageConfigNotFound(string name);

    // ─────────────────────────────────────────────────────────────────────────────
    // Namespace / storage policy
    // ─────────────────────────────────────────────────────────────────────────────
    error NamespaceConfigMissing(string namespaceId);
    error NamespaceReplaced(string namespaceId, string successorNamespaceId);
    error StorageLayoutIncompatible(string namespaceId, string reason);

    // ─────────────────────────────────────────────────────────────────────────────
    // Desired facets validation
    // ─────────────────────────────────────────────────────────────────────────────
    error UsesMissing(string facetArtifact); // facet didn't declare `uses` when required
    error SelectorCollision(bytes4 selector, string artifactA, string artifactB);
    error CoreSelectorProtected(bytes4 selector); // attempted to touch core selector without allowRemoveCore

    // ─────────────────────────────────────────────────────────────────────────────
    // Init / execution
    // ─────────────────────────────────────────────────────────────────────────────
    error InitCalldataMissing(); // target present without data or vice versa
    error InitFailed(bytes returndata);

    // ─────────────────────────────────────────────────────────────────────────────
    // Artifacts / deployment
    // ─────────────────────────────────────────────────────────────────────────────
    error RuntimeBytecodeEmpty(string artifact);
    error InvalidArtifact(string artifact);
}
