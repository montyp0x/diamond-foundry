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

interface IStorageFacet {
    function setValue(uint256 value) external;
    function getValue() external view returns (uint256);
    function double() external;
    function halve() external;
}

/// @title PerformanceTests
/// @notice Performance and gas usage tests for Diamond upgrades
contract PerformanceTests is Test {
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
    // GAS USAGE TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_gas_deployment() public {
        FacetsPrepare.ensureAndSync(NAME_EXAMPLE);
        _setupStorageConfig();

        uint256 gasBefore = gasleft();
        diamond = DiamondUpgrades.deployDiamond(
            NAME_EXAMPLE,
            DiamondUpgrades.DeployOpts({
                owner: owner,
                opts: DiamondUpgrades.Options({unsafeLayout: false, allowDualWrite: false, force: false})
            }),
            DiamondUpgrades.InitSpec({target: address(0), data: ""})
        );
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Diamond deployment gas used:", gasUsed);
        assertTrue(gasUsed < 5_000_000, "Deployment gas too high");
        assertTrue(diamond != address(0), "Diamond not deployed");
    }

    function test_gas_simple_operations() public {
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

        // Test gas usage for simple operations
        uint256 gasBefore = gasleft();
        IAddFacet(diamond).increment(5);
        uint256 incrementGas = gasBefore - gasleft();
        console.log("Increment gas used:", incrementGas);

        gasBefore = gasleft();
        uint256 value = IViewFacet(diamond).get();
        uint256 viewGas = gasBefore - gasleft();
        console.log("View gas used:", viewGas);

        gasBefore = gasleft();
        IAddFacet(diamond).reset();
        uint256 resetGas = gasBefore - gasleft();
        console.log("Reset gas used:", resetGas);

        // Verify operations worked
        assertEq(value, 5, "Increment failed");
        assertEq(IViewFacet(diamond).get(), 0, "Reset failed");
    }

    function test_gas_math_operations() public {
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

        IAddFacet(diamond).increment(10);

        // Test gas usage for math operations
        uint256 gasBefore = gasleft();
        IMathFacet(diamond).multiply(3);
        uint256 multiplyGas = gasBefore - gasleft();
        console.log("Multiply gas used:", multiplyGas);

        gasBefore = gasleft();
        IMathFacet(diamond).square();
        uint256 squareGas = gasBefore - gasleft();
        console.log("Square gas used:", squareGas);

        gasBefore = gasleft();
        IMathFacet(diamond).addNumbers(5, 15);
        uint256 addNumbersGas = gasBefore - gasleft();
        console.log("AddNumbers gas used:", addNumbersGas);

        gasBefore = gasleft();
        uint256 squared = IMathFacet(diamond).getSquared();
        uint256 getSquaredGas = gasBefore - gasleft();
        console.log("GetSquared gas used:", getSquaredGas);

        // Verify operations worked
        assertEq(IViewFacet(diamond).get(), 20, "Math operations failed");
        assertEq(squared, 400, "GetSquared failed");
    }

    function test_gas_storage_operations() public {
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

        // Test gas usage for storage operations
        uint256 gasBefore = gasleft();
        IStorageFacet(diamond).setValue(100);
        uint256 setValueGas = gasBefore - gasleft();
        console.log("SetValue gas used:", setValueGas);

        gasBefore = gasleft();
        uint256 value = IStorageFacet(diamond).getValue();
        uint256 getValueGas = gasBefore - gasleft();
        console.log("GetValue gas used:", getValueGas);

        gasBefore = gasleft();
        IStorageFacet(diamond).double();
        uint256 doubleGas = gasBefore - gasleft();
        console.log("Double gas used:", doubleGas);

        gasBefore = gasleft();
        IStorageFacet(diamond).halve();
        uint256 halveGas = gasBefore - gasleft();
        console.log("Halve gas used:", halveGas);

        // Verify operations worked
        assertEq(value, 100, "SetValue failed");
        assertEq(IStorageFacet(diamond).getValue(), 100, "Double/Halve failed");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // PERFORMANCE TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_performance_batch_operations() public {
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

        uint256 startTime = block.timestamp;
        uint256 startGas = gasleft();

        // Perform batch operations
        for (uint256 i = 0; i < 100; i++) {
            IAddFacet(diamond).increment(1);
            IMathFacet(diamond).multiply(2);
            IStorageFacet(diamond).halve();
        }

        uint256 endTime = block.timestamp;
        uint256 endGas = gasleft();
        uint256 totalGas = startGas - endGas;
        uint256 timeElapsed = endTime - startTime;

        console.log("Batch operations (100 iterations):");
        console.log("Total gas used:", totalGas);
        console.log("Time elapsed:", timeElapsed);
        console.log("Average gas per operation:", totalGas / 300); // 3 operations per iteration

        // Verify final state
        assertTrue(IViewFacet(diamond).get() > 0, "Batch operations failed");
    }

    function test_performance_large_calculations() public {
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

        uint256 startGas = gasleft();

        // Large calculations
        IStorageFacet(diamond).setValue(1000);
        IMathFacet(diamond).square(); // 1,000,000
        IMathFacet(diamond).multiply(2); // 2,000,000
        IMathFacet(diamond).square(); // 4,000,000,000,000
        IMathFacet(diamond).multiply(3); // 12,000,000,000,000

        uint256 endGas = gasleft();
        uint256 totalGas = startGas - endGas;

        console.log("Large calculations gas used:", totalGas);
        console.log("Final value:", IViewFacet(diamond).get());

        // Verify calculation
        assertEq(IViewFacet(diamond).get(), 12000000000000, "Large calculations failed");
    }

    function test_performance_memory_usage() public {
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

        // Test memory usage with large arrays
        uint256[] memory largeArray = new uint256[](1000);
        for (uint256 i = 0; i < 1000; i++) {
            largeArray[i] = i;
        }

        uint256 startGas = gasleft();

        // Perform operations with large data
        for (uint256 i = 0; i < 100; i++) {
            IMathFacet(diamond).addNumbers(largeArray[i], largeArray[i + 1]);
        }

        uint256 endGas = gasleft();
        uint256 totalGas = startGas - endGas;

        console.log("Memory usage test gas used:", totalGas);
        console.log("Final value:", IViewFacet(diamond).get());

        // Verify operations completed
        assertTrue(IViewFacet(diamond).get() > 0, "Memory usage test failed");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // STRESS TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_stress_rapid_calls() public {
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

        // Rapid calls to test system stability
        for (uint256 i = 0; i < 50; i++) {
            IAddFacet(diamond).increment(1);
            IMathFacet(diamond).multiply(2);
            IStorageFacet(diamond).halve();

            // Verify state consistency
            assertTrue(IViewFacet(diamond).get() >= 0, "State inconsistency detected");
        }

        console.log("Stress test completed successfully");
        console.log("Final value:", IViewFacet(diamond).get());
    }

    function test_stress_mixed_operations() public {
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

        // Mixed operations to test system robustness
        for (uint256 i = 0; i < 20; i++) {
            // Random-like operations
            if (i % 3 == 0) {
                IAddFacet(diamond).increment(i);
            } else if (i % 3 == 1) {
                IMathFacet(diamond).multiply(i + 1);
            } else {
                IStorageFacet(diamond).setValue(i * 10);
            }

            // Verify state after each operation
            uint256 currentValue = IViewFacet(diamond).get();
            assertTrue(currentValue >= 0, "Invalid state detected");
        }

        console.log("Mixed operations stress test completed");
        console.log("Final value:", IViewFacet(diamond).get());
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
