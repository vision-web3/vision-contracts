// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;
// solhint-disable func-name-mixedcase
// solhint-disable no-console

import {stdError} from "forge-std/Test.sol";

import {VisionToken} from "../src/VisionToken.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {BaseTest} from "./BaseTest.t.sol";

contract VisionTokenTest is BaseTest {
    function setUp() public virtual {
        deployVisionToken();
    }

    function test_pause() public {
        assertFalse(token.paused());
        vm.expectEmit(address(token));
        emit PausableUpgradeable.Paused(pauser);
        vm.prank(pauser);
        token.pause();
        assertTrue(token.paused());
    }

    function test_pause_WhenPausedReverts() public {
        assertFalse(token.paused());
        vm.startPrank(pauser);
        token.pause();
        assertTrue(token.paused());

        // try pausing already paused
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.pause();
        vm.stopPrank();

        assertTrue(token.paused());
    }

    function test_pause_WhenPausedMultipleAttemptReverts() public {
        vm.startPrank(pauser);

        // Initial state
        assertFalse(token.paused());

        // First pause
        token.pause();
        assertTrue(token.paused());

        // Attempt to pause again
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.pause();

        vm.stopPrank();
        assertTrue(token.paused());
    }

    function test_pause_ByNonPauserRoleReverts() public {
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, bob, token.PAUSER_ROLE())
        );
        token.pause();
        vm.stopPrank();
        assertFalse(token.paused());
    }

    function test_pause_ByOtherRolesReverts() public {
        address[3] memory otherRoles = [roleAdmin, minter, upgrader];

        for (uint256 i; i < otherRoles.length; i++) {
            address otherRole = otherRoles[i];
            vm.startPrank(otherRole);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector, otherRole, token.PAUSER_ROLE()
                )
            );
            token.pause();

            assertFalse(token.paused());
            vm.stopPrank();
        }
    }

    function test_unpause() public {
        vm.startPrank(pauser);
        token.pause();
        assertTrue(token.paused());

        vm.expectEmit(address(token));
        emit PausableUpgradeable.Unpaused(pauser);
        token.unpause();
        vm.stopPrank();

        assertFalse(token.paused());
    }

    function test_unpause_WhenPausedReverts() public {
        vm.startPrank(pauser);
        // try unpausing when already unpaused
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        token.unpause();
        vm.stopPrank();

        assertFalse(token.paused());
    }

    function test_unpause_WhenPausedMultipleAttemptReverts() public {
        vm.startPrank(pauser);
        // try unpausing when already unpaused
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        token.unpause();

        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        token.unpause();

        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        token.unpause();

        vm.stopPrank();

        assertFalse(token.paused());
    }

    function test_unpause_ByNonPauserRoleReverts() public {
        vm.prank(pauser);
        token.pause();

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, bob, token.PAUSER_ROLE())
        );
        token.unpause();
        vm.stopPrank();
        assertTrue(token.paused());
    }

    function test_unpause_ByOtherRolesReverts() public {
        address[3] memory otherRoles = [roleAdmin, minter, upgrader];
        vm.prank(pauser);
        token.pause();

        for (uint256 i; i < otherRoles.length; i++) {
            address otherRole = otherRoles[i];
            vm.startPrank(otherRole);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector, otherRole, token.PAUSER_ROLE()
                )
            );
            token.unpause();

            assertTrue(token.paused());
            vm.stopPrank();
        }
    }

    function test_mint() public {
        uint256 amount = 1000 * TOKEN_UNIT;
        setUser(bob, amount);
        setUser(charlie, amount);
        uint256 initialSupply = token.totalSupply();

        vm.startPrank(minter);
        vm.expectEmit(address(token));
        emit VisionToken.Mint(minter, alice, amount);
        token.mint(alice, amount);
        vm.stopPrank();
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(charlie), amount);
        assertEq(token.totalSupply(), initialSupply + amount);
    }

    function test_mint_OverflowReverts() public {
        uint256 maxUint = type(uint256).max;
        vm.startPrank(minter);
        token.mint(alice, 1 * TOKEN_UNIT);

        // more minting should overflow
        vm.expectRevert(stdError.arithmeticError);
        token.mint(alice, maxUint);
        vm.stopPrank();

        // Validate alice's balance remains unchanged
        assertEq(token.totalSupply(), 1 * TOKEN_UNIT + INITIAL_SUPPLY_VSN, "Total supply should remain unchanged");
        assertEq(token.balanceOf(alice), 1 * TOKEN_UNIT, "alice's balance should not change");
    }

    function test_mint_TotalSupplyOverflowReverts() public {
        uint256 maxUint = type(uint256).max;
        vm.startPrank(minter);
        token.mint(alice, maxUint - INITIAL_SUPPLY_VSN);

        // more minting should overflow
        vm.expectRevert(stdError.arithmeticError);
        token.mint(alice, 1);
        vm.stopPrank();

        // Validate alice's balance remains unchanged
        assertEq(token.totalSupply(), maxUint, "Total supply should remain unchanged");
        assertEq(token.balanceOf(alice), maxUint - INITIAL_SUPPLY_VSN, "alice's balance should not change");
    }

    function test_mint_ToZeroAddressReverts() public {
        uint256 mintAmount = 100 * TOKEN_UNIT;
        vm.startPrank(minter);
        // Expect revert when minting to the zero address
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.mint(address(0), mintAmount);
        vm.stopPrank();
    }

    function test_mint_WhenPausedReverts() public {
        vm.prank(pauser);
        token.pause();

        // Attempt to mint new tokens while the contract is paused
        vm.startPrank(minter);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.mint(alice, 100 * TOKEN_UNIT);
        vm.stopPrank();

        // Validate alice's balance remains unchanged
        assertEq(token.balanceOf(alice), 0, "alice's balance should not change");
    }

    function test_mint_ZeroAmountReverts() public {
        vm.startPrank(minter);
        vm.expectRevert(VisionToken.ZeroAmount.selector);
        token.mint(alice, 0);
        vm.stopPrank();
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), INITIAL_SUPPLY_VSN);
    }

    function testFuzz_mint_ByNonMinterRoleReverts(address user_) public {
        uint256 amount = 100 * TOKEN_UNIT;
        vm.assume(!token.hasRole(token.MINTER_ROLE(), user_));
        vm.assume(user_ != address(0));

        vm.startPrank(user_);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user_, token.MINTER_ROLE()
            )
        );
        token.mint(alice, amount);
        vm.stopPrank();
        assertEq(token.totalSupply(), INITIAL_SUPPLY_VSN);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_mint_ByOtherRolesReverts() public {
        uint256 amount = 100 * TOKEN_UNIT;
        address[3] memory otherRoles = [roleAdmin, pauser, upgrader];

        for (uint256 i; i < otherRoles.length; i++) {
            address otherRole = otherRoles[i];
            vm.startPrank(otherRole);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector, otherRole, token.MINTER_ROLE()
                )
            );
            token.mint(alice, amount);
            vm.stopPrank();

            assertEq(token.totalSupply(), INITIAL_SUPPLY_VSN);
            assertEq(token.balanceOf(alice), 0);
        }
    }

    function test_mint_AfterRoleRevokedReverts() public {
        uint256 amount = 100 * TOKEN_UNIT;
        vm.startPrank(roleAdmin);
        token.revokeRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.startPrank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, minter, token.MINTER_ROLE()
            )
        );
        token.mint(alice, amount);
        vm.stopPrank();
        assertEq(token.totalSupply(), INITIAL_SUPPLY_VSN);
        assertEq(token.balanceOf(minter), 0);
    }

    function test_mint_ToMultipleAddresses() public {
        uint256 aliceMint = 100 * TOKEN_UNIT;
        uint256 bobMint = 200 * TOKEN_UNIT;
        uint256 charlieMint = 200 * TOKEN_UNIT;

        vm.startPrank(minter);
        token.mint(alice, aliceMint);
        token.mint(bob, bobMint);
        token.mint(charlie, charlieMint);
        vm.stopPrank();

        // Validate the total supply and balances
        assertEq(
            token.totalSupply(),
            INITIAL_SUPPLY_VSN + aliceMint + bobMint + charlieMint,
            "Total supply should equal the sum of all mints"
        );
        assertEq(token.balanceOf(alice), aliceMint, "Alice's balance should match the mint amount");
        assertEq(token.balanceOf(bob), bobMint, "Bob's balance should match the mint amount");
        assertEq(token.balanceOf(charlie), charlieMint, "Charlie's balance should match the mint amount");
    }

    function test_burn() public {
        // Mint tokens to the minter for burning
        uint256 initialAmount = 1000 * TOKEN_UNIT;
        uint256 burnAmount = 100 * TOKEN_UNIT;
        setUser(minter, initialAmount);
        setUser(alice, initialAmount);
        setUser(bob, initialAmount);
        setUser(charlie, initialAmount);
        uint256 initialSupply = token.totalSupply();

        // Burn tokens
        vm.startPrank(minter);
        vm.expectEmit(address(token));
        emit VisionToken.Burn(minter, burnAmount);
        token.burn(burnAmount);
        vm.stopPrank();

        // Verify remaining balance
        uint256 expectedBalance = initialAmount - burnAmount;
        assertEq(token.balanceOf(minter), expectedBalance, "Remaining balance should be reduced by the burned amount");
        assertEq(token.totalSupply(), initialSupply - burnAmount);
    }

    function test_burn_WhenPausedReverts() public {
        // Mint tokens to minter
        setUser(minter, 1000 * TOKEN_UNIT);

        // Pause the contract
        vm.prank(pauser);
        token.pause();

        // Attempt to burn tokens while the contract is paused
        vm.startPrank(minter);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.burn(100 * TOKEN_UNIT); // Attempt to burn tokens
        vm.stopPrank();

        // Validate minter's balance remains unchanged
        assertEq(token.balanceOf(minter), 1000 * TOKEN_UNIT, "minter's balance should not change");
    }

    function test_burn_ExceedingBalanceReverts() public {
        uint256 amount = 100 * TOKEN_UNIT;

        vm.startPrank(minter);
        token.mint(minter, amount);
        uint256 burnAmount = amount + 1;

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, minter, amount, burnAmount)
        );
        token.burn(burnAmount);
        vm.stopPrank();
    }

    function test_burn_NoTokensOwnedReverts() public {
        uint256 burnAmount = 100 * TOKEN_UNIT;

        vm.startPrank(minter);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, minter, 0, burnAmount));
        token.burn(burnAmount);
        vm.stopPrank();
    }

    function test_burn_AfterRoleRevokedReverts() public {
        uint256 amount = 100 * TOKEN_UNIT;
        // Mint tokens to minter
        setUser(minter, amount);
        vm.startPrank(roleAdmin);
        token.revokeRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.startPrank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, minter, token.MINTER_ROLE()
            )
        );
        token.burn(amount);
        vm.stopPrank();
    }

    function test_burn_ZeroAmountReverts() public {
        uint256 initialAmount = 1000 * TOKEN_UNIT;
        setUser(minter, initialAmount);

        // Attempt to burn zero tokens
        vm.startPrank(minter);
        vm.expectRevert(VisionToken.ZeroAmount.selector);
        token.burn(0);
        vm.stopPrank();
    }

    function testFuzz_burn_ByNonMinterRoleReverts(address user_) public {
        // Ensure the account has some balance to burn
        vm.assume(!token.hasRole(token.MINTER_ROLE(), user_));
        vm.assume(user_ != address(0) && user_ != address(treasury));
        setUser(user_, 1000 * TOKEN_UNIT);

        // Attempt to burn tokens
        vm.startPrank(user_);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user_, token.MINTER_ROLE()
            )
        );
        token.burn(100 * TOKEN_UNIT);
        vm.stopPrank();
    }

    function test_burn_ByOtherRolesReverts() public {
        address[3] memory otherRoles = [roleAdmin, pauser, upgrader];

        for (uint256 i; i < otherRoles.length; i++) {
            address otherRole = otherRoles[i];
            setUser(otherRole, 1000 * TOKEN_UNIT);
            vm.startPrank(otherRole);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector, otherRole, token.MINTER_ROLE()
                )
            );
            token.burn(100 * TOKEN_UNIT);
            vm.stopPrank();

            // Verify balances remain unchanged
            assertEq(token.balanceOf(otherRole), 1000 * TOKEN_UNIT, "otherRole's balance should not change");
        }
    }

    function test_approve_WhenPausedReverts() public {
        // Mint tokens to alice and approve bob to transfer from alice
        setUser(alice, 1000 * TOKEN_UNIT);
        setUser(bob, 1000 * TOKEN_UNIT);

        // approve bob to transfer from alice for 100
        vm.prank(alice);
        token.approve(bob, 100 * TOKEN_UNIT);

        // Pause the contract
        vm.prank(pauser);
        token.pause();

        // approve bob to transfer from alice for 200 when paused should revert
        vm.startPrank(alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.approve(bob, 200 * TOKEN_UNIT);
        vm.stopPrank();

        // Validate balances and allowance remain unchanged
        assertEq(token.balanceOf(alice), 1000 * TOKEN_UNIT, "alice's balance should not change");
        assertEq(token.balanceOf(bob), 1000 * TOKEN_UNIT, "bob's balance should not change");
        assertEq(token.allowance(alice, bob), 100 * TOKEN_UNIT, "allowance should remain unchanged");
        assertEq(token.balanceOf(charlie), 0, "charlie's balance should not change");
    }
}
