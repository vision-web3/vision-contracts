// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
// solhint-disable func-name-mixedcase

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {BaseTest} from "./BaseTest.t.sol";

contract ERC20Test is BaseTest {
    function setUp() public {
        // Initialize roles
        deployVisionToken();
    }

    function test_transfer_WhenPausedReverts() public {
        // Mint tokens to alice and ensure alice can transfer when not paused
        setUser(alice, 1000 * TOKEN_UNIT);

        // Pause the contract
        vm.startPrank(pauser);
        token.pause();
        vm.stopPrank();

        vm.startPrank(alice);
        // Attempt to transfer tokens while the contract is paused
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.transfer(bob, 100 * TOKEN_UNIT);
        vm.stopPrank();

        // Validate that balances remain unchanged
        assertEq(token.balanceOf(alice), 1000 * TOKEN_UNIT, "alice's balance should not change");
        assertEq(token.balanceOf(bob), 0, "bob's balance should not change");
    }

    function test_transfer_WhenUnpaused() public {
        // Mint tokens to alice and ensure blocked
        setUser(alice, 1000 * TOKEN_UNIT);

        // Pause the contract
        vm.prank(pauser);
        token.pause();

        // Attempt to transfer tokens while paused
        vm.startPrank(alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector); // Use the new Paused error from OpenZeppelin 5.2
        token.transfer(bob, 100 * TOKEN_UNIT);
        vm.stopPrank();

        // Unpause the contract
        vm.prank(pauser);
        token.unpause();

        // Now that the contract is unpaused, the transfer should work
        vm.startPrank(alice);
        bool success = token.transfer(bob, 100 * TOKEN_UNIT);
        assertTrue(success, "Transfer should be successful after unpause");
        vm.stopPrank();

        // Validate balances after transfer
        assertEq(token.balanceOf(alice), 900 * TOKEN_UNIT, "alice's balance should decrease");
        assertEq(token.balanceOf(bob), 100 * TOKEN_UNIT, "bob's balance should increase");
    }

    function test_transfer() public {
        // Mint tokens to alice
        vm.startPrank(minter);
        token.mint(alice, 1000 * TOKEN_UNIT); // Mint 1000 tokens to alice
        vm.stopPrank();

        // Alice transfers 100 tokens to bob
        vm.startPrank(alice);
        bool success = token.transfer(bob, 100 * TOKEN_UNIT); // Alice sends 100 tokens
        assertTrue(success, "Transfer should be successful");
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 900 * TOKEN_UNIT, "alice balance should decrease by 100 tokens");
        assertEq(token.balanceOf(bob), 100 * TOKEN_UNIT, "bob balance should increase by 100 tokens");
    }

    function test_transferFrom_UnapprovedAccountReverts() public {
        // Mint tokens to alice
        vm.startPrank(minter);
        token.mint(alice, 1000 * TOKEN_UNIT); // Mint 1000 tokens to alice
        vm.stopPrank();

        // Bob is not approved to spend alice's tokens, so the transfer should fail
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, 100 * TOKEN_UNIT)
        );
        token.transferFrom(alice, bob, 100 * TOKEN_UNIT); // Bob tries to transfer from Alice's account
        vm.stopPrank();
    }

    function test_transferFrom_WhenPausedReverts() public {
        // Mint tokens to alice and approve bob to transfer from alice
        setUser(alice, 1000 * TOKEN_UNIT);
        setUser(bob, 1000 * TOKEN_UNIT);

        vm.prank(alice);
        token.approve(bob, 100 * TOKEN_UNIT);

        // Pause the contract
        vm.prank(pauser);
        token.pause();

        vm.startPrank(bob);
        // Attempt to transferFrom while the contract is paused
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.transferFrom(alice, charlie, 100 * TOKEN_UNIT);
        vm.stopPrank();

        // Validate balances and allowance remain unchanged
        assertEq(token.balanceOf(alice), 1000 * TOKEN_UNIT, "alice's balance should not change");
        assertEq(token.balanceOf(bob), 1000 * TOKEN_UNIT, "bob's balance should not change");
        assertEq(token.allowance(alice, bob), 100 * TOKEN_UNIT, "allowance should remain unchanged");
        assertEq(token.balanceOf(charlie), 0, "charlie's balance should not change");
    }
}
