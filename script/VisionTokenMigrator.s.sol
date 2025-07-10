// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.28;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {VisionTokenMigrator} from "../src/VisionTokenMigrator.sol";

/**
 * @title Deploy Vision token migrator contract
 *
 * @notice Deploy the contract that will migrate the Pantos and BEST tokens to the Vision token
 *
 * @dev Usage
 * Deploy by any gas paying account:
 * forge script ./script/VisionTokenMigrator.s.sol --account <account> \
 *     --rpc-url <rpc alias> --slow --force --sig \
 *     "deploy(address, address, address, address, address)" \
 *     <pantosTokenAddress> <bestTokenAddress> <visionTokenAddress> <criticalOps> <defaultAdmin>
 * Start token migration:
 * forge script ./script/VisionTokenMigrator.s.sol --account <account> \
 *     --rpc-url <rpc alias> --slow --force --sig \
 *     "startTokenMigration(uint256)" \
 *     <amount>
 */
contract VisionTokenMigratorScript is Script {
    VisionTokenMigrator public visionTokenMigrator;

    function deploy(
        address pantosTokenAddress,
        address bestTokenAddress,
        address visionTokenAddress,
        address criticalOps,
        address defaultAdmin
    ) external {
        vm.broadcast();
        visionTokenMigrator = new VisionTokenMigrator(
            pantosTokenAddress, bestTokenAddress, visionTokenAddress, criticalOps, defaultAdmin
        );

        logDetails(visionTokenMigrator);
    }

    function startTokenMigration(address visionTokenMigratorAddress, uint256 amount) external {
        visionTokenMigrator = VisionTokenMigrator(visionTokenMigratorAddress);

        vm.broadcast();
        visionTokenMigrator.startTokenMigration(amount);

        console.log("Token migration started with Vision token amount: ", amount);
        logDetails(visionTokenMigrator);
    }

    function logDetails(VisionTokenMigrator visionTokenMigrator_) public view {
        console.log("VisionTokenMigrator deployed at: ", address(visionTokenMigrator_));
        console.log("isTokenMigrationStarted: ", visionTokenMigrator_.isTokenMigrationStarted());
        console.log("getPantosToVisionExchangeRate: ", visionTokenMigrator_.getPantosToVisionExchangeRate());
        console.log("getBestToVisionExchangeRate: ", visionTokenMigrator_.getBestToVisionExchangeRate());
        console.log("getExchangeRateScalingFactor: ", visionTokenMigrator_.getExchangeRateScalingFactor());
        console.log("getPantosTokenAddress: ", visionTokenMigrator_.getPantosTokenAddress());
        console.log("getBestTokenAddress: ", visionTokenMigrator_.getBestTokenAddress());
        console.log("getVisionTokenAddress: ", visionTokenMigrator_.getVisionTokenAddress());
    }
}
