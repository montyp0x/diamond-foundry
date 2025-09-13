// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../errors/Errors.sol";
import {DesiredFacetsIO} from "../io/DesiredFacets.sol";
import {StorageConfigIO} from "../io/StorageConfig.sol";

/// @title NamespacePolicy
/// @notice Validates `uses` declarations of facets against storage namespace config.
/// @dev Pure checks only; integrate this before building/executing a cut.
library NamespacePolicy {
    /// @notice Validation options.
    struct Options {
        bool strictUses;       // if true, every facet must declare non-empty `uses` (for mutating facets)
        bool allowDualWrite;   // if false, using a Replaced namespace is forbidden
    }

    /// @notice Validate desired facets against storage config.
    /// @dev Reverts with clear custom errors on policy violations.
    function validate(
        DesiredFacetsIO.DesiredState memory desired,
        StorageConfigIO.StorageConfig memory storageCfg,
        Options memory opts
    ) internal pure {
        // Track which namespaces are referenced, for optional cross-checks if needed later
        // (e.g., ensuring declared namespaces exist).
        for (uint256 i = 0; i < desired.facets.length; i++) {
            DesiredFacetsIO.Facet memory f = desired.facets[i];

            // strict mode: require uses (you may decide to skip view-only facets in higher layer)
            if (opts.strictUses && f.uses.length == 0) {
                revert Errors.UsesMissing(f.artifact);
            }

            // Validate each namespace reference
            for (uint256 u = 0; u < f.uses.length; u++) {
                string memory nsId = f.uses[u];

                // Must exist in storage config
                (bool ok, uint256 idx) = StorageConfigIO.find(storageCfg, nsId);
                if (!ok) revert Errors.NamespaceConfigMissing(nsId);

                StorageConfigIO.NamespaceConfig memory ns = storageCfg.namespaces[idx];

                // Disallow using a Replaced namespace unless dual write is explicitly allowed
                if (ns.status == StorageConfigIO.NamespaceStatus.Replaced && !opts.allowDualWrite) {
                    revert Errors.NamespaceReplaced(nsId, ns.supersededBy);
                }
            }

            // When dual-write is disabled, disallow declaring both a namespace and its successor together
            if (!opts.allowDualWrite && f.uses.length > 1) {
                for (uint256 a = 0; a < f.uses.length; a++) {
                    for (uint256 b = a + 1; b < f.uses.length; b++) {
                        string memory nsA = f.uses[a];
                        string memory nsB = f.uses[b];
                        if (StorageConfigIO.isReplacedBy(storageCfg, nsA, nsB)) {
                            revert Errors.NamespaceReplaced(nsA, nsB);
                        }
                        if (StorageConfigIO.isReplacedBy(storageCfg, nsB, nsA)) {
                            revert Errors.NamespaceReplaced(nsB, nsA);
                        }
                    }
                }
            }
        }
    }
}
