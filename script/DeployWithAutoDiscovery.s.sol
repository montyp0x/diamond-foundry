// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DiamondUpgrades} from "src/DiamondUpgrades.sol";
import {StorageInit} from "src/internal/sync/StorageInit.sol";
import {FacetSync} from "src/internal/sync/FacetSync.sol";

/// @title DeployWithAutoDiscovery
/// @notice Example deployment script that automatically discovers facets from src/example/
/// @dev This script demonstrates how to deploy a diamond with automatically discovered facets
contract DeployWithAutoDiscovery is Script {
    // Configuration constants
    string internal constant PROJECT_NAME = "example";
    string internal constant NAMESPACE_ID = "counter.v1";
    string internal constant LIB_ARTIFACT = "LibCounterStorage.sol:LibCounterStorage";
    string internal constant LIB_NAME = "LibCounterStorage";

    function run() public {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Project name:", PROJECT_NAME);
        console.log("Namespace:", NAMESPACE_ID);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Setup storage configuration
        console.log("Setting up storage configuration...");
        StorageInit.NamespaceSeed[] memory seeds = new StorageInit.NamespaceSeed[](1);
        seeds[0] = StorageInit.NamespaceSeed({
            namespaceId: NAMESPACE_ID,
            version: 1,
            artifact: LIB_ARTIFACT,
            libraryName: LIB_NAME
        });
        StorageInit.ensure({name: PROJECT_NAME, seeds: seeds, appendOnlyPolicy: true, allowDualWrite: false});

        // 2. Auto-discover and save facets from src/example/
        console.log("Auto-discovering facets from src/example/...");
        DiamondUpgrades.autoDiscoverAndSaveFacets(PROJECT_NAME, NAMESPACE_ID);

        // 3. Sync selectors from compiled artifacts
        console.log("Syncing selectors from compiled artifacts...");
        FacetSync.syncSelectors(PROJECT_NAME);

        // 4. Deploy diamond with auto-discovered facets
        console.log("Deploying diamond with auto-discovered facets...");
        address diamond = DiamondUpgrades.deployDiamondWithAutoDiscovery(
            PROJECT_NAME,
            NAMESPACE_ID,
            DiamondUpgrades.DeployOpts({
                owner: deployer,
                opts: DiamondUpgrades.Options({unsafeLayout: false, allowDualWrite: false, force: false})
            }),
            DiamondUpgrades.InitSpec({target: address(0), data: ""})
        );

        vm.stopBroadcast();

        console.log("Diamond deployed at:", diamond);
        console.log("Deployment complete!");

        // Verify deployment
        require(diamond != address(0), "Diamond deployment failed");
        console.log("Deployment verification: SUCCESS");
    }
}
