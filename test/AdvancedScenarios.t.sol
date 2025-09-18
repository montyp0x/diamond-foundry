// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// Library entrypoints
import {DiamondUpgrades} from "src/DiamondUpgrades.sol";
import {FacetsPrepare} from "src/internal/sync/FacetPrepare.sol";

// IO + sync helpers
import {DesiredFacetsIO} from "src/internal/io/DesiredFacets.sol";
import {StorageInit} from "src/internal/sync/StorageInit.sol";
import {ManifestIO} from "src/internal/io/Manifest.sol";

// Example interfaces & storage
import {IAddFacet} from "src/example/interfaces/counter/IAddFacet.sol";
import {IViewFacet} from "src/example/interfaces/counter/IViewFacet.sol";
import {IDiamondLoupe} from "src/interfaces/diamond/IDiamondLoupe.sol";
import {IERC173} from "src/interfaces/diamond/IERC173.sol";

// Test interfaces for additional facets
interface IMathFacet {
    function multiply(uint256 factor) external;
    function square() external;
    function addNumbers(uint256 a, uint256 b) external;
    function getSquared() external view returns (uint256);
}

interface IStorageFacet {
    function setValue(uint256 value) external;
    function getValue() external view returns (uint256);
    function double() external;
    function halve() external;
}

interface IEventFacet {
    function setWithEvent(uint256 value) external;
    function emitSpecial(string memory message) external;
    function emitComplex(uint256 id, string memory data, uint256[] memory numbers) external;
}

interface IAdminFacet {
    function admin() external view returns (address);
    function paused() external view returns (bool);
    function setAdmin(address newAdmin) external;
    function pause() external;
    function unpause() external;
    function adminSetValue(uint256 value) external;
    function initializeAdmin() external;
}

// Event definitions for testing
event ValueChanged(uint256 oldValue, uint256 newValue);

event SpecialEvent(string message, uint256 value);

event ComplexEvent(uint256 indexed id, string data, uint256[] numbers);

/// @title AdvancedScenarios
/// @notice Advanced testing scenarios for Diamond upgrades
contract AdvancedScenarios is Test {
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
    // SCENARIO 06: MATH OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_06_math_operations() public {
        // Ensure facets are synced (should have AddFacet, ViewFacet, MathFacet)
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

        // Test basic operations
        IAddFacet(diamond).increment(5);
        assertEq(IViewFacet(diamond).get(), 5, "Initial increment failed");

        // Test math operations
        IMathFacet(diamond).multiply(3);
        assertEq(IViewFacet(diamond).get(), 15, "Multiply failed");

        IMathFacet(diamond).square();
        assertEq(IViewFacet(diamond).get(), 225, "Square failed");

        // Test addNumbers
        IMathFacet(diamond).addNumbers(10, 20);
        assertEq(IViewFacet(diamond).get(), 30, "AddNumbers failed");

        // Test getSquared
        uint256 squared = IMathFacet(diamond).getSquared();
        assertEq(squared, 900, "GetSquared failed");

        console.log("[OK] Scenario 06: Math operations successful");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 07: STORAGE MANIPULATION
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_07_storage_manipulation() public {
        // Ensure facets are synced (should have AddFacet, ViewFacet, StorageFacet)
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

        // Test storage operations
        IStorageFacet(diamond).setValue(100);
        assertEq(IStorageFacet(diamond).getValue(), 100, "SetValue failed");
        assertEq(IViewFacet(diamond).get(), 100, "ViewFacet should see same value");

        IStorageFacet(diamond).double();
        assertEq(IStorageFacet(diamond).getValue(), 200, "Double failed");

        IStorageFacet(diamond).halve();
        assertEq(IStorageFacet(diamond).getValue(), 100, "Halve failed");

        // Test interaction with AddFacet
        IAddFacet(diamond).increment(50);
        assertEq(IStorageFacet(diamond).getValue(), 150, "AddFacet interaction failed");

        console.log("[OK] Scenario 07: Storage manipulation successful");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 08: EVENT EMISSION
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_08_event_emission() public {
        // Ensure facets are synced (should have AddFacet, ViewFacet, EventFacet)
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

        // Test event emission
        IAddFacet(diamond).increment(10);

        // Test setWithEvent
        vm.expectEmit(true, true, true, true);
        emit ValueChanged(10, 25);
        IEventFacet(diamond).setWithEvent(25);
        assertEq(IViewFacet(diamond).get(), 25, "SetWithEvent failed");

        // Test emitSpecial
        vm.expectEmit(false, false, false, true);
        emit SpecialEvent("test message", 25);
        IEventFacet(diamond).emitSpecial("test message");

        // Test emitComplex
        uint256[] memory numbers = new uint256[](3);
        numbers[0] = 1;
        numbers[1] = 2;
        numbers[2] = 3;

        vm.expectEmit(true, false, false, true);
        emit ComplexEvent(123, "complex data", numbers);
        IEventFacet(diamond).emitComplex(123, "complex data", numbers);

        console.log("[OK] Scenario 08: Event emission successful");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 09: ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_09_admin_functions() public {
        // Ensure facets are synced (should have AddFacet, ViewFacet, AdminFacet)
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

        // Initialize admin
        IAdminFacet(diamond).initializeAdmin();
        assertEq(IAdminFacet(diamond).admin(), address(this), "Admin not set");

        // Test admin functions
        IAdminFacet(diamond).adminSetValue(100);
        assertEq(IViewFacet(diamond).get(), 100, "AdminSetValue failed");

        // Test pause/unpause
        IAdminFacet(diamond).pause();
        assertTrue(IAdminFacet(diamond).paused(), "Contract not paused");

        // Should fail when paused
        vm.expectRevert("Paused");
        IAdminFacet(diamond).adminSetValue(200);

        IAdminFacet(diamond).unpause();
        assertFalse(IAdminFacet(diamond).paused(), "Contract still paused");

        // Should work when unpaused
        IAdminFacet(diamond).adminSetValue(200);
        assertEq(IViewFacet(diamond).get(), 200, "AdminSetValue after unpause failed");

        // Test admin change
        address newAdmin = makeAddr("newAdmin");
        IAdminFacet(diamond).setAdmin(newAdmin);
        assertEq(IAdminFacet(diamond).admin(), newAdmin, "Admin change failed");

        console.log("[OK] Scenario 09: Admin functions successful");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 10: COMPLEX INTEGRATION
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_10_complex_integration() public {
        // Ensure facets are synced (should have all facets)
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

        // Initialize admin
        IAdminFacet(diamond).initializeAdmin();

        // Complex workflow
        IAddFacet(diamond).increment(5);
        assertEq(IViewFacet(diamond).get(), 5, "Step 1 failed");

        IMathFacet(diamond).multiply(2);
        assertEq(IViewFacet(diamond).get(), 10, "Step 2 failed");

        IStorageFacet(diamond).double();
        assertEq(IViewFacet(diamond).get(), 20, "Step 3 failed");

        IMathFacet(diamond).square();
        assertEq(IViewFacet(diamond).get(), 400, "Step 4 failed");

        // Test events
        vm.expectEmit(true, true, true, true);
        emit ValueChanged(400, 500);
        IEventFacet(diamond).setWithEvent(500);
        assertEq(IViewFacet(diamond).get(), 500, "Step 5 failed");

        // Test admin operations
        IAdminFacet(diamond).adminSetValue(1000);
        assertEq(IViewFacet(diamond).get(), 1000, "Step 6 failed");

        // Verify all facets are working
        assertEq(IMathFacet(diamond).getSquared(), 1000000, "MathFacet verification failed");
        assertEq(IStorageFacet(diamond).getValue(), 1000, "StorageFacet verification failed");
        assertEq(IAdminFacet(diamond).admin(), address(this), "AdminFacet verification failed");

        console.log("[OK] Scenario 10: Complex integration successful");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // EDGE CASE TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_edge_case_zero_values() public {
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

        // Test with zero values
        IAddFacet(diamond).increment(0);
        assertEq(IViewFacet(diamond).get(), 0, "Zero increment failed");

        IMathFacet(diamond).multiply(0);
        assertEq(IViewFacet(diamond).get(), 0, "Zero multiply failed");

        IStorageFacet(diamond).setValue(0);
        assertEq(IViewFacet(diamond).get(), 0, "Zero setValue failed");

        console.log("[OK] Edge case: Zero values successful");
    }

    function test_edge_case_large_values() public {
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

        // Test with large values
        uint256 largeValue = type(uint256).max / 2;
        IStorageFacet(diamond).setValue(largeValue);
        assertEq(IViewFacet(diamond).get(), largeValue, "Large value set failed");

        IStorageFacet(diamond).double();
        assertEq(IViewFacet(diamond).get(), largeValue * 2, "Large value double failed");

        console.log("[OK] Edge case: Large values successful");
    }

    function test_edge_case_rapid_upgrades() public {
        // Test rapid upgrades
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

        // Perform multiple operations rapidly
        for (uint256 i = 0; i < 10; i++) {
            IAddFacet(diamond).increment(1);
            IMathFacet(diamond).multiply(2);
            IStorageFacet(diamond).halve();
        }

        // Verify final state
        assertTrue(IViewFacet(diamond).get() > 0, "Rapid upgrades failed");

        console.log("[OK] Edge case: Rapid upgrades successful");
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
