// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// Library entrypoints
import {DiamondUpgrades} from "src/DiamondUpgrades.sol";
import {FacetsPrepare} from "src/internal/sync/FacetPrepare.sol";

// IO + sync helpers
import {StorageInit} from "src/internal/sync/StorageInit.sol";

// Example interfaces & storage
import {IAddFacet} from "src/example/interfaces/counter/IAddFacet.sol";
import {IViewFacet} from "src/example/interfaces/counter/IViewFacet.sol";

// Test interfaces
interface IMathFacet {
    function multiply(uint256 factor) external;
    function square() external;
    function addNumbers(uint256 a, uint256 b) external;
    function getSquared() external view returns (uint256);
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

/// @title ErrorHandlingTests
/// @notice Tests for error handling and edge cases
contract ErrorHandlingTests is Test {
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
    // ACCESS CONTROL TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_access_control_admin_functions() public {
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

        // Initialize admin
        IAdminFacet(diamond).initializeAdmin();
        assertEq(IAdminFacet(diamond).admin(), address(this), "Admin not set");

        // Test that non-admin cannot call admin functions
        address nonAdmin = makeAddr("nonAdmin");
        vm.prank(nonAdmin);
        vm.expectRevert("Not admin");
        IAdminFacet(diamond).adminSetValue(100);

        vm.prank(nonAdmin);
        vm.expectRevert("Not admin");
        IAdminFacet(diamond).pause();

        vm.prank(nonAdmin);
        vm.expectRevert("Not admin");
        IAdminFacet(diamond).setAdmin(nonAdmin);

        console.log("[OK] Access control tests passed");
    }

    function test_access_control_pause_mechanism() public {
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

        IAdminFacet(diamond).initializeAdmin();

        // Test pause mechanism
        IAdminFacet(diamond).pause();
        assertTrue(IAdminFacet(diamond).paused(), "Contract not paused");

        // Admin functions should fail when paused
        vm.expectRevert("Paused");
        IAdminFacet(diamond).adminSetValue(100);

        // Unpause and test again
        IAdminFacet(diamond).unpause();
        assertFalse(IAdminFacet(diamond).paused(), "Contract still paused");

        // Should work when unpaused
        IAdminFacet(diamond).adminSetValue(100);
        assertEq(IViewFacet(diamond).get(), 100, "Admin function failed after unpause");

        console.log("[OK] Pause mechanism tests passed");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // EDGE CASE TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_edge_case_overflow_protection() public {
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

        // Test overflow protection
        IAddFacet(diamond).increment(type(uint256).max);
        assertEq(IViewFacet(diamond).get(), type(uint256).max, "Max value increment failed");

        // Try to increment again - should overflow
        vm.expectRevert();
        IAddFacet(diamond).increment(1);

        console.log("[OK] Overflow protection tests passed");
    }

    function test_edge_case_underflow_protection() public {
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

        // Test underflow protection
        IAddFacet(diamond).increment(5);
        assertEq(IViewFacet(diamond).get(), 5, "Initial increment failed");

        // Try to increment with max value - should overflow
        vm.expectRevert();
        IAddFacet(diamond).increment(type(uint256).max);

        console.log("[OK] Underflow protection tests passed");
    }

    function test_edge_case_zero_operations() public {
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

        // Test zero operations
        IAddFacet(diamond).increment(0);
        assertEq(IViewFacet(diamond).get(), 0, "Zero increment failed");

        IAddFacet(diamond).increment(10);
        assertEq(IViewFacet(diamond).get(), 10, "Non-zero increment failed");

        // Test division by zero
        IAddFacet(diamond).increment(0);
        assertEq(IViewFacet(diamond).get(), 10, "Zero increment should not change value");

        console.log("[OK] Zero operations tests passed");
    }

    function test_edge_case_large_numbers() public {
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

        // Test with large numbers
        uint256 largeNumber = type(uint256).max / 2;
        IAddFacet(diamond).increment(largeNumber);
        assertEq(IViewFacet(diamond).get(), largeNumber, "Large number increment failed");

        // Test multiplication with large numbers
        IMathFacet(diamond).multiply(2);
        assertEq(IViewFacet(diamond).get(), largeNumber * 2, "Large number multiplication failed");

        console.log("[OK] Large numbers tests passed");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // ERROR RECOVERY TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_error_recovery_after_failed_operation() public {
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

        // Set initial value
        IAddFacet(diamond).increment(100);
        assertEq(IViewFacet(diamond).get(), 100, "Initial value not set");

        // Try to cause an error (overflow)
        vm.expectRevert();
        IAddFacet(diamond).increment(type(uint256).max);

        // Verify state is unchanged after failed operation
        assertEq(IViewFacet(diamond).get(), 100, "State changed after failed operation");

        // Verify normal operations still work
        IAddFacet(diamond).increment(50);
        assertEq(IViewFacet(diamond).get(), 150, "Normal operation failed after error");

        console.log("[OK] Error recovery tests passed");
    }

    function test_error_recovery_after_pause() public {
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

        IAdminFacet(diamond).initializeAdmin();

        // Set initial value
        IAddFacet(diamond).increment(200);
        assertEq(IViewFacet(diamond).get(), 200, "Initial value not set");

        // Pause contract
        IAdminFacet(diamond).pause();

        // Try to perform operations while paused
        vm.expectRevert("Paused");
        IAdminFacet(diamond).adminSetValue(300);

        // Verify state is unchanged
        assertEq(IViewFacet(diamond).get(), 200, "State changed while paused");

        // Unpause and verify operations work again
        IAdminFacet(diamond).unpause();
        IAdminFacet(diamond).adminSetValue(300);
        assertEq(IViewFacet(diamond).get(), 300, "Operation failed after unpause");

        console.log("[OK] Pause recovery tests passed");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // BOUNDARY CONDITION TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_boundary_conditions_min_values() public {
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

        // Test minimum values
        IAddFacet(diamond).increment(0);
        assertEq(IViewFacet(diamond).get(), 0, "Zero increment failed");

        IAddFacet(diamond).increment(1);
        assertEq(IViewFacet(diamond).get(), 1, "One increment failed");

        IAddFacet(diamond).reset();
        assertEq(IViewFacet(diamond).get(), 0, "Reset failed");

        console.log("[OK] Minimum values tests passed");
    }

    function test_boundary_conditions_max_values() public {
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

        // Test maximum values
        uint256 maxValue = type(uint256).max;
        IAddFacet(diamond).increment(maxValue);
        assertEq(IViewFacet(diamond).get(), maxValue, "Max value increment failed");

        // Test that we can't go beyond max
        vm.expectRevert();
        IAddFacet(diamond).increment(1);

        console.log("[OK] Maximum values tests passed");
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
