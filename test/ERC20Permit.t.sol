// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
// solhint-disable func-name-mixedcase

import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import {BaseTest} from "./BaseTest.t.sol";

contract ERC20PermitTest is BaseTest {
    bytes32 public domainSeparator;

    function setUp() public {
        // Initialize roles
        deployVisionToken();

        domainSeparator = token.DOMAIN_SEPARATOR();

        // Mint tokens
        setUser(alice, 1000 * TOKEN_UNIT);
        setUser(bob, 1000 * TOKEN_UNIT);
    }

    function test_permit() public {
        uint256 nonce = token.nonces(alice);
        uint256 deadline = block.timestamp + 1 days;
        uint256 amount = 100 * TOKEN_UNIT;

        (uint8 v, bytes32 r, bytes32 s) =
            signPermit(alice, bob, amount, nonce, deadline, domainSeparator, aliceWallet.privateKey);

        // anyone can submit this permit
        token.permit(alice, bob, amount, deadline, v, r, s);

        // Verify that Bob has the allowance after permit
        assertEq(token.allowance(alice, bob), amount, "Allowance should be updated");
    }

    function test_permit_ExpiredReverts() public {
        uint256 nonce = token.nonces(alice);
        uint256 deadline = block.timestamp; // expired deadline
        uint256 amount = TOKEN_UNIT;

        (uint8 v, bytes32 r, bytes32 s) =
            signPermit(alice, bob, amount, nonce, deadline, domainSeparator, aliceWallet.privateKey);

        vm.warp(block.timestamp + 1 hours);
        // Expect revert if permit is expired
        vm.expectRevert(abi.encodeWithSelector(ERC20PermitUpgradeable.ERC2612ExpiredSignature.selector, deadline));
        token.permit(alice, bob, amount, deadline, v, r, s);
    }

    function test_permit_AlreadyUsedReverts() public {
        uint256 nonce = token.nonces(alice);
        uint256 deadline = block.timestamp + 1 days; // valid deadline
        uint256 amount = 100 * TOKEN_UNIT;

        (uint8 v, bytes32 r, bytes32 s) =
            signPermit(alice, bob, amount, nonce, deadline, domainSeparator, aliceWallet.privateKey);

        // Submit the permit
        token.permit(alice, bob, amount, deadline, v, r, s);

        // Expect revert if permit is used again
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20PermitUpgradeable.ERC2612InvalidSigner.selector, 0x0753edA9bFb6d40175BD594a9fDF83ce33CCA20a, alice
            )
        );
        token.permit(alice, bob, amount, deadline, v, r, s);
    }
}
