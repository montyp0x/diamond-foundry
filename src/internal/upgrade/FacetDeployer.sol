// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {ManifestIO} from "../io/Manifest.sol";
import {DesiredFacetsIO} from "../io/DesiredFacets.sol";
import {CutPlanner} from "../plan/CutPlanner.sol";
import {Errors} from "../../errors/Errors.sol";

/// @title FacetDeployer
/// @notice Resolves facet addresses for desired artifacts by runtime bytecode hash,
///         reusing cached addresses from the manifest, and optionally deploying if missing.
/// @dev Requires Foundry cheatcodes (works in scripts/tests). No on-chain reads.
library FacetDeployer {
    // canonical handle to Foundry's Vm
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Result of resolution (and optional deployment).
    struct Result {
        CutPlanner.FacetAddr[] targets;  // artifact → facet address (address(0) if unresolved and deploy=false)
        bytes32[] runtimeHashes;         // keccak256(runtime bytecode) per desired facet (same index)
    }

    /// @notice Resolve target facet addresses for all desired artifacts.
    /// @param desired Desired state (facets list with artifacts).
    /// @param current Current manifest chain slice (used for bytecode hash → address cache).
    /// @param deploy If true, deploy facets whose runtime hash is not in cache.
    /// @dev Artifacts must be available (compiled) under Foundry's `out/` — cheatcodes will fetch/deploy by artifact id,
    ///      e.g. "src/example/facets/counter/CounterAddFacet.sol:CounterAddFacet".
    function resolveTargets(
        DesiredFacetsIO.DesiredState memory desired,
        ManifestIO.ChainState memory current,
        bool deploy
    ) internal returns (Result memory r) {
        uint256 n = desired.facets.length;
        r.targets = new CutPlanner.FacetAddr[](n);
        r.runtimeHashes = new bytes32[](n);

        for (uint256 i = 0; i < n; i++) {
            string memory artifact = desired.facets[i].artifact;

            // 1) load runtime bytecode from artifact (compiled output) with basename fallback
            bytes memory runtime = VM.getCode(artifact);
            if (runtime.length == 0) {
                string memory base = _basename(artifact);
                if (!_eq(base, artifact)) {
                    runtime = VM.getCode(base);
                }
            }
            if (runtime.length == 0) revert Errors.RuntimeBytecodeEmpty(artifact);

            bytes32 rhash;
            assembly {
                rhash := keccak256(add(runtime, 0x20), mload(runtime))
            }
            r.runtimeHashes[i] = rhash;

            // 2) try resolve from manifest cache
            address facet = ManifestIO.resolveFacetByHash(current, rhash);

            // 3) if not cached and allowed, deploy now
            if (facet == address(0) && deploy) {
                // NB: facets should not have constructors; if they do, use the overloaded deployCode with args.
                facet = VM.deployCode(artifact);
                if (facet == address(0)) {
                    string memory base = _basename(artifact);
                    if (!_eq(base, artifact)) {
                        facet = VM.deployCode(base);
                    }
                }
                if (facet == address(0)) revert Errors.InvalidArtifact(artifact);
            }

            r.targets[i] = CutPlanner.FacetAddr({artifact: artifact, facet: facet});
        }
    }

    function _basename(string memory artifact) private pure returns (string memory) {
        bytes memory b = bytes(artifact);
        // split on ':' first
        uint256 colon = b.length;
        for (uint256 i = 0; i < b.length; i++) { if (b[i] == ":") { colon = i; break; } }
        if (colon == b.length) return artifact; // malformed, return as-is
        // left part
        bytes memory L = new bytes(colon);
        for (uint256 i2 = 0; i2 < colon; i2++) L[i2] = b[i2];
        // right part
        bytes memory R = new bytes(b.length - colon - 1);
        for (uint256 j = 0; j < R.length; j++) R[j] = b[colon + 1 + j];

        // find last '/'
        int256 lastSlash = -1;
        for (uint256 k = 0; k < L.length; k++) { if (L[k] == "/") lastSlash = int256(k); }
        if (lastSlash < 0) return artifact; // nothing to trim
        uint256 start = uint256(lastSlash) + 1;
        bytes memory baseL = new bytes(L.length - start);
        for (uint256 t = 0; t < baseL.length; t++) baseL[t] = L[start + t];
        return string(abi.encodePacked(string(baseL), ":", string(R)));
    }

    function _eq(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
