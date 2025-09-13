// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DiamondUpgrades} from "src/DiamondUpgrades.sol";
import {FacetSync} from "src/internal/sync/FacetSync.sol";

/// @title UpgradeWithAutoDiscovery
/// @notice Example upgrade script that automatically discovers facets from src/example/
/// @dev This script demonstrates how to upgrade a diamond with automatically discovered facets
contract UpgradeWithAutoDiscovery is Script {
    // Configuration constants
    string internal constant PROJECT_NAME = "example";
    string internal constant NAMESPACE_ID = "counter.v1";

    function run() public {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Upgrader address:", deployer);
        console.log("Project name:", PROJECT_NAME);
        console.log("Namespace:", NAMESPACE_ID);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Auto-discover and save facets from src/example/
        console.log("Auto-discovering facets from src/example/...");
        DiamondUpgrades.autoDiscoverAndSaveFacets(PROJECT_NAME, NAMESPACE_ID);

        // 2. Sync selectors from compiled artifacts
        console.log("Syncing selectors from compiled artifacts...");
        FacetSync.syncSelectors(PROJECT_NAME);

        // 3. Upgrade diamond with auto-discovered facets
        console.log("Upgrading diamond with auto-discovered facets...");
        address diamond = DiamondUpgrades.upgradeWithAutoDiscovery(PROJECT_NAME, NAMESPACE_ID);

        vm.stopBroadcast();

        console.log("Diamond upgraded at:", diamond);
        console.log("Upgrade complete!");

        // Verify upgrade
        require(diamond != address(0), "Diamond upgrade failed");
        console.log("Upgrade verification: SUCCESS");
    }
}
