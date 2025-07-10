// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
// solhint-disable func-name-mixedcase
// solhint-disable max-states-count
// solhint-disable no-console

import {Test, Vm} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {VisionToken} from "../src/VisionToken.sol";

abstract contract BaseTest is Test {
    uint256 public constant TOKEN_DECIMALS = 18;
    string public constant TOKEN_NAME = "Vision";
    string public constant TOKEN_SYMBOL = "VSN";
    uint256 public constant TOKEN_UNIT = 10 ** TOKEN_DECIMALS;
    uint256 public constant INITIAL_SUPPLY_VSN = 1_000_000_000 * TOKEN_UNIT;

    Vm.Wallet public aliceWallet = vm.createWallet("alice");
    Vm.Wallet public bobWallet = vm.createWallet("bob");
    Vm.Wallet public charlieWallet = vm.createWallet("charlie");

    Vm.Wallet public roleAdminWallet = vm.createWallet("roleAdmin");
    Vm.Wallet public pauserWallet = vm.createWallet("pauser");
    Vm.Wallet public minterWallet = vm.createWallet("minter");
    Vm.Wallet public upgraderWallet = vm.createWallet("upgrader");
    // wallet to hold initial supply of vision token
    Vm.Wallet public treasuryWallet = vm.createWallet("treasury");

    address public alice = aliceWallet.addr;
    address public bob = bobWallet.addr;
    address public charlie = charlieWallet.addr;

    address public roleAdmin = roleAdminWallet.addr;
    address public pauser = pauserWallet.addr;
    address public minter = minterWallet.addr;
    address public upgrader = upgraderWallet.addr;
    address public treasury = treasuryWallet.addr;

    VisionToken public token;
    VisionToken public logic;

    function deployVisionToken() public {
        // Deploy the logic contract and proxy
        logic = new VisionToken();

        bytes memory initData = abi.encodeWithSelector(
            VisionToken.initialize.selector,
            INITIAL_SUPPLY_VSN,
            treasury, // treasury wallet receives initial supply
            roleAdmin,
            pauser,
            minter,
            upgrader
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(logic), initData);

        // wrap proxy into VisionToken for easy access
        token = VisionToken(address(proxy));
    }

    function checkStateAfterDeployVisionToken() public view {
        assertEq(token.name(), TOKEN_NAME);
        assertEq(token.symbol(), TOKEN_SYMBOL);
        assertEq(token.decimals(), TOKEN_DECIMALS);
        assertEq(token.totalSupply(), INITIAL_SUPPLY_VSN);
        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), roleAdmin), true);
        assertEq(token.hasRole(token.PAUSER_ROLE(), pauser), true);
        assertEq(token.hasRole(token.MINTER_ROLE(), minter), true);
        assertEq(token.hasRole(token.UPGRADER_ROLE(), upgrader), true);
    }

    function setUser(address account, uint256 balance) internal {
        assertEq(token.balanceOf(account), 0);
        // transfer tokens to account from treasury account
        if (balance > 0) {
            vm.prank(treasury);
            token.transfer(account, balance);
        }
    }

    function signPermit(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        bytes32 domainSeparator,
        uint256 privateKey
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        return vm.sign(privateKey, digest);
    }

    function runBasicFunctionalityTests() public {
        // Constants for testing
        uint256 mintAmount = 1000 * TOKEN_UNIT;
        uint256 transferAmount = 100 * TOKEN_UNIT;
        uint256 burnAmount = 200 * TOKEN_UNIT;

        // Fetch current balances dynamically
        uint256 minterStartBalance = token.balanceOf(minter);
        uint256 aliceStartBalance = token.balanceOf(alice);
        uint256 bobStartBalance = token.balanceOf(bob);
        uint256 charlieStartBalance = token.balanceOf(charlie);

        uint256 totalSupplyStart = token.totalSupply();

        // --- Test Minting ---
        vm.startPrank(minter); // Act as the minter
        token.mint(minter, mintAmount);
        assertEq(token.balanceOf(minter), mintAmount + minterStartBalance, "Minting failed");
        token.transfer(alice, transferAmount); // top up alice
        assertEq(token.balanceOf(alice), transferAmount + aliceStartBalance, "transfer failed");
        vm.stopPrank();

        // --- Test Burning ---
        vm.startPrank(minter); // Only minter can burn
        token.burn(burnAmount);
        assertEq(
            token.balanceOf(minter), minterStartBalance + mintAmount - burnAmount - transferAmount, "Burning failed"
        );
        assertEq(token.balanceOf(alice), transferAmount + aliceStartBalance);
        vm.stopPrank();

        // --- Test Transfers ---
        vm.startPrank(alice); // Alice transfers tokens to Bob
        token.transfer(bob, transferAmount);
        assertEq(token.balanceOf(bob), transferAmount + bobStartBalance, "Transfer failed");
        assertEq(token.balanceOf(alice), aliceStartBalance, "Transfer did not deduct from sender");
        vm.stopPrank();

        // --- Test Pausing and Transfers ---
        vm.startPrank(pauser); // Act as the pauser
        token.pause();
        assertTrue(token.paused(), "Contract is not paused");
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.transfer(charlie, transferAmount); // Should revert while paused
        vm.stopPrank();

        vm.startPrank(pauser);
        token.unpause();
        assertFalse(token.paused(), "Contract is still paused");
        vm.stopPrank();

        vm.startPrank(bob);
        token.transfer(charlie, transferAmount); // Should succeed after unpausing
        assertEq(token.balanceOf(charlie), transferAmount + charlieStartBalance, "Transfer to Charlie failed");
        assertEq(token.balanceOf(bob), bobStartBalance);
        vm.stopPrank();

        // --- Final State Assertions ---
        assertEq(token.totalSupply(), totalSupplyStart + mintAmount, "Total supply mismatch");
        assertEq(token.balanceOf(alice), aliceStartBalance + transferAmount, "Seizing failed to deduct from alice");
    }
}
