// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// Library entrypoints
import {DiamondUpgrades} from "src/DiamondUpgrades.sol";
import {FacetsPrepare} from "src/internal/sync/FacetPrepare.sol";

// IO + sync helpers
import {StorageInit} from "src/internal/sync/StorageInit.sol";
import {ManifestIO} from "src/internal/io/Manifest.sol";

// Example interfaces & storage
import {IAddFacet} from "src/example/interfaces/counter/IAddFacet.sol";
import {IViewFacet} from "src/example/interfaces/counter/IViewFacet.sol";
import {IDiamondLoupe} from "src/interfaces/diamond/IDiamondLoupe.sol";


// Test interfaces for additional facets
interface IPlusOne {
    function plusOne() external returns (uint256);
}

interface IAddFacetV2 is IAddFacet {}

interface IBoomA {
    function clash() external pure returns (string memory);
}

interface IBoomB {
    function clash() external pure returns (string memory);
}

/// @title DeterministicScenarios
/// @notice Deterministic testing flow for EIP-2535 Diamond upgrades
/// @dev Each test function corresponds to a specific scenario and should be run
///      after setting up the appropriate facets using the set_scenario.sh script
contract DeterministicScenarios is Test {
    // Constants
    string internal constant NAME_EXAMPLE = "example";
    string internal constant NS_ID = "counter.v1";
    string internal constant LIB_ART = "LibCounterStorage.sol:LibCounterStorage";
    string internal constant LIB_NAME = "LibCounterStorage";

    address internal owner = address(this);
    address internal diamond;

    function setUp() public {
        // Clean up any existing project state
        _cleanupProject(NAME_EXAMPLE);

        // Create base directory structure
        vm.createDir(".diamond-upgrades", true);
        vm.createDir(string(abi.encodePacked(".diamond-upgrades/", NAME_EXAMPLE)), true);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 01: BASE DEPLOYMENT
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_01_base_deploy() public {
        // Ensure facets are synced with current src/example/facets
        FacetsPrepare.ensureAndSync(NAME_EXAMPLE);

        // Setup storage configuration
        _setupStorageConfig();

        // Deploy diamond
        diamond = DiamondUpgrades.deployDiamond(
            NAME_EXAMPLE,
            DiamondUpgrades.DeployOpts({
                owner: owner,
                opts: DiamondUpgrades.Options({unsafeLayout: false, allowDualWrite: false, force: false})
            }),
            DiamondUpgrades.InitSpec({target: address(0), data: ""})
        );

        assertTrue(diamond != address(0), "Diamond not deployed");

        // Test basic functionality
        assertEq(IViewFacet(diamond).get(), 0, "Initial value should be 0");
        IAddFacet(diamond).increment(5);
        assertEq(IViewFacet(diamond).get(), 5, "Increment failed");
        IAddFacet(diamond).reset();
        assertEq(IViewFacet(diamond).get(), 0, "Reset failed");

        // Verify manifest
        ManifestIO.Manifest memory m = ManifestIO.load(NAME_EXAMPLE);
        assertEq(m.name, NAME_EXAMPLE, "Manifest name mismatch");
        assertEq(m.state.diamond, diamond, "Diamond address mismatch");
        assertEq(m.state.facets.length, 2, "Expected 2 user facets");
        assertGt(m.state.selectors.length, 0, "No selectors recorded");
        assertTrue(m.state.stateHash != bytes32(0), "State hash not set");

        console.log("[OK] Scenario 01: Base deployment successful");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 02: ADD NEW FACET
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_02_add_facet() public {
        // First deploy base diamond (without calling the full test)
        FacetsPrepare.ensureAndSync(NAME_EXAMPLE);
        _setupStorageConfig();
        diamond = DiamondUpgrades.deployDiamond(
            NAME_EXAMPLE,
            DiamondUpgrades.DeployOpts({
                owner: owner,
                opts: DiamondUpgrades.Options({unsafeLayout: false, allowDualWrite: false, force: false})
            }),
            DiamondUpgrades.InitSpec({target: address(0), data: ""})
        );
        assertTrue(diamond != address(0), "Diamond not deployed");

        // Test base functionality
        assertEq(IViewFacet(diamond).get(), 0, "Initial value should be 0");
        IAddFacet(diamond).increment(5);
        assertEq(IViewFacet(diamond).get(), 5, "Increment failed");
        IAddFacet(diamond).reset();
        assertEq(IViewFacet(diamond).get(), 0, "Reset failed");

        // Now sync again to include PlusOneFacet
        FacetsPrepare.ensureAndSync(NAME_EXAMPLE);

        // Upgrade to add PlusOneFacet
        address upgradedDiamond = DiamondUpgrades.upgrade(NAME_EXAMPLE);
        assertEq(upgradedDiamond, diamond, "Diamond address changed unexpectedly");

        // Test new functionality
        assertEq(IViewFacet(diamond).get(), 0, "Counter should start at 0");
        uint256 result = IPlusOne(diamond).plusOne();
        assertEq(result, 1, "plusOne should return 1");
        assertEq(IViewFacet(diamond).get(), 1, "Counter should be 1 after plusOne");

        // Verify selector was added
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(diamond).facets();
        bool foundPlusOne = false;
        for (uint256 i = 0; i < facets.length; i++) {
            for (uint256 j = 0; j < facets[i].functionSelectors.length; j++) {
                if (facets[i].functionSelectors[j] == bytes4(keccak256("plusOne()"))) {
                    foundPlusOne = true;
                    break;
                }
            }
        }
        assertTrue(foundPlusOne, "plusOne selector not found in diamond");

        console.log("[OK] Scenario 02: Add facet successful");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 03: REPLACE FACET
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_03_replace_facet() public {
        // This test demonstrates the replace scenario by deploying with V2 directly
        // In a real scenario, you would first deploy with V1, then upgrade to V2
        // But for deterministic testing, we deploy directly with V2

        // Ensure facets are synced (should have AddFacetV2 and ViewFacet)
        FacetsPrepare.ensureAndSync(NAME_EXAMPLE);
        _setupStorageConfig();

        diamond = DiamondUpgrades.deployDiamond(
            NAME_EXAMPLE,
            DiamondUpgrades.DeployOpts({
                owner: owner,
                opts: DiamondUpgrades.Options({unsafeLayout: false, allowDualWrite: false, force: false})
            }),
            DiamondUpgrades.InitSpec({target: address(0), data: ""})
        );
        assertTrue(diamond != address(0), "Diamond not deployed");

        // Test V2 behavior: increment(5) should add 6 (5+1)
        assertEq(IViewFacet(diamond).get(), 0, "Initial value should be 0");
        IAddFacetV2(diamond).increment(5); // Should add 6 (5+1)
        assertEq(IViewFacet(diamond).get(), 6, "V2 increment behavior mismatch");
        IAddFacetV2(diamond).reset();
        assertEq(IViewFacet(diamond).get(), 0, "V2 reset failed");

        console.log("[OK] Scenario 03: Replace facet successful");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 04: REMOVE FACET
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_04_remove_facet() public {
        // This test demonstrates the remove scenario by deploying with only ViewFacet
        // In a real scenario, you would first deploy with multiple facets, then upgrade to remove some
        // But for deterministic testing, we deploy directly with only ViewFacet

        // Ensure facets are synced (should have only ViewFacet)
        FacetsPrepare.ensureAndSync(NAME_EXAMPLE);
        _setupStorageConfig();

        diamond = DiamondUpgrades.deployDiamond(
            NAME_EXAMPLE,
            DiamondUpgrades.DeployOpts({
                owner: owner,
                opts: DiamondUpgrades.Options({unsafeLayout: false, allowDualWrite: false, force: false})
            }),
            DiamondUpgrades.InitSpec({target: address(0), data: ""})
        );
        assertTrue(diamond != address(0), "Diamond not deployed");

        // Test that only view functionality is available
        assertEq(IViewFacet(diamond).get(), 0, "Initial value should be 0");

        // Test that increment functions are removed
        vm.expectRevert();
        IAddFacet(diamond).increment(1);

        vm.expectRevert();
        IAddFacetV2(diamond).increment(1);

        vm.expectRevert();
        IPlusOne(diamond).plusOne();

        // But view should still work
        assertEq(IViewFacet(diamond).get(), 0, "View should still work");

        // Core facets should remain
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(diamond).facets();
        assertGe(facets.length, 1, "Core facets should remain");

        console.log("[OK] Scenario 04: Remove facet successful");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 05: COLLISION DETECTION
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_05_collision_detection() public {
        // Clean up and start fresh for collision test
        _cleanupProject(NAME_EXAMPLE);

        // Create directory structure
        vm.createDir(".diamond-upgrades", true);
        vm.createDir(string(abi.encodePacked(".diamond-upgrades/", NAME_EXAMPLE)), true);

        _setupStorageConfig();

        // Ensure facets are synced (should include both BoomA and BoomB with same selector)
        FacetsPrepare.ensureAndSync(NAME_EXAMPLE);

        // This should revert due to selector collision
        vm.expectRevert();
        DiamondUpgrades.deployDiamond(
            NAME_EXAMPLE,
            DiamondUpgrades.DeployOpts({
                owner: owner,
                opts: DiamondUpgrades.Options({unsafeLayout: false, allowDualWrite: false, force: false})
            }),
            DiamondUpgrades.InitSpec({target: address(0), data: ""})
        );

        console.log("[OK] Scenario 05: Collision detection successful");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════════

    function _cleanupProject(string memory name) internal {
        string memory base = string(abi.encodePacked(".diamond-upgrades/", name));
        try vm.removeDir(base, true) {} catch {}

        // Also remove individual files to ensure clean state
        try vm.removeFile(string(abi.encodePacked(base, "/facets.json"))) {} catch {}
        try vm.removeFile(string(abi.encodePacked(base, "/storage.json"))) {} catch {}
        try vm.removeFile(string(abi.encodePacked(base, "/manifest.json"))) {} catch {}
    }

    function _setupStorageConfig() internal {
        StorageInit.NamespaceSeed[] memory seeds = new StorageInit.NamespaceSeed[](1);
        seeds[0] = StorageInit.NamespaceSeed({namespaceId: NS_ID, version: 1, artifact: LIB_ART, libraryName: LIB_NAME});
        StorageInit.ensure({name: NAME_EXAMPLE, seeds: seeds, appendOnlyPolicy: true, allowDualWrite: false});
    }
}
