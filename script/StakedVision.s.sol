// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC20} from "@solmate/contracts/tokens/ERC20.sol";

import {StakedVision} from "../src/StakedVision.sol";

/**
 * @title Staked vision scripts
 *
 * @notice Deploy and manage the staked Vision contract
 *
 * @dev Usage
 * Deploy
 * forge script ./script/StakedVision.s.sol --account <account> --password <password>
 * --rpc-url <rpc-url> --sig "deployStakedVision(address,uint256,address,address,address)"
 * <visionTokenAddress> <cooldownPeriod> <pauser> <criticalOps> <defaultAdmin>
 *
 * Add cycle
 * forge script ./script/StakedVision.s.sol --account <account> --password <password>
 * --rpc-url <rpc-url> --sig "createRewardsCycle(uint256,uint256,uint256,address,address)"
 * <rewardsAmount> <cycleDuration> <bpsYieldCapPerSecond> <visionTokenAddress> <stakedVisionAddress>
 *
 * Withdraw all surplus rewards
 * forge script ./script/StakedVision.s.sol --account <account> --password <password>
 * --rpc-url <rpc-url> --sig "withdrawSurplusRewards(address, address)"
 * <receiver> <stakedVisionAddress>
 *
 * Rescue tokens
 * forge script ./script/StakedVision.s.sol --account <account> --password <password>
 * --rpc-url <rpc-url> --sig "createRewardsCycle(address,uint256,address,address)"
 * <token> <amount> <to> <stakedVisionAddress>
 *
 * Update cooldown duration
 * forge script ./script/StakedVision.s.sol --account <account> --password <password>
 * --rpc-url <rpc-url> --sig "updateCooldownDuration(uint256,address)"
 * <cooldownDuration> <stakedVisionAddress>
 *
 * Update bpsYieldCapPerSecond
 * forge script ./script/StakedVision.s.sol --account <account> --password <password>
 * --rpc-url <rpc-url> --sig "updateBpsYieldCapPerSecond(uint256,address)"
 * <bpsYieldCapPerSecond> <stakedVisionAddress>
 */
contract StakedVisionScript is Script {
    StakedVision public stakedVision;
    ERC20 public visionToken;

    function deployStakedVision(
        address visionTokenAddress,
        uint256 cooldownPeriod,
        address pauser,
        address criticalOps,
        address defaultAdmin
    ) external {
        vm.startBroadcast();

        stakedVision = new StakedVision(ERC20(visionTokenAddress), cooldownPeriod, pauser, criticalOps, defaultAdmin);
        console.log("Staked Vision contract deployed at", address(stakedVision));

        vm.stopBroadcast();
    }

    function createRewardsCycle(
        uint256 amount,
        uint256 duration,
        uint256 bpsYieldCapPerSecond,
        address visionTokenAddress,
        address stakedVisionAddress
    ) public {
        visionToken = ERC20(visionTokenAddress);
        stakedVision = StakedVision(stakedVisionAddress);

        vm.startBroadcast();

        visionToken.transfer(stakedVisionAddress, amount);
        stakedVision.createRewardsCycle(amount, block.timestamp + duration, bpsYieldCapPerSecond);
        (uint256 unvestedAmount, uint256 endTimestamp,,, uint256 yieldCap) = stakedVision.rewardsCycle();
        console.log(
            "Cycle created. Unvested rewards: %s; End timestamp: %s; bpsYieldCapPerSecond: %s",
            unvestedAmount,
            endTimestamp,
            yieldCap
        );

        vm.stopBroadcast();
    }

    function withdrawSurplusRewards(address receiver, address stakedVisionAddress) external {
        stakedVision = StakedVision(stakedVisionAddress);

        vm.startBroadcast();

        stakedVision.withdrawSurplusRewards(receiver);
        console.log("Entire surplus withdrawn to ", receiver);

        vm.stopBroadcast();
    }

    function rescueTokens(address token, uint256 amount, address to, address stakedVisionAddress) external {
        stakedVision = StakedVision(stakedVisionAddress);

        vm.startBroadcast();

        stakedVision.rescueTokens{gas: 120_000}(token, amount, to);
        console.log("%s tokens of contract %s rescued and sent to %s", amount, token, to);

        vm.stopBroadcast();
    }

    function updateCooldownDuration(uint256 cooldownDuration, address stakedVisionAddress) external {
        stakedVision = StakedVision(stakedVisionAddress);

        vm.startBroadcast();

        stakedVision.updateCooldownDuration(cooldownDuration);
        console.log("Cooldown duration updated to %s seconds", cooldownDuration);

        vm.stopBroadcast();
    }

    function updateBpsYieldCapPerSecond(uint256 bpsYieldCapPerSecond, address stakedVisionAddress) external {
        stakedVision = StakedVision(stakedVisionAddress);

        vm.startBroadcast();

        stakedVision.updateBpsYieldCapPerSecond(bpsYieldCapPerSecond);
        console.log("BpsYieldCapPerSecond updated to %s", bpsYieldCapPerSecond);

        vm.stopBroadcast();
    }
}
