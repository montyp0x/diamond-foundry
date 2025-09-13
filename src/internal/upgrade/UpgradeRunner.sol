// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DesiredFacetsIO} from "../io/DesiredFacets.sol";
import {ManifestIO} from "../io/Manifest.sol";
import {StorageConfigIO} from "../io/StorageConfig.sol";

import {NamespacePolicy} from "../validate/NamespacePolicy.sol";
import {PlanBuilder} from "./PlanBuilder.sol";
import {FacetDeployer} from "./FacetDeployer.sol";
import {ManifestApply} from "./ManifestApply.sol";
import {PlanExecutor} from "./PlanExecutor.sol";
import {InitUtils} from "./InitUtils.sol";

/// @title UpgradeRunner
/// @notice End-to-end upgrade pipeline (manifest-only): validate → resolve/deploy → plan → execute → rebuild snapshot.
/// @dev Requires Foundry cheatcodes for facet deployment via FacetDeployer.
///      JSON I/O (load/save) is still stubbed in IO modules — this library focuses on orchestration.
library UpgradeRunner {
    /// @notice Minimal options affecting validation behavior.
    struct Options {
        bool allowRemoveCore; // allow touching core selectors
        bool strictUses; // require `uses` for facets (typically for mutating facets)
        bool allowDualWrite; // allow v1+v2 namespaces to co-exist temporarily
    }

    /// @notice Result of an upgrade run (useful for scripts/tests).
    struct Result {
        address diamond;
        uint256 addCount;
        uint256 replaceCount;
        uint256 removeCount;
        ManifestIO.Manifest manifestNext; // updated in-memory snapshot (saving is up to the caller)
    }

    /// @notice Execute a full upgrade for the named diamond.
    /// @dev I/O: DesiredFacetsIO.load / StorageConfigIO.load / ManifestIO.load must be implemented for this to run.
    function run(string memory name, Options memory opts) internal returns (Result memory r) {
        // 1) Load desired, storage config, and current manifest slice (for this chain)
        DesiredFacetsIO.DesiredState memory desiredTmp = DesiredFacetsIO.load(name);
        StorageConfigIO.StorageConfig memory storageCfg = StorageConfigIO.load(name);
        ManifestIO.Manifest memory manifest = ManifestIO.load(name);

        r.diamond = manifest.state.diamond; // must exist for upgrades

        // Core facets (Cut, Ownership, Loupe) are automatically handled by DiamondDeployer
        // so we only need to process user-defined facets from the desired state
        DesiredFacetsIO.DesiredState memory desired = desiredTmp;

        // 2) Validate `uses` ↔ storage namespaces policy (pure checks)
        // Use storage configuration's allowDualWrite to enforce migration policy regardless of caller opts
        NamespacePolicy.Options memory nsOpts =
            NamespacePolicy.Options({strictUses: opts.strictUses, allowDualWrite: storageCfg.allowDualWrite});
        NamespacePolicy.validate(desired, storageCfg, nsOpts);

        // 3) Resolve facet targets by runtime hash; deploy missing ones if needed
        FacetDeployer.Result memory res = FacetDeployer.resolveTargets(
            desired,
            manifest.state,
            /*deploy=*/
            true
        );

        // 4) Build a grouped cut plan (manifest-only diff)
        PlanBuilder.Options memory pbOpts = PlanBuilder.Options({allowRemoveCore: opts.allowRemoveCore});
        PlanBuilder.Plan memory planGrouped = PlanBuilder.build(manifest.state, desired, res.targets, pbOpts);

        // If no changes, return early (NoOp)
        if (planGrouped.cuts.length == 0) {
            r.addCount = 0;
            r.replaceCount = 0;
            r.removeCount = 0;

            // Mirror current manifest into next (stateHash may change only if caller updates namespaces/history)
            r.manifestNext = manifest;
            return r;
        }

        // 5) Prepare init from desired (pairing checks)
        InitUtils.InitPair memory initPair = InitUtils.fromDesired(desired.init);

        // 6) Execute the diamondCut (single tx, with optional init)
        PlanExecutor.execute(r.diamond, planGrouped.cuts, initPair.target, initPair.data);

        // 7) Rebuild the manifest snapshot after successful cut (selectors/facets/cache/stateHash)
        ManifestIO.ChainState memory nextState =
            ManifestApply.rebuildAfterUpgrade(manifest.state, desired, res.targets, res.runtimeHashes);

        // 8) Write result fields
        r.addCount = planGrouped.addCount;
        r.replaceCount = planGrouped.replaceCount;
        r.removeCount = planGrouped.removeCount;

        r.manifestNext.name = manifest.name;
        r.manifestNext.state = nextState;

        // NOTE: Persisting `r.manifestNext` to disk via ManifestIO.save(r.manifestNext) is left to the caller,
        // once IO.save is implemented (currently stubs would revert).
    }

    /// @notice Check if the current manifest has existing loupe selectors.
    function _hasExistingLoupeSelectors(ManifestIO.ChainState memory state) private pure returns (bool) {
        bytes4 facetsSelector = 0x7a0ed627; // IDiamondLoupe.facets.selector
        for (uint256 i = 0; i < state.selectors.length; i++) {
            if (state.selectors[i].selector == facetsSelector) {
                return true;
            }
        }
        return false;
    }

    /// @notice Return the canonical loupe selectors.
    function _getLoupeSelectors() private pure returns (bytes4[] memory sel) {
        sel = new bytes4[](4);
        sel[0] = 0x7a0ed627; // IDiamondLoupe.facets.selector
        sel[1] = 0xadfca15e; // IDiamondLoupe.facetFunctionSelectors.selector
        sel[2] = 0x52ef6b2c; // IDiamondLoupe.facetAddresses.selector
        sel[3] = 0xcdffacc6; // IDiamondLoupe.facetAddress.selector
    }

    /// @notice Check if the desired state already has an explicit loupe facet defined.
    function _hasExplicitLoupeFacet(DesiredFacetsIO.DesiredState memory desired) private pure returns (bool) {
        string memory loupeArtifact = "DiamondLoupeFacet.sol:DiamondLoupeFacet";
        bytes32 key;
        assembly {
            key := keccak256(add(loupeArtifact, 0x20), mload(loupeArtifact))
        }
        for (uint256 i = 0; i < desired.facets.length; i++) {
            if (keccak256(bytes(desired.facets[i].artifact)) == key) {
                return true;
            }
        }
        return false;
    }
}
