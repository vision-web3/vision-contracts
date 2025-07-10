// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title VisionToken
 * @notice An ERC20 token that includes pausing, role-based access control, off-chain approvals, and
 * upgradeability through the UUPS proxy pattern.
 */
contract VisionToken is ERC20PausableUpgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable {
    string private constant _NAME = "Vision";
    string private constant _SYMBOL = "VSN";

    /// @notice Role for pausing the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role for minting and burning tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role for upgrading the contract.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /**
     * @dev Emitted when `amount` tokens are minted by `MINTER_ROLE` and assigned to `to`.
     */
    event Mint(address indexed minter, address indexed to, uint256 amount);

    /**
     * @dev Emitted when `amount` tokens are burnt by `MINTER_ROLE` from its own balance.
     */
    event Burn(address indexed burner, uint256 amount);

    /**
     * @dev Error thrown when mint/burn amount passed to {mint} / {burn} is zero.
     */
    error ZeroAmount();

    /**
     * @dev Error thrown when address passed as param is zero.
     */
    error ZeroAddress();

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 initialSupply,
        address recipient,
        address roleAdmin,
        address pauser,
        address minter,
        address upgrader
    ) public initializer {
        __ERC20_init(_NAME, _SYMBOL);
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init(_NAME);
        __UUPSUpgradeable_init();

        if (
            recipient == address(0) || roleAdmin == address(0) || pauser == address(0) || minter == address(0)
                || upgrader == address(0)
        ) {
            revert ZeroAddress();
        }

        _mint(recipient, initialSupply);

        _grantRole(DEFAULT_ADMIN_ROLE, roleAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    /**
     * @notice Pauses the Token contract.
     * @dev Only callable by accounts with the `PAUSER_ROLE`
     * and only if the contract is not paused.
     * Requirements the contract must not be paused.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the Token contract.
     * @dev Only callable by accounts with the `PAUSER_ROLE`
     * and only if the contract is paused.
     * Requirement: the contract must be paused.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Mints tokens to a specified address.
     * @dev Only callable by accounts with the `MINTER_ROLE`.
     * Emits a {Mint} event with `minter` set to the address that initiated the minting,
     * `to` set to the recipient's address, and `amount` set to the amount of tokens minted.
     * If the amount is zero, a {ZeroAmount} error will be triggered.
     * Requirement: the contract must not be paused. {ERC20PausableUpgradeable-_update} enforces it.
     * @param to The address to receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (amount == 0) revert ZeroAmount();
        _mint(to, amount);
        emit Mint(_msgSender(), to, amount);
    }

    /**
     * @notice Burn tokens from own balance.
     * @dev Only callable by accounts with the `MINTER_ROLE`. The `value` must be greater than 0 and less than or
     * equal to the caller's token balance.
     * Emits a {Burn} event with `burner` set to the address that initiated the burn,
     * and `amount` set to the number of tokens burned.
     * If the amount is zero, a {ZeroAmount} error will be triggered.
     * Requirement: the contract must not be paused. {ERC20PausableUpgradeable-_update} enforces it.
     * @param amount The number of tokens to burn.
     */
    function burn(uint256 amount) external onlyRole(MINTER_ROLE) {
        if (amount == 0) revert ZeroAmount();
        _burn(_msgSender(), amount);
        emit Burn(_msgSender(), amount);
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirement: the contract must not be paused.
     */
    function approve(address spender, uint256 value) public virtual override whenNotPaused returns (bool) {
        return super.approve(spender, value);
    }

    /**
     * @dev See {IERC20Permit-permit}.
     *
     * Requirement: the contract must not be paused.
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
        override
        whenNotPaused
    {
        super.permit(owner, spender, value, deadline, v, r, s);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @dev See {ERC20-_update}.
     *
     * Requirement: the contract must not be paused.
     */
    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        super._update(from, to, value);
    }
}
