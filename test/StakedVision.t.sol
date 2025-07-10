// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
// solhint-disable func-name-mixedcase
// solhint-disable one-contract-per-file

import {ERC20} from "@solmate/contracts/tokens/ERC20.sol";

import {Vm} from "forge-std/Test.sol";

import {VisionToken} from "../src/VisionToken.sol";
import {StakedVision} from "../src/StakedVision.sol";
import {IStakedVision} from "../src/interfaces/IStakedVision.sol";

import {MockERC20} from "./helpers/MockERC20.sol";
import {BaseTest} from "./BaseTest.t.sol";

struct UserBalance {
    address address_;
    uint256 balance;
}

contract VisionStakingTest is BaseTest {
    uint256 public constant DEFAULT_REWARDS_AMOUNT = 60e18;
    uint256 public constant DEFAULT_CYCLE_DURATION = 1 minutes;
    uint256 public constant DEFAULT_UNBONDING_PERIOD = 0;
    uint256 public constant DEFAULT_USER_STAKED_AMOUNT = 1_000_000e18;

    address public constant PAUSER_ROLE_ADDRESS = address(uint160(uint256(keccak256("Pauser"))));
    address public constant CRITICAL_OPS_ROLE_ADDRESS = address(uint160(uint256(keccak256("CriticalOps"))));
    address public constant DEFAULT_ADMIN_ADDRESS = address(uint160(uint256(keccak256("DefaultAdmin"))));

    uint256 public constant TOTAL_ASSETS_STORAGE_SLOT = 8;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public sponsor = address(0x4);

    StakedVision public stakedVision;
    VisionToken public visionToken;

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC                    
    //////////////////////////////////////////////////////////////*/

    function test_deposit_CheckAssetsSameBlockAsDeposit() external {
        _createRewardsCycleWithNoCap();
        vm.prank(minter);
        visionToken.mint(user1, DEFAULT_USER_STAKED_AMOUNT);
        uint256 expectedReceivedShares = DEFAULT_USER_STAKED_AMOUNT;
        vm.prank(user1);
        visionToken.approve(address(stakedVision), DEFAULT_USER_STAKED_AMOUNT);

        vm.prank(user1);
        stakedVision.deposit(DEFAULT_USER_STAKED_AMOUNT, user1);

        assertEq(stakedVision.balanceOf(user1), expectedReceivedShares);
        assertEq(stakedVision.previewRedeem(stakedVision.balanceOf(user1)), DEFAULT_USER_STAKED_AMOUNT);
    }

    function test_deposit_CheckAssetsLaterAfterDeposit() external {
        _createRewardsCycleWithNoCap();
        vm.prank(minter);
        visionToken.mint(user1, DEFAULT_USER_STAKED_AMOUNT);
        uint256 expectedReceivedShares = DEFAULT_USER_STAKED_AMOUNT;
        vm.prank(user1);
        visionToken.approve(address(stakedVision), DEFAULT_USER_STAKED_AMOUNT);

        vm.prank(user1);
        stakedVision.deposit(DEFAULT_USER_STAKED_AMOUNT, user1);
        skip(DEFAULT_CYCLE_DURATION / 2);

        assertEq(stakedVision.balanceOf(user1), expectedReceivedShares);
        assertEq(
            stakedVision.previewRedeem(stakedVision.balanceOf(user1)),
            DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT / 2
        );
    }

    function test_mint_CheckAssetsSameBlockAsDeposit() external {
        _createRewardsCycleWithNoCap();
        vm.prank(minter);
        visionToken.mint(user1, DEFAULT_USER_STAKED_AMOUNT);
        uint256 expectedReceivedShares = DEFAULT_USER_STAKED_AMOUNT;
        vm.prank(user1);
        visionToken.approve(address(stakedVision), DEFAULT_USER_STAKED_AMOUNT);

        vm.prank(user1);
        stakedVision.deposit(DEFAULT_USER_STAKED_AMOUNT, user1);

        assertEq(stakedVision.balanceOf(user1), expectedReceivedShares);
        assertEq(stakedVision.previewRedeem(stakedVision.balanceOf(user1)), DEFAULT_USER_STAKED_AMOUNT);
    }

    function test_mint_CheckAssetsLaterAfterDeposit() external {
        _createRewardsCycleWithNoCap();
        vm.prank(minter);
        visionToken.mint(user1, DEFAULT_USER_STAKED_AMOUNT);
        uint256 expectedReceivedShares = DEFAULT_USER_STAKED_AMOUNT;
        vm.prank(user1);
        visionToken.approve(address(stakedVision), DEFAULT_USER_STAKED_AMOUNT);

        vm.prank(user1);
        stakedVision.deposit(DEFAULT_USER_STAKED_AMOUNT, user1);
        skip(DEFAULT_CYCLE_DURATION / 2);

        assertEq(stakedVision.balanceOf(user1), expectedReceivedShares);
        assertEq(
            stakedVision.previewRedeem(stakedVision.balanceOf(user1)),
            DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT / 2
        );
    }

    function test_withdraw() external {
        _createRewardsCycleWithNoCap();
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        skip(DEFAULT_CYCLE_DURATION / 2);
        _mint_and_deposit(user2, DEFAULT_USER_STAKED_AMOUNT);
        uint256 expectedAssetsUser1 = stakedVision.previewRedeem(stakedVision.balanceOf(user1));
        uint256 expectedAssetsUser2 = stakedVision.previewRedeem(stakedVision.balanceOf(user2));

        vm.prank(user1);
        stakedVision.withdraw(expectedAssetsUser1, user1, user1);
        vm.prank(user2);
        stakedVision.withdraw(expectedAssetsUser2, user2, user2);

        assertEq(visionToken.balanceOf(user1), DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT / 2);
        assertApproxEqAbs(visionToken.balanceOf(user2), DEFAULT_USER_STAKED_AMOUNT, 10);
    }

    function test_redeem() external {
        _createRewardsCycleWithNoCap();
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        skip(DEFAULT_CYCLE_DURATION / 2);
        _mint_and_deposit(user2, DEFAULT_USER_STAKED_AMOUNT);
        uint256 redeemAmountUser1 = stakedVision.balanceOf(user1);
        uint256 redeemAmountUser2 = stakedVision.balanceOf(user2);

        vm.prank(user1);
        stakedVision.redeem(redeemAmountUser1, user1, user1);
        vm.prank(user2);
        stakedVision.redeem(redeemAmountUser2, user2, user2);

        assertEq(visionToken.balanceOf(user1), DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT / 2);
        assertApproxEqAbs(visionToken.balanceOf(user2), DEFAULT_USER_STAKED_AMOUNT, 10);
    }

    function test_cooldownAssets() external {
        _createRewardsCycleWithNoCap();
        uint256 cooldownDuration = 10 seconds;
        _updateCooldownPeriod(cooldownDuration);
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        skip(DEFAULT_CYCLE_DURATION / 2);
        _mint_and_deposit(user2, DEFAULT_USER_STAKED_AMOUNT);
        uint256 expectedAssetsUser1 = stakedVision.previewRedeem(stakedVision.balanceOf(user1));
        uint256 expectedAssetsUser2 = stakedVision.previewRedeem(stakedVision.balanceOf(user2));

        vm.prank(user1);
        stakedVision.cooldownAssets(expectedAssetsUser1);
        vm.prank(user2);
        stakedVision.cooldownAssets(expectedAssetsUser2);

        (uint104 cooldownEndUser1, uint152 lockedAmountUser1) = stakedVision.cooldowns(user1);
        (uint104 cooldownEndUser2, uint152 lockedAmountUser2) = stakedVision.cooldowns(user2);
        assertEq(stakedVision.totalSupply(), 0);
        assertEq(visionToken.balanceOf(user1), 0);
        assertEq(visionToken.balanceOf(user2), 0);
        assertEq(lockedAmountUser1, DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT / 2);
        assertApproxEqAbs(lockedAmountUser2, DEFAULT_USER_STAKED_AMOUNT, 10);
        assertEq(cooldownEndUser1, block.timestamp + cooldownDuration);
        assertEq(cooldownEndUser2, block.timestamp + cooldownDuration);
    }

    function test_cooldownShares() external {
        _createRewardsCycleWithNoCap();
        uint256 cooldownDuration = 10 seconds;
        _updateCooldownPeriod(cooldownDuration);
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        skip(DEFAULT_CYCLE_DURATION / 2);
        _mint_and_deposit(user2, DEFAULT_USER_STAKED_AMOUNT);
        uint256 redeemAmountUser1 = stakedVision.balanceOf(user1);
        uint256 redeemAmountUser2 = stakedVision.balanceOf(user2);

        vm.prank(user1);
        stakedVision.cooldownShares(redeemAmountUser1);
        vm.prank(user2);
        stakedVision.cooldownShares(redeemAmountUser2);

        (uint104 cooldownEndUser1, uint152 lockedAmountUser1) = stakedVision.cooldowns(user1);
        (uint104 cooldownEndUser2, uint152 lockedAmountUser2) = stakedVision.cooldowns(user2);
        assertEq(stakedVision.totalSupply(), 0);
        assertEq(visionToken.balanceOf(user1), 0);
        assertEq(visionToken.balanceOf(user2), 0);
        assertEq(lockedAmountUser1, DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT / 2);
        assertApproxEqAbs(lockedAmountUser2, DEFAULT_USER_STAKED_AMOUNT, 10);
        assertEq(cooldownEndUser1, block.timestamp + cooldownDuration);
        assertEq(cooldownEndUser2, block.timestamp + cooldownDuration);
    }

    function test_claim() external {
        _createRewardsCycleWithNoCap();
        uint256 cooldownDuration = 10 seconds;
        _updateCooldownPeriod(cooldownDuration);
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        skip(DEFAULT_CYCLE_DURATION / 2);
        _mint_and_deposit(user2, DEFAULT_USER_STAKED_AMOUNT);
        uint256 redeemAmountUser1 = stakedVision.balanceOf(user1);
        uint256 redeemAmountUser2 = stakedVision.balanceOf(user2);
        vm.prank(user1);
        stakedVision.cooldownShares(redeemAmountUser1);
        vm.prank(user2);
        stakedVision.cooldownShares(redeemAmountUser2);
        skip(cooldownDuration);

        vm.prank(user1);
        stakedVision.claim(user1);
        vm.prank(user2);
        stakedVision.claim(user2);

        (uint104 cooldownEndUser1, uint152 lockedAmountUser1) = stakedVision.cooldowns(user1);
        (uint104 cooldownEndUser2, uint152 lockedAmountUser2) = stakedVision.cooldowns(user2);
        assertEq(visionToken.balanceOf(user1), DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT / 2);
        assertApproxEqAbs(visionToken.balanceOf(user2), DEFAULT_USER_STAKED_AMOUNT, 10);
        assertEq(lockedAmountUser1, 0);
        assertEq(lockedAmountUser2, 0);
        assertEq(cooldownEndUser1, 0);
        assertEq(cooldownEndUser2, 0);
    }

    /*//////////////////////////////////////////////////////////////
                             REWARDS LOGIC                           
    //////////////////////////////////////////////////////////////*/

    function test_distributeRewards_AllRewards() external {
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycleWithNoCap();
        skip(DEFAULT_CYCLE_DURATION);
        vm.expectEmit();
        emit IStakedVision.DistributeRewards(DEFAULT_REWARDS_AMOUNT);

        stakedVision.distributeRewards();

        (uint256 unvestedAmount,, uint256 lastDistributionTimestamp, uint256 surplus,) = stakedVision.rewardsCycle();

        uint256 totalAssetsStored = _getStoredAssets();
        assertEq(totalAssetsStored, DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT);
        assertEq(unvestedAmount, 0);
        assertEq(lastDistributionTimestamp, block.timestamp);
        assertEq(surplus, 0);
    }

    function test_distributeRewards_PartOfTheRewards() external {
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycleWithNoCap();
        skip(DEFAULT_CYCLE_DURATION / 2);
        vm.expectEmit();
        emit IStakedVision.DistributeRewards(DEFAULT_REWARDS_AMOUNT / 2);

        stakedVision.distributeRewards();

        (uint256 unvestedAmount,, uint256 lastDistributionTimestamp, uint256 surplus,) = stakedVision.rewardsCycle();
        uint256 totalAssetsStored = _getStoredAssets();
        assertEq(totalAssetsStored, DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT / 2);
        assertEq(unvestedAmount, DEFAULT_REWARDS_AMOUNT / 2);
        assertEq(lastDistributionTimestamp, block.timestamp);
        assertEq(surplus, 0);
    }

    function test_distributeRewards_AlreadyDistributed() external {
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        uint256 currentBlockTimestamp = block.timestamp;
        _createRewardsCycleWithNoCap();
        skip(DEFAULT_CYCLE_DURATION);
        stakedVision.distributeRewards();
        skip(DEFAULT_CYCLE_DURATION);
        vm.recordLogs();

        stakedVision.distributeRewards();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint256 totalAssetsStored = _getStoredAssets();
        (uint256 unvestedAmount,, uint256 lastDistributionTimestamp, uint256 surplus,) = stakedVision.rewardsCycle();
        assertEq(entries.length, 0);
        assertEq(totalAssetsStored, DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT);
        assertEq(unvestedAmount, 0);
        assertNotEq(lastDistributionTimestamp, block.timestamp);
        assertEq(lastDistributionTimestamp, currentBlockTimestamp + DEFAULT_CYCLE_DURATION);
        assertEq(surplus, 0);
    }

    function test_distributeRewards_WithSurplus() external {
        uint256 cycleDuration = 24 hours * 365; // 1 year
        uint256 rewardsAmount = 1_000_000e18;
        uint256 expectedRewardsPerYear = (5 * rewardsAmount) / 100; // 5% of rewards

        uint256 bpsYieldCapPerSecond = 1585; // ~5% per year
        _updateMaximumRewardsCycleDuration(53 weeks);
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycle(rewardsAmount, cycleDuration, bpsYieldCapPerSecond);
        skip(cycleDuration);
        vm.expectEmit(false, false, false, false);
        /// @dev The distributed amount is not exactly 5% due to precision loss. Therefore,
        /// we don't check the event exact amount (here is should be around 50ke18)
        emit IStakedVision.DistributeRewards(0);

        stakedVision.distributeRewards();

        uint256 totalAssetsStored = _getStoredAssets();
        (uint256 unvestedAmount,, uint256 lastDistributionTimestamp, uint256 surplus,) = stakedVision.rewardsCycle();
        assertApproxEqAbs(totalAssetsStored, DEFAULT_USER_STAKED_AMOUNT + expectedRewardsPerYear, 20e18);
        assertEq(unvestedAmount, 0);
        assertEq(lastDistributionTimestamp, block.timestamp);
        assertApproxEqAbs(surplus, rewardsAmount - expectedRewardsPerYear, 20e18);
    }

    function test_previewDistributeRewards_CycleNeverCreated() external {
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        skip(1);

        (uint256 rewards, uint256 surplusRewards, uint256 uncappedRewards) = stakedVision.previewDistributeRewards();

        assertEq(rewards, 0);
        assertEq(surplusRewards, 0);
        assertEq(uncappedRewards, 0);
    }

    function test_previewDistributeRewards_CycleAlreadyVested() external {
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycleWithNoCap();
        skip(DEFAULT_CYCLE_DURATION);
        stakedVision.distributeRewards();
        skip(DEFAULT_CYCLE_DURATION);

        (uint256 rewards, uint256 surplusRewards, uint256 uncappedRewards) = stakedVision.previewDistributeRewards();

        assertEq(rewards, 0);
        assertEq(surplusRewards, 0);
        assertEq(uncappedRewards, 0);
    }

    function test_previewDistributeRewards_RewardsAlreadyDistributedInTheSameBlock() external {
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycleWithNoCap();
        skip(DEFAULT_CYCLE_DURATION / 2);
        stakedVision.distributeRewards();

        (uint256 rewards, uint256 surplusRewards, uint256 uncappedRewards) = stakedVision.previewDistributeRewards();

        assertEq(rewards, 0);
        assertEq(surplusRewards, 0);
        assertEq(uncappedRewards, 0);
    }

    function test_previewDistributeRewards_NoCap_DuringCycle() external {
        uint256 elapsedTime = 31 seconds;
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycleWithNoCap();
        skip(elapsedTime);

        (uint256 rewards, uint256 surplusRewards, uint256 uncappedRewards) = stakedVision.previewDistributeRewards();

        assertEq(rewards, DEFAULT_REWARDS_AMOUNT * elapsedTime / DEFAULT_CYCLE_DURATION);
        assertEq(surplusRewards, 0);
        assertEq(uncappedRewards, DEFAULT_REWARDS_AMOUNT * elapsedTime / DEFAULT_CYCLE_DURATION);
    }

    function test_previewDistributeRewards_NoCap_AfterCycle() external {
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycleWithNoCap();
        skip(DEFAULT_CYCLE_DURATION * 2);

        (uint256 rewards, uint256 surplusRewards, uint256 uncappedRewards) = stakedVision.previewDistributeRewards();

        assertEq(rewards, DEFAULT_REWARDS_AMOUNT);
        assertEq(surplusRewards, 0);
        assertEq(uncappedRewards, DEFAULT_REWARDS_AMOUNT);
    }

    function test_previewDistributeRewards_WithCap_OneYear() external {
        uint256 cycleDuration = 24 hours * 365; // 1 year
        uint256 rewardsAmount = 1_000_000e18;
        uint256 expectedRewardsPerYear = (5 * rewardsAmount) / 100; // 5% of rewards

        uint256 bpsYieldCapPerSecond = 1585; // ~5% per year
        _updateMaximumRewardsCycleDuration(53 weeks);
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycle(rewardsAmount, cycleDuration, bpsYieldCapPerSecond);
        skip(cycleDuration);

        (uint256 rewards, uint256 surplusRewards, uint256 uncappedRewards) = stakedVision.previewDistributeRewards();

        assertApproxEqAbs(rewards, expectedRewardsPerYear, 20e18);
        assertApproxEqAbs(surplusRewards, rewardsAmount - expectedRewardsPerYear, 20e18);
        assertEq(uncappedRewards, rewardsAmount);
    }

    function test_previewDistributeRewards_WithCap_OneSecond() external {
        uint256 cycleDuration = 24 hours * 365; // 1 year
        uint256 rewardsAmount = 1_000_000e18;
        uint256 expectedRewardsPerYear = (5 * rewardsAmount) / 100; // 5% of rewards

        uint256 bpsYieldCapPerSecond = 1585; // ~5% per year
        _updateMaximumRewardsCycleDuration(53 weeks);
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycle(rewardsAmount, cycleDuration, bpsYieldCapPerSecond);
        skip(1);

        (uint256 rewards, uint256 surplusRewards, uint256 uncappedRewards) = stakedVision.previewDistributeRewards();

        assertApproxEqAbs(rewards, expectedRewardsPerYear / cycleDuration, 1e12);
        assertApproxEqAbs(surplusRewards, rewardsAmount / cycleDuration - expectedRewardsPerYear / cycleDuration, 1e12);
        assertEq(uncappedRewards, rewardsAmount / cycleDuration);
    }

    function test_totalAssets_RewardsDistributed() external {
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycleWithNoCap();
        skip(DEFAULT_CYCLE_DURATION);
        stakedVision.distributeRewards();

        uint256 totalAssets = stakedVision.totalAssets();

        assertEq(totalAssets, DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT);
    }

    function test_totalAssets_RewardsNotYetDistributed() external {
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycleWithNoCap();
        skip(DEFAULT_CYCLE_DURATION);

        uint256 totalAssets = stakedVision.totalAssets();

        assertEq(totalAssets, DEFAULT_USER_STAKED_AMOUNT + DEFAULT_REWARDS_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            RBAC OPERATIONS                          
    //////////////////////////////////////////////////////////////*/

    function test_createRewardsCycle() external {
        vm.prank(minter);
        visionToken.mint(sponsor, DEFAULT_REWARDS_AMOUNT);
        vm.prank(sponsor);
        visionToken.transfer(address(stakedVision), DEFAULT_REWARDS_AMOUNT);
        uint256 bpsYieldCapPerSecondInit = 0;
        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        vm.expectEmit();
        emit IStakedVision.RewardsCycleCreated(
            DEFAULT_REWARDS_AMOUNT, block.timestamp + DEFAULT_CYCLE_DURATION, bpsYieldCapPerSecondInit
        );
        stakedVision.createRewardsCycle(
            DEFAULT_REWARDS_AMOUNT, block.timestamp + DEFAULT_CYCLE_DURATION, bpsYieldCapPerSecondInit
        );

        (
            uint256 unvestedAmount,
            uint256 endTimestamp,
            uint256 lastDistributionTimestamp,
            uint256 surplus,
            uint256 bpsYieldCapPerSecond
        ) = stakedVision.rewardsCycle();
        assertEq(unvestedAmount, DEFAULT_REWARDS_AMOUNT);
        assertEq(endTimestamp, block.timestamp + DEFAULT_CYCLE_DURATION);
        assertEq(lastDistributionTimestamp, block.timestamp);
        assertEq(surplus, 0);
        assertEq(bpsYieldCapPerSecond, bpsYieldCapPerSecondInit);
    }

    function test_createRewardsCycle_AfterElapsedCycle() external {
        _createRewardsCycleWithNoCap();
        skip(DEFAULT_CYCLE_DURATION);
        vm.prank(minter);
        visionToken.mint(sponsor, DEFAULT_REWARDS_AMOUNT);
        vm.prank(sponsor);
        visionToken.transfer(address(stakedVision), DEFAULT_REWARDS_AMOUNT);
        uint256 bpsYieldCapPerSecondInit = 0;
        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        vm.expectEmit();
        emit IStakedVision.RewardsCycleCreated(
            DEFAULT_REWARDS_AMOUNT, block.timestamp + DEFAULT_CYCLE_DURATION, bpsYieldCapPerSecondInit
        );

        stakedVision.createRewardsCycle(
            DEFAULT_REWARDS_AMOUNT, block.timestamp + DEFAULT_CYCLE_DURATION, bpsYieldCapPerSecondInit
        );

        (
            uint256 unvestedAmount,
            uint256 endTimestamp,
            uint256 lastDistributionTimestamp,
            uint256 surplus,
            uint256 bpsYieldCapPerSecond
        ) = stakedVision.rewardsCycle();
        assertEq(unvestedAmount, DEFAULT_REWARDS_AMOUNT);
        assertEq(endTimestamp, block.timestamp + DEFAULT_CYCLE_DURATION);
        assertEq(lastDistributionTimestamp, block.timestamp);
        assertEq(surplus, 0);
        assertEq(bpsYieldCapPerSecond, bpsYieldCapPerSecondInit);
    }

    function test_createRewardsCycle_CycleEndTimestampInThePast() external {
        skip(10);
        vm.prank(minter);
        visionToken.mint(sponsor, DEFAULT_REWARDS_AMOUNT);
        vm.prank(sponsor);
        visionToken.transfer(address(stakedVision), DEFAULT_REWARDS_AMOUNT);
        vm.expectRevert(IStakedVision.CycleEndTimestampInThePast.selector);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.createRewardsCycle(DEFAULT_REWARDS_AMOUNT, block.timestamp - 1, 0);
    }

    function test_createRewardsCycle_PreviousCycleNotFinished() external {
        _createRewardsCycleWithNoCap();
        vm.prank(minter);
        visionToken.mint(sponsor, DEFAULT_REWARDS_AMOUNT);
        vm.prank(sponsor);
        visionToken.transfer(address(stakedVision), DEFAULT_REWARDS_AMOUNT);
        vm.expectRevert(IStakedVision.PreviousCycleNotFinished.selector);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.createRewardsCycle(DEFAULT_REWARDS_AMOUNT, block.timestamp + DEFAULT_CYCLE_DURATION, 0);
    }

    function test_createRewardsCycle_MaximumRewardsCycleDurationExceeded() external {
        uint256 cycleDuration = 61 days;
        uint256 bpsYieldCapPerSecond = 1585; // ~5% per year
        vm.prank(minter);
        visionToken.mint(sponsor, DEFAULT_REWARDS_AMOUNT);
        vm.prank(sponsor);
        visionToken.transfer(address(stakedVision), DEFAULT_REWARDS_AMOUNT);
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        vm.expectRevert(IStakedVision.RewardsCycleDurationTooLong.selector);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.createRewardsCycle(DEFAULT_REWARDS_AMOUNT, cycleDuration, bpsYieldCapPerSecond);
    }

    function test_createRewardsCycle_SurplusNotWithdrawn() external {
        uint256 cycleDuration = 24 hours * 365; // 1 year
        uint256 rewardsAmount = 1_000_000e18;
        uint256 bpsYieldCapPerSecond = 1585; // ~5% per year
        _updateMaximumRewardsCycleDuration(53 weeks);
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycle(rewardsAmount, cycleDuration, bpsYieldCapPerSecond);
        skip(cycleDuration);
        stakedVision.distributeRewards();
        (,,, uint256 initialSurplus,) = stakedVision.rewardsCycle();
        vm.prank(minter);
        visionToken.mint(sponsor, DEFAULT_REWARDS_AMOUNT);
        vm.prank(sponsor);
        visionToken.transfer(address(stakedVision), DEFAULT_REWARDS_AMOUNT);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.createRewardsCycle(DEFAULT_REWARDS_AMOUNT, block.timestamp + DEFAULT_CYCLE_DURATION, 0);

        (
            uint256 unvestedAmount,
            uint256 endTimestamp,
            uint256 lastDistributionTimestamp,
            uint256 surplus,
            uint256 bpsYieldCapPerSecond_
        ) = stakedVision.rewardsCycle();
        assertEq(unvestedAmount, DEFAULT_REWARDS_AMOUNT);
        assertEq(endTimestamp, block.timestamp + DEFAULT_CYCLE_DURATION);
        assertEq(lastDistributionTimestamp, block.timestamp);
        assertEq(surplus, initialSurplus);
        assertEq(bpsYieldCapPerSecond_, 0);
    }

    function test_createRewardsCycle_SurplusNotWithdrawn_NotEnoughFunds() external {
        uint256 cycleDuration = 24 hours * 365; // 1 year
        uint256 rewardsAmount = 1_000_000e18;
        uint256 bpsYieldCapPerSecond = 1585; // ~5% per year
        _updateMaximumRewardsCycleDuration(53 weeks);
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycle(rewardsAmount, cycleDuration, bpsYieldCapPerSecond);
        skip(cycleDuration);
        vm.prank(minter);
        visionToken.mint(sponsor, DEFAULT_REWARDS_AMOUNT);
        vm.prank(sponsor);
        visionToken.transfer(address(stakedVision), DEFAULT_REWARDS_AMOUNT);
        vm.expectRevert(IStakedVision.NotEnoughRewardFunds.selector);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.createRewardsCycle(DEFAULT_REWARDS_AMOUNT + 1, block.timestamp + DEFAULT_CYCLE_DURATION, 0);
    }

    function test_createRewardsCycle_NotEnoughRewardFunds() external {
        vm.prank(minter);
        visionToken.mint(sponsor, DEFAULT_REWARDS_AMOUNT);
        vm.prank(sponsor);
        visionToken.transfer(address(stakedVision), DEFAULT_REWARDS_AMOUNT - 1);
        vm.expectRevert(IStakedVision.NotEnoughRewardFunds.selector);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.createRewardsCycle(DEFAULT_REWARDS_AMOUNT, block.timestamp + DEFAULT_CYCLE_DURATION, 0);
    }

    function test_withdrawSurplusRewards() external {
        uint256 cycleDuration = 24 hours * 365; // 1 year
        uint256 rewardsAmount = 1_000_000e18;
        uint256 bpsYieldCapPerSecond = 1585; // ~5% per year
        uint256 expectedRewardsPerYear = (5 * rewardsAmount) / 100; // 5% of rewards
        _updateMaximumRewardsCycleDuration(53 weeks);
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycle(rewardsAmount, cycleDuration, bpsYieldCapPerSecond);
        skip(cycleDuration);
        stakedVision.distributeRewards();
        vm.expectEmit(true, false, false, false);
        emit IStakedVision.WithdrawSurplus(CRITICAL_OPS_ROLE_ADDRESS, 0);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.withdrawSurplusRewards(CRITICAL_OPS_ROLE_ADDRESS);

        (,,, uint256 surplus,) = stakedVision.rewardsCycle();
        assertApproxEqAbs(
            visionToken.balanceOf(CRITICAL_OPS_ROLE_ADDRESS), rewardsAmount - expectedRewardsPerYear, 20e18
        );
        assertEq(surplus, 0);
    }

    function test_withdrawSurplusRewards_NoSurplus() external {
        _mint_and_deposit(user1, DEFAULT_USER_STAKED_AMOUNT);
        _createRewardsCycleWithNoCap();
        skip(DEFAULT_CYCLE_DURATION * 2);
        stakedVision.distributeRewards();
        vm.expectRevert(IStakedVision.NoSurplusToWithdraw.selector);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.withdrawSurplusRewards(CRITICAL_OPS_ROLE_ADDRESS);
    }

    function test_rescueTokens() external {
        MockERC20 token = new MockERC20(18);
        token.mint(address(stakedVision), 1e18);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.rescueTokens(address(token), 1e18, CRITICAL_OPS_ROLE_ADDRESS);

        assertEq(token.balanceOf(CRITICAL_OPS_ROLE_ADDRESS), 1e18);
    }

    function test_updateCooldownDuration() external {
        uint256 cooldownDuration = 10 seconds;
        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        vm.expectEmit();
        emit IStakedVision.CooldownDurationUpdated(0, cooldownDuration);
        stakedVision.updateCooldownDuration(cooldownDuration);

        assertEq(stakedVision.cooldownDuration(), cooldownDuration);
    }

    function test_updateCooldownDuration_error_same_value() external {
        uint256 cooldownDuration = 10 seconds;
        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        vm.expectEmit();
        emit IStakedVision.CooldownDurationUpdated(0, cooldownDuration);
        stakedVision.updateCooldownDuration(cooldownDuration);

        assertEq(stakedVision.cooldownDuration(), cooldownDuration);

        vm.expectRevert(IStakedVision.SameCooldownDuration.selector);
        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.updateCooldownDuration(cooldownDuration);
    }

    function test_updateBpsYieldCapPerSecond() external {
        uint256 bpsYieldCapPerSecond = 1585; // ~5% per year
        _createRewardsCycle(bpsYieldCapPerSecond);
        vm.expectEmit();
        emit IStakedVision.BpsYieldCapPerSecondUpdated(bpsYieldCapPerSecond, bpsYieldCapPerSecond + 10);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.updateBpsYieldCapPerSecond(bpsYieldCapPerSecond + 10);

        (,,,, uint256 updatedBpsYieldCapPerSecond) = stakedVision.rewardsCycle();
        assertEq(updatedBpsYieldCapPerSecond, bpsYieldCapPerSecond + 10);
    }

    function test_updateBpsYieldCapPerSecond_SameBpsYieldCapPerSecond() external {
        uint256 bpsYieldCapPerSecond = 1585; // ~5% per year
        _createRewardsCycle(bpsYieldCapPerSecond);
        vm.expectRevert(IStakedVision.SameBpsYieldCapPerSecond.selector);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.updateBpsYieldCapPerSecond(bpsYieldCapPerSecond);
    }

    function test_updateMaximumRewardsCycleDuration() external {
        uint256 maximumRewardsCycleDuration = 53 weeks;
        vm.expectEmit();
        emit IStakedVision.MaximumRewardsCycleDurationUpdated(60 days, maximumRewardsCycleDuration);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.updateMaximumRewardsCycleDuration(maximumRewardsCycleDuration);

        assertEq(stakedVision.maximumRewardsCycleDuration(), maximumRewardsCycleDuration);
    }

    function test_updateMaximumRewardsCycleDuration_SameValue() external {
        uint256 maximumRewardsCycleDuration = 60 days;
        vm.expectRevert(IStakedVision.SameMaximumRewardsCycleDuration.selector);

        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.updateMaximumRewardsCycleDuration(maximumRewardsCycleDuration);
    }

    function test_pause() external {
        vm.prank(PAUSER_ROLE_ADDRESS);
        stakedVision.pause();

        assertTrue(stakedVision.paused());
    }

    function test_pause_unauthorized_role() external {
        vm.expectRevert();

        vm.prank(user1);
        stakedVision.pause();
    }

    function test_pause_fail_when_already_paused() external {
        vm.prank(PAUSER_ROLE_ADDRESS);
        stakedVision.pause();

        vm.expectRevert();
        vm.prank(PAUSER_ROLE_ADDRESS);
        stakedVision.pause();
    }

    function test_unpause() external {
        vm.prank(PAUSER_ROLE_ADDRESS);
        stakedVision.pause();

        assertTrue(stakedVision.paused());

        vm.prank(PAUSER_ROLE_ADDRESS);
        stakedVision.unpause();
        assertFalse(stakedVision.paused());
    }

    function test_unpause_unauthorized_role() external {
        vm.prank(PAUSER_ROLE_ADDRESS);
        stakedVision.pause();

        vm.expectRevert();
        vm.prank(user1);
        stakedVision.pause();
    }

    function test_unpause_fail_when_already_paused() external {
        vm.expectRevert();
        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            SETUP & HELPERS                                                
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        deployVisionToken();
        visionToken = token;
        stakedVision = new StakedVision(
            ERC20(address(visionToken)),
            DEFAULT_UNBONDING_PERIOD,
            PAUSER_ROLE_ADDRESS,
            CRITICAL_OPS_ROLE_ADDRESS,
            DEFAULT_ADMIN_ADDRESS
        );
    }

    function _getStoredAssets() internal view returns (uint256) {
        return uint256(vm.load(address(stakedVision), bytes32(uint256(TOTAL_ASSETS_STORAGE_SLOT))));
    }

    function _createRewardsCycle(uint256 rewardsAmount, uint256 cycleDuration, uint256 bpsYieldCapPerSecond)
        internal
    {
        vm.prank(minter);
        visionToken.mint(sponsor, rewardsAmount);
        vm.prank(sponsor);
        visionToken.transfer(address(stakedVision), rewardsAmount);
        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.createRewardsCycle(rewardsAmount, block.timestamp + cycleDuration, bpsYieldCapPerSecond);
    }

    function _createRewardsCycle(uint256 bpsYieldCapPerSecond) internal {
        _createRewardsCycle(DEFAULT_REWARDS_AMOUNT, DEFAULT_CYCLE_DURATION, bpsYieldCapPerSecond);
    }

    function _createRewardsCycle(uint256 rewardsAmount, uint256 bpsYieldCapPerSecond) internal {
        _createRewardsCycle(rewardsAmount, DEFAULT_CYCLE_DURATION, bpsYieldCapPerSecond);
    }

    function _createRewardsCycleWithNoCap(uint256 rewardsAmount) internal {
        _createRewardsCycle(rewardsAmount, 0);
    }

    function _createRewardsCycleWithNoCap() internal {
        _createRewardsCycle(DEFAULT_REWARDS_AMOUNT, 0);
    }

    function _updateCooldownPeriod(uint256 cooldownDuration) internal {
        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.updateCooldownDuration(cooldownDuration);
    }

    function _updateMaximumRewardsCycleDuration(uint256 maximumRewardsCycleDuration) internal {
        vm.prank(CRITICAL_OPS_ROLE_ADDRESS);
        stakedVision.updateMaximumRewardsCycleDuration(maximumRewardsCycleDuration);
    }

    function _mint_and_deposit(address user, uint256 amount) internal {
        vm.prank(minter);
        visionToken.mint(user, amount);
        vm.startPrank(user);
        visionToken.approve(address(stakedVision), amount);
        stakedVision.deposit(amount, user);
        vm.stopPrank();
    }
}
