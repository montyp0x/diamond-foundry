// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// for compilation only
import {DiamondCutFacet} from "./facets/diamond/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "./facets/diamond/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "./facets/diamond/OwnershipFacet.sol";

import {IDiamondCut} from "./interfaces/diamond/IDiamondCut.sol";
import {IDiamondLoupe} from "./interfaces/diamond/IDiamondLoupe.sol";
import {Vm} from "forge-std/Vm.sol";

// internal libs (IO)
import {ManifestIO} from "./internal/io/Manifest.sol";
import {DesiredFacetsIO} from "./internal/io/DesiredFacets.sol";
import {StorageConfigIO} from "./internal/io/StorageConfig.sol";

// planning + execution
import {CutPlanner} from "./internal/plan/CutPlanner.sol";
import {PlanBuilder} from "./internal/upgrade/PlanBuilder.sol";
import {PlanExecutor} from "./internal/upgrade/PlanExecutor.sol";
import {UpgradeRunner} from "./internal/upgrade/UpgradeRunner.sol"; // still used for upgrade()
import {NamespacePolicy} from "./internal/validate/NamespacePolicy.sol";
import {FacetDeployer} from "./internal/upgrade/FacetDeployer.sol";
import {ManifestApply} from "./internal/upgrade/ManifestApply.sol";
import {InitUtils} from "./internal/upgrade/InitUtils.sol";
import {DiamondDeployer} from "./internal/upgrade/DiamondDeployer.sol";
import {FacetsPrepare} from "./internal/sync/FacetPrepare.sol";

/// @title DiamondUpgrades (manifest-only)
/// @notice Public entrypoints for deploying and upgrading Diamonds using a manifest-driven flow.
library DiamondUpgrades {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // ─────────────────────────────────────────────────────────────────────────────
    // Types
    // ─────────────────────────────────────────────────────────────────────────────

    struct Options {
        bool unsafeLayout;
        bool allowDualWrite;
        bool force;
    }

    struct DeployOpts {
        address owner;
        Options opts;
    }

    struct InitSpec {
        address target;
        bytes data;
    }

    struct FacetSpec {
        string artifact;
        bytes4[] selectors;
        string[] uses;
    }

    struct PlanOp {
        IDiamondCut.FacetCutAction action;
        address facet;
        bytes4[] selectors;
    }

    struct Plan {
        PlanOp[] ops;
        address init;
        bytes initCalldata;
        uint256 addCount;
        uint256 replaceCount;
        uint256 removeCount;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────────

    event Deployed(string indexed name, address indexed diamond);
    event Upgraded(string indexed name, address indexed diamond, bytes32 manifestStateHash);

    // ─────────────────────────────────────────────────────────────────────────────
    // Constants (core selectors)
    // ─────────────────────────────────────────────────────────────────────────────

    bytes4 internal constant SELECTOR_DIAMOND_CUT = IDiamondCut.diamondCut.selector;
    bytes4 internal constant SELECTOR_LOUPE_FACETS = IDiamondLoupe.facets.selector;
    bytes4 internal constant SELECTOR_LOUPE_FACET_FUNCTION_SELECTORS = IDiamondLoupe.facetFunctionSelectors.selector;
    bytes4 internal constant SELECTOR_LOUPE_FACET_ADDRESSES = IDiamondLoupe.facetAddresses.selector;
    bytes4 internal constant SELECTOR_LOUPE_FACET_ADDRESS = IDiamondLoupe.facetAddress.selector;

    // ─────────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Deploy a fresh Diamond using the library-owned core and add desired facets.
    function deployDiamond(string memory name, DeployOpts memory deploy, InitSpec memory initOverride)
        internal
        returns (address diamond)
    {
        // 0) Ensure .diamond-upgrades directory exists for good UX
        _ensureDiamondUpgradesDir(name);

        // 0.5) Auto-discover facets and sync selectors if needed
        FacetsPrepare.ensureAndSync(name);

        // 1) Prepare desiredPlus + initPair and validate `uses`
        DesiredFacetsIO.DesiredState memory desiredPlus;
        InitUtils.InitPair memory initPair;

        {
            // load desired + storage once, validate, compose desiredPlus in this scope
            DesiredFacetsIO.DesiredState memory desiredTmp = DesiredFacetsIO.load(name);
            StorageConfigIO.StorageConfig memory storageCfg = StorageConfigIO.load(name);

            NamespacePolicy.Options memory nsOpts =
                NamespacePolicy.Options({strictUses: false, allowDualWrite: storageCfg.allowDualWrite});
            NamespacePolicy.validate(desiredTmp, storageCfg, nsOpts);

            desiredPlus.name = desiredTmp.name;
            desiredPlus.facets = new DesiredFacetsIO.Facet[](desiredTmp.facets.length);

            // copy user facets (core facets are handled by deployCore)
            for (uint256 i = 0; i < desiredTmp.facets.length; i++) {
                desiredPlus.facets[i] = desiredTmp.facets[i];
            }

            // merge init
            initPair = InitUtils.merge(
                InitUtils.fromDesired(desiredTmp.init),
                InitUtils.InitPair({target: initOverride.target, data: initOverride.data})
            );
            desiredPlus.init = DesiredFacetsIO.InitSpec({target: initPair.target, data: initPair.data});
        } // ← desiredTmp, storageCfg, nsOpts, addLoupe go out of scope here

        // 2) Deploy core (Diamond + Cut)
        {
            DiamondDeployer.Core memory core = DiamondDeployer.deployCore(deploy.owner);
            diamond = core.diamond;
        } // ← core out of scope

        // 3) Current (empty) chain slice
        ManifestIO.ChainState memory current;
        current.chainId = block.chainid;
        current.diamond = diamond;
        current.selectors = new ManifestIO.SelectorSnapshot[](0);
        current.facets = new ManifestIO.FacetSnapshot[](0);
        current.bytecodeCache = new ManifestIO.BytecodeCacheEntry[](0);
        current.namespaces = new ManifestIO.NamespaceState[](0);
        current.history = new ManifestIO.HistoryEntry[](0);
        current.stateHash = bytes32(0);

        // 4) Resolve targets (deploy facets) → plan → execute
        FacetDeployer.Result memory res = FacetDeployer.resolveTargets(
            desiredPlus,
            current,
            /*deploy=*/
            true
        );

        PlanBuilder.Plan memory gp =
            PlanBuilder.build(current, desiredPlus, res.targets, PlanBuilder.Options({allowRemoveCore: false}));

        PlanExecutor.execute(diamond, gp.cuts, initPair.target, initPair.data);

        // 5) Rebuild manifest slice and persist
        ManifestIO.ChainState memory nextState =
            ManifestApply.rebuildAfterUpgrade(current, desiredPlus, res.targets, res.runtimeHashes);

        // Copy storage namespaces snapshot from storage.json into manifest (status-only snapshot)
        {
            StorageConfigIO.StorageConfig memory storageCfg2 = StorageConfigIO.load(name);
            ManifestIO.NamespaceState[] memory ns = new ManifestIO.NamespaceState[](storageCfg2.namespaces.length);
            for (uint256 i = 0; i < storageCfg2.namespaces.length; i++) {
                ns[i] = ManifestIO.NamespaceState({
                    namespaceId: storageCfg2.namespaces[i].namespaceId,
                    layoutHash: bytes32(0),
                    fieldsCount: 0,
                    status: ManifestIO.NamespaceStatus(uint8(storageCfg2.namespaces[i].status)),
                    supersededBy: storageCfg2.namespaces[i].supersededBy
                });
            }
            nextState.namespaces = ns;
        }

        ManifestIO.Manifest memory manifest;
        manifest.name = name;
        manifest.state = nextState;

        // history[0]
        {
            ManifestIO.HistoryEntry[] memory hist = new ManifestIO.HistoryEntry[](1);
            hist[0] = ManifestIO.HistoryEntry({
                txHash: bytes32(0),
                timestamp: block.timestamp,
                addCount: gp.addCount,
                replaceCount: gp.replaceCount,
                removeCount: gp.removeCount
            });
            manifest.state.history = hist;
        }

        manifest.state.stateHash = ManifestIO.computeStateHash(manifest.state);
        ManifestIO.save(manifest);

        emit Deployed(name, diamond);
    }

    /// @notice High-level upgrade using the manifest-only pipeline; persists the new manifest.
    function upgrade(string memory name) internal returns (address diamond) {
        // Ensure .diamond-upgrades directory exists for good UX
        _ensureDiamondUpgradesDir(name);

        // Auto-discover facets and sync selectors if needed
        FacetsPrepare.ensureAndSync(name);

        UpgradeRunner.Options memory opts =
            UpgradeRunner.Options({allowRemoveCore: false, strictUses: false, allowDualWrite: false});

        UpgradeRunner.Result memory r = UpgradeRunner.run(name, opts);
        diamond = r.diamond;

        // Mirror storage namespaces snapshot from storage.json into manifest after upgrade
        {
            StorageConfigIO.StorageConfig memory storageCfg2 = StorageConfigIO.load(name);
            ManifestIO.NamespaceState[] memory ns = new ManifestIO.NamespaceState[](storageCfg2.namespaces.length);
            for (uint256 i = 0; i < storageCfg2.namespaces.length; i++) {
                ns[i] = ManifestIO.NamespaceState({
                    namespaceId: storageCfg2.namespaces[i].namespaceId,
                    layoutHash: bytes32(0),
                    fieldsCount: 0,
                    status: ManifestIO.NamespaceStatus(uint8(storageCfg2.namespaces[i].status)),
                    supersededBy: storageCfg2.namespaces[i].supersededBy
                });
            }
            r.manifestNext.state.namespaces = ns;
        }

        // append history entry
        ManifestIO.HistoryEntry memory he = ManifestIO.HistoryEntry({
            txHash: bytes32(0),
            timestamp: block.timestamp,
            addCount: r.addCount,
            replaceCount: r.replaceCount,
            removeCount: r.removeCount
        });
        uint256 oldLen = r.manifestNext.state.history.length;
        ManifestIO.HistoryEntry[] memory newHist = new ManifestIO.HistoryEntry[](oldLen + 1);
        for (uint256 i = 0; i < oldLen; i++) {
            newHist[i] = r.manifestNext.state.history[i];
        }
        newHist[oldLen] = he;
        r.manifestNext.state.history = newHist;
        r.manifestNext.state.stateHash = ManifestIO.computeStateHash(r.manifestNext.state);

        ManifestIO.save(r.manifestNext);
        emit Upgraded(name, diamond, r.manifestNext.state.stateHash);
    }

    /// @notice Build a cut plan from manifest (current) and desired (facets.json) without executing it.
    function plan(string memory name) internal view returns (Plan memory p) {
        DesiredFacetsIO.DesiredState memory desired = DesiredFacetsIO.load(name);
        ManifestIO.Manifest memory manifest = ManifestIO.load(name);

        CutPlanner.FacetAddr[] memory targets = new CutPlanner.FacetAddr[](desired.facets.length);
        for (uint256 i = 0; i < desired.facets.length; i++) {
            targets[i].artifact = desired.facets[i].artifact;
            targets[i].facet = address(0);
        }

        PlanBuilder.Options memory pbOpts = PlanBuilder.Options({allowRemoveCore: false});
        PlanBuilder.Plan memory gp = PlanBuilder.build(manifest.state, desired, targets, pbOpts);

        p.ops = _toPlanOps(gp.cuts);
        p.addCount = gp.addCount;
        p.replaceCount = gp.replaceCount;
        p.removeCount = gp.removeCount;
        p.init = desired.init.target;
        p.initCalldata = desired.init.data;
    }

    /// @notice Execute an explicit cut plan (advanced usage).
    function executeCut(address diamond, PlanOp[] memory ops, address init, bytes memory initCalldata) internal {
        IDiamondCut.FacetCut[] memory cuts = _toFacetCuts(ops);
        PlanExecutor.execute(diamond, cuts, init, initCalldata);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────────

    function selectorFromSig(string memory sig) public pure returns (bytes4) {
        return bytes4(keccak256(bytes(sig)));
    }

    function selectorsFromSigs(string[] memory sigs) public pure returns (bytes4[] memory out) {
        out = new bytes4[](sigs.length);
        for (uint256 i = 0; i < sigs.length; i++) {
            out[i] = selectorFromSig(sigs[i]);
        }
    }

    function _toPlanOps(IDiamondCut.FacetCut[] memory cuts) internal pure returns (PlanOp[] memory out) {
        out = new PlanOp[](cuts.length);
        for (uint256 i = 0; i < cuts.length; i++) {
            out[i].action = cuts[i].action;
            out[i].facet = cuts[i].facetAddress;
            out[i].selectors = cuts[i].functionSelectors;
        }
    }

    function _toFacetCuts(PlanOp[] memory ops) internal pure returns (IDiamondCut.FacetCut[] memory out) {
        out = new IDiamondCut.FacetCut[](ops.length);
        for (uint256 i = 0; i < ops.length; i++) {
            out[i].action = ops[i].action;
            out[i].facetAddress = ops[i].facet;
            out[i].functionSelectors = ops[i].selectors;
        }
    }

    /// @notice Ensure .diamond-upgrades directory exists for good UX
    function _ensureDiamondUpgradesDir(string memory name) internal {
        // Create .diamond-upgrades directory if it doesn't exist
        try VM.createDir(".diamond-upgrades", true) {} catch {}

        // Create project-specific directory
        string memory projectDir = string(abi.encodePacked(".diamond-upgrades/", name));
        try VM.createDir(projectDir, true) {} catch {}
    }
}
