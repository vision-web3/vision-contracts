// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// solhint-disable gas-custom-errors

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VisionTokenMigrator} from "../src/VisionTokenMigrator.sol";
import {IStakedVision} from "../src/interfaces/IStakedVision.sol";
import {StakedVision} from "../src/StakedVision.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract MigrationAndStakingForkTest is Test {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant CRITICAL_OPS_ROLE = keccak256("CRITICAL_OPS_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    IERC20 public pan;
    IERC20 public best;
    IERC20 public vsn;
    VisionTokenMigrator public migrator;
    StakedVision public staked;
    address public whale;
    address public criticalOps;
    address public pauser;
    address public admin;

    modifier forkTestOnly() {
        if (!vm.envOr("RUN_FORK", false)) {
            vm.skip(true); // Skip if not a fork test
        }
        _;
    }

    function setUp() public forkTestOnly {
        pan = IERC20(vm.envAddress("PAN_ADDRESS"));
        best = IERC20(vm.envAddress("BEST_ADDRESS"));
        vsn = IERC20(vm.envAddress("VSN_ADDRESS"));
        migrator = VisionTokenMigrator(vm.envAddress("MIGRATOR_ADDRESS"));
        staked = StakedVision(vm.envAddress("STAKED_VISION_ADDRESS"));

        whale = vm.envAddress("PAN_BEST_WHALE");
        criticalOps = vm.envAddress("CRITICAL_OPS");
        pauser = vm.envAddress("PAUSER");
        admin = vm.envAddress("ADMIN");

        vm.label(address(pan), "PAN");
        vm.label(address(best), "BEST");
        vm.label(address(vsn), "VSN");
        vm.label(address(migrator), "Migrator");
        vm.label(address(staked), "StakedVision");
        vm.label(whale, "Whale");
    }
    // -------------------------
    // Test Utilities
    // -------------------------

    function startMigration(uint256 tokenAmount) public {
        vm.startPrank(criticalOps);
        vsn.approve(address(migrator), tokenAmount);
        migrator.startTokenMigration(tokenAmount);
        vm.stopPrank();
    }

    function migrateTokens() public {
        vm.startPrank(whale);
        uint256 panAmount = pan.balanceOf(whale);
        uint256 bestAmount = best.balanceOf(whale);
        require(panAmount + bestAmount > 0, "Whale has no PAN or BEST");

        pan.approve(address(migrator), panAmount);
        best.approve(address(migrator), bestAmount);

        migrator.migrateTokens();
        uint256 vsnBalance = vsn.balanceOf(whale);
        require(vsnBalance > 0, "No VSN received after migration");
        vm.stopPrank();
    }

    function createRewardsCycle(uint256 rewardsAmount, uint256 cycleDuration, uint256 bpsYieldCapPerSecond) public {
        vm.startPrank(criticalOps);
        // Transfer VSN rewards to staking contract first
        vsn.approve(address(staked), rewardsAmount);
        vsn.transfer(address(staked), rewardsAmount);

        // Set cycle end timestamp
        uint256 rewardsCycleEndTimestamp = block.timestamp + cycleDuration;
        staked.createRewardsCycle(rewardsAmount, rewardsCycleEndTimestamp, bpsYieldCapPerSecond);

        vm.stopPrank();
    }

    function stakeVSN(uint256 vsnAmount) public returns (uint256) {
        vm.startPrank(whale);
        vsn.approve(address(staked), vsnAmount);
        uint256 shares = staked.deposit(vsnAmount, whale);
        require(shares > 0, "No sVSN received");
        vm.stopPrank();
        return shares;
    }

    function startCooldown(address account, uint256 shares) public {
        vm.startPrank(account);
        uint256 lockedAssets = staked.cooldownShares(shares);
        require(lockedAssets > 0, "No assets locked");
        vm.stopPrank();
    }

    function wrapTimePastCooldown(address account) public {
        // Warp time past cooldown
        (uint104 cooldownEnd,) = staked.cooldowns(account);
        vm.warp(cooldownEnd + 1);
    }

    function claim(address receiver) public {
        vm.startPrank(receiver);

        // Claim VSN
        staked.claim(receiver);
        uint256 finalVSN = vsn.balanceOf(receiver);
        assertGt(finalVSN, 0, "Claim failed");

        vm.stopPrank();
    }

    // -------------------------
    // Test cases
    // -------------------------

    function testMigration() public forkTestOnly {
        startMigration(2_500_000_000e18);
        migrateTokens();
    }

    function testStaking() public forkTestOnly {
        startMigration(2_500_000_000e18);
        migrateTokens();

        uint256 vsnBalance = vsn.balanceOf(whale);
        stakeVSN(vsnBalance);
    }

    function testCooldownAndClaim() public forkTestOnly {
        startMigration(2_500_000_000e18);
        migrateTokens();
        uint256 vsnBalance = vsn.balanceOf(whale);
        uint256 shares = stakeVSN(vsnBalance);
        startCooldown(whale, shares);
        wrapTimePastCooldown(whale);
        claim(whale);
    }

    /// Test: Cannot migrate with no PAN/BEST
    function testCannotMigrateWithNoPanOrBest() public forkTestOnly {
        startMigration(2_500_000_000e18);

        address nobody = address(0xBEEF);
        vm.startPrank(nobody);
        vm.expectRevert(); // Should revert on ZeroTokensToMigrate()
        migrator.migrateTokens();
        vm.stopPrank();
    }

    /// Test: Cannot claim before cooldown ends
    function testCannotClaimBeforeCooldown() public forkTestOnly {
        startMigration(2_500_000_000e18);
        migrateTokens();
        uint256 vsnBalance = vsn.balanceOf(whale);
        uint256 shares = stakeVSN(vsnBalance);
        startCooldown(whale, shares);

        vm.startPrank(whale);
        vm.expectRevert();
        staked.claim(whale);
        vm.stopPrank();
    }

    /// Test: Non-holder can call claim, but no VSN is transferred
    function testNonHolderClaimTransfersNothing() public forkTestOnly {
        startMigration(2_500_000_000e18);
        migrateTokens();
        uint256 vsnBalance = vsn.balanceOf(whale);
        uint256 shares = stakeVSN(vsnBalance);
        startCooldown(whale, shares);
        wrapTimePastCooldown(whale);

        address withdrawWallet = address(0xD00D);
        address stranger = address(0xABCD);

        uint256 beforeStranger = vsn.balanceOf(stranger);
        uint256 beforeWithdraw = vsn.balanceOf(withdrawWallet);

        // Stranger calls claim (should not revert, but nothing happens)
        vm.startPrank(stranger);
        staked.claim(withdrawWallet);
        vm.stopPrank();

        uint256 afterStranger = vsn.balanceOf(stranger);
        uint256 afterWithdraw = vsn.balanceOf(withdrawWallet);

        assertEq(afterStranger, beforeStranger, "Stranger should not receive VSN");
        assertEq(afterWithdraw, beforeWithdraw, "Withdraw wallet should not receive VSN");
    }

    function testStakeDuringActiveRewardCycle() public forkTestOnly {
        startMigration(2_500_000_000e18);
        migrateTokens();

        // Parameters for the reward cycle
        uint256 rewardsAmount = 1_000e18;
        uint256 duration = 30 days;
        uint256 bpsYieldCapPerSecond = 6342;

        // Give the criticalOps enough VSN for reward
        // (May not be needed if criticalOps already has VSN)
        vm.startPrank(whale);
        vsn.transfer(criticalOps, rewardsAmount);
        vm.stopPrank();

        // Create reward cycle
        createRewardsCycle(rewardsAmount, duration, bpsYieldCapPerSecond);

        // Stake as whale during the active cycle
        uint256 vsnBalance = vsn.balanceOf(whale);
        uint256 shares = stakeVSN(vsnBalance);

        // Check staking contract totalAssets increased (optional)
        uint256 totalAssets = staked.totalAssets();
        assertGt(totalAssets, 0, "Staking contract should have assets");

        // Start cooldown and claim (optional)
        startCooldown(whale, shares);
        wrapTimePastCooldown(whale);
        claim(whale);
    }

    function testRolesAreCorrectlyGranted() public forkTestOnly {
        // Check pauser has PAUSER_ROLE
        assertTrue(staked.hasRole(PAUSER_ROLE, pauser), "pauser missing PAUSER_ROLE");
        // Check criticalOps has CRITICAL_OPS_ROLE
        assertTrue(staked.hasRole(CRITICAL_OPS_ROLE, criticalOps), "criticalOps missing CRITICAL_OPS_ROLE");
        // Check admin has DEFAULT_ADMIN_ROLE
        assertTrue(staked.hasRole(DEFAULT_ADMIN_ROLE, admin), "admin missing DEFAULT_ADMIN_ROLE");
    }

    function testCriticalOpsUpdates() public forkTestOnly {
        // --- updateCooldownDuration ---
        vm.startPrank(criticalOps);
        staked.updateCooldownDuration(1234);
        vm.stopPrank();
        assertEq(staked.cooldownDuration(), 1234, "cooldownDuration should be updated");

        // --- updateBpsYieldCapPerSecond ---
        vm.startPrank(criticalOps);
        staked.updateBpsYieldCapPerSecond(8888);
        vm.stopPrank();
        (,,,, uint256 bpsYieldCapPerSecond) = staked.rewardsCycle();
        assertEq(bpsYieldCapPerSecond, 8888, "bpsYieldCapPerSecond not updated");

        // --- updateMaximumRewardsCycleDuration ---
        vm.startPrank(criticalOps);
        staked.updateMaximumRewardsCycleDuration(4321);
        vm.stopPrank();
        assertEq(staked.maximumRewardsCycleDuration(), 4321, "maximumRewardsCycleDuration should be updated");
    }

    function testRoleProtectedCallsMigrator() public forkTestOnly {
        //--- Only CRITICAL_OPS can start migration ---
        vm.startPrank(criticalOps);
        vsn.approve(address(migrator), 1e18);
        migrator.startTokenMigration(1e18);
        vm.stopPrank();

        vm.startPrank(address(0x8));
        vsn.approve(address(migrator), 1e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(0x8), CRITICAL_OPS_ROLE
            )
        );
        migrator.startTokenMigration(1e18);
        vm.stopPrank();
    }

    function testRoleProtectedCallsStakedVision() public forkTestOnly {
        //--- Only PAUSER can pause/unpause ---
        vm.startPrank(pauser);
        staked.pause();
        staked.unpause();
        vm.stopPrank();
        vm.startPrank(address(0x1));
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(0x1), PAUSER_ROLE)
        );
        staked.pause();
        vm.stopPrank();

        //--- Only CRITICAL_OPS can createRewardsCycle ---
        vm.startPrank(criticalOps);
        vsn.approve(address(staked), 1e18);
        vsn.transfer(address(staked), 1e18);
        staked.createRewardsCycle(1e18, block.timestamp + 1000, 6342);
        vm.stopPrank();
        vm.startPrank(address(0x2));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(0x2), CRITICAL_OPS_ROLE
            )
        );
        staked.createRewardsCycle(1e18, block.timestamp + 1000, 6342);
        vm.stopPrank();

        //--- Only CRITICAL_OPS can update cooldown duration ---
        vm.startPrank(criticalOps);
        staked.updateCooldownDuration(123);
        vm.stopPrank();
        vm.startPrank(address(0x3));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(0x3), CRITICAL_OPS_ROLE
            )
        );
        staked.updateCooldownDuration(321);
        vm.stopPrank();

        //--- Only CRITICAL_OPS can update bpsYieldCapPerSecond ---
        vm.startPrank(criticalOps);
        staked.updateBpsYieldCapPerSecond(9999);
        vm.stopPrank();
        vm.startPrank(address(0x4));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(0x4), CRITICAL_OPS_ROLE
            )
        );
        staked.updateBpsYieldCapPerSecond(1);
        vm.stopPrank();

        //--- Only CRITICAL_OPS can update max reward cycle duration ---
        vm.startPrank(criticalOps);
        staked.updateMaximumRewardsCycleDuration(100000);
        vm.stopPrank();
        vm.startPrank(address(0x5));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(0x5), CRITICAL_OPS_ROLE
            )
        );
        staked.updateMaximumRewardsCycleDuration(200000);
        vm.stopPrank();

        //--- Only CRITICAL_OPS can withdraw surplus rewards ---
        vm.startPrank(criticalOps);
        // This may revert if no surplus, but should revert with a different message if not CRITICAL_OPS
        vm.expectRevert(IStakedVision.NoSurplusToWithdraw.selector);
        staked.withdrawSurplusRewards(admin);
        vm.stopPrank();
        vm.startPrank(address(0x6));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(0x6), CRITICAL_OPS_ROLE
            )
        );
        staked.withdrawSurplusRewards(admin);
        vm.stopPrank();

        //--- Only CRITICAL_OPS can rescue tokens ---
        address token = address(best); // Any ERC20
        vm.startPrank(criticalOps);
        // Will revert if called on the staking token, otherwise should succeed or revert for balance
        vm.expectRevert();
        staked.rescueTokens(token, 1e18, admin);
        vm.stopPrank();
        vm.startPrank(address(0x7));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(0x7), CRITICAL_OPS_ROLE
            )
        );
        staked.rescueTokens(token, 1e18, admin);
        vm.stopPrank();

        // --- Only admin can grant roles ---
        address newPauser = address(0xCAFE);

        // Non-admin should revert
        vm.startPrank(whale);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, whale, DEFAULT_ADMIN_ROLE)
        );
        staked.grantRole(PAUSER_ROLE, newPauser);
        vm.stopPrank();

        // Admin should succeed
        vm.startPrank(admin);
        staked.grantRole(PAUSER_ROLE, newPauser);
        assertTrue(staked.hasRole(PAUSER_ROLE, newPauser), "newPauser not granted PAUSER_ROLE by admin");
        vm.stopPrank();
    }
}
