// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.28;
// solhint-disable immutable-vars-naming

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Vision Token Migrator
 *
 * @notice Contract for migrating from the original single-chain
 * Pantos and Best tokens to the new multi-chain Vision token on Ethereum
 */
contract VisionTokenMigrator is AccessControl {
    /*//////////////////////////////////////////////////////////////
                             USED LIBRARIES                            
    //////////////////////////////////////////////////////////////*/

    using SafeERC20 for ERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS                             
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant CRITICAL_OPS_ROLE = keccak256("CRITICAL_OPS_ROLE");
    uint8 private constant OLD_TOKENS_DECIMALS = 8;
    uint8 private constant VISION_TOKEN_DECIMALS = 18;
    // 0.8875244604 * 1e10 (scaling factor)
    uint256 private constant PAN_TO_VISION_EXCHANGE_RATE = 8875244604;
    // 4.9139034040 * 1e10 (scaling factor)
    uint256 private constant BEST_TO_VISION_EXCHANGE_RATE = 49139034040;
    uint256 private constant EXCHANGE_RATE_SCALING_FACTOR = 1e10;
    // DECIMALS_DIFFERENCE_SCALING = 10 ** (VISION_TOKEN_DECIMALS - OLD_TOKENS_DECIMALS) = 1e10

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES                             
    //////////////////////////////////////////////////////////////*/

    ERC20 private immutable _pantosToken;
    ERC20 private immutable _bestToken;
    ERC20 private immutable _visionToken;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES                                                 
    //////////////////////////////////////////////////////////////*/

    bool private _tokenMigrationStarted;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS                          
    //////////////////////////////////////////////////////////////*/

    error InvalidZeroAddress();
    error UnexpectedDecimals();
    error TokenMigrationNotStarted();
    error TokenMigrationAlreadyStarted();
    error ZeroTokensToMigrate();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS                                                           
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Event that is emitted when the token migration starts
     *
     * @param visionTokenAmount The amount of Vision tokens available for migration
     */
    event TokenMigrationStarted(uint256 visionTokenAmount);

    /**
     * @notice Event that is emitted when an account has migrated its
     * tokens
     *
     * @param accountAddress The address of the token holder account
     * @param pantosTokensAmount The amount of Pantos tokens that has been migrated
     * @param bestTokensAmount The amount of BEST tokens that has been migrated
     * @param visionTokensAmount The amount of Vision tokens received
     */
    event TokensMigrated(
        address accountAddress, uint256 pantosTokensAmount, uint256 bestTokensAmount, uint256 visionTokensAmount
    );

    /**
     * @notice Initializes the contract with token addresses
     *
     * @param pantosTokenAddress The address of the Pantos token contract
     * @param bestTokenAddress The address of the Best token contract
     * @param visionTokenAddress The address of the Vision token contract
     * @param criticalOps The address of the critical operation role
     * @param defaultAdmin The address of the default admin of the roles
     *
     * @dev The token migration is halted until explicitly started in a
     * separate transaction
     */
    constructor(
        address pantosTokenAddress,
        address bestTokenAddress,
        address visionTokenAddress,
        address criticalOps,
        address defaultAdmin
    ) {
        if (
            pantosTokenAddress == address(0) || bestTokenAddress == address(0) || visionTokenAddress == address(0)
                || criticalOps == address(0) || defaultAdmin == address(0)
        ) {
            revert InvalidZeroAddress();
        }
        _pantosToken = ERC20(pantosTokenAddress);
        _bestToken = ERC20(bestTokenAddress);
        _visionToken = ERC20(visionTokenAddress);

        if (
            _pantosToken.decimals() != OLD_TOKENS_DECIMALS || _bestToken.decimals() != OLD_TOKENS_DECIMALS
                || _visionToken.decimals() != VISION_TOKEN_DECIMALS
        ) revert UnexpectedDecimals();
        _grantRole(CRITICAL_OPS_ROLE, criticalOps);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        _tokenMigrationStarted = false;
    }

    /*//////////////////////////////////////////////////////////////
                            MIGRATION LOGIC                                                           
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates the token migration process. The total number
     * of tokens available for migration will be equal to the circulating
     * supply of PAN and BEST tokens at the time of migration,
     * each multiplied by their conversion rates
     *
     * @param tokenAmount The amount of Vision tokens available for migration
     *
     * @dev There must be an allowance of the token amount for the
     * contract when invoking this function. After the transaction is
     * included in the blockchain, all accounts are able to migrate
     * their own tokens
     */
    function startTokenMigration(uint256 tokenAmount) external onlyRole(CRITICAL_OPS_ROLE) {
        if (_tokenMigrationStarted) revert TokenMigrationAlreadyStarted();
        _tokenMigrationStarted = true;
        _visionToken.safeTransferFrom(msg.sender, address(this), tokenAmount);
        emit TokenMigrationStarted(tokenAmount);
    }

    /**
     * @notice Returns the converted Vision token amount for the user's Pantos token balance
     *
     * @return uint256 The converted amount of Vision tokens
     */
    function previewPantosMigration() external view returns (uint256) {
        uint256 amount = _pantosToken.balanceOf(msg.sender);
        return _previewPantosMigration(amount);
    }

    /**
     * @notice Returns the converted Vision token amount for the user's Best token balance
     *
     * @return uint256 The converted amount of Vision tokens
     */
    function previewBestMigration() external view returns (uint256) {
        uint256 amount = _bestToken.balanceOf(msg.sender);
        return _previewBestMigration(amount);
    }

    /**
     * @notice Returns the total converted Vision token amount for
     * the user's Pantos and BEST token balances
     *
     * @return uint256 The total converted amount of Vision tokens
     */
    function previewPantosAndBestMigration() external view returns (uint256) {
        uint256 pantosAmount = _pantosToken.balanceOf(msg.sender);
        uint256 bestAmount = _bestToken.balanceOf(msg.sender);
        return _previewPantosAndBestMigration(pantosAmount, bestAmount);
    }

    /**
     * @notice Migrate the Pantos and BEST tokens held by
     * the sender of the transaction to the Vision token
     *
     * @dev There must be an allowance of the sender account's total
     * PAN and BEST token balances for this contract when invoking this function
     */
    function migrateTokens() external {
        if (!_tokenMigrationStarted) revert TokenMigrationNotStarted();

        uint256 panTokenAmount = _pantosToken.balanceOf(msg.sender);
        uint256 bestTokenAmount = _bestToken.balanceOf(msg.sender);

        // slither-disable-next-line incorrect-equality
        if (panTokenAmount == 0 && bestTokenAmount == 0) {
            revert ZeroTokensToMigrate();
        }

        uint256 visionTokenAmount = _previewPantosAndBestMigration(panTokenAmount, bestTokenAmount);

        _pantosToken.safeTransferFrom(msg.sender, address(this), panTokenAmount);
        _bestToken.safeTransferFrom(msg.sender, address(this), bestTokenAmount);
        _visionToken.safeTransfer(msg.sender, visionTokenAmount);

        emit TokensMigrated(msg.sender, panTokenAmount, bestTokenAmount, visionTokenAmount);
    }

    /**
     * @notice Checks if token migration has started
     *
     * @return True if the token migration has already started.
     */
    function isTokenMigrationStarted() external view returns (bool) {
        return _tokenMigrationStarted;
    }

    /**
     * @notice Returns the converted Vision token amount for a given Pantos token amount
     *
     * @param amount The amount of Pantos tokens
     *
     * @return uint256 The converted amount of Vision tokens
     */
    function _previewPantosMigration(uint256 amount) internal pure returns (uint256) {
        // The original formula:
        // (amount * PAN_TO_VISION_EXCHANGE_RATE * DECIMALS_DIFFERENCE_SCALING) /
        // EXCHANGE_RATE_SCALING_FACTOR
        // Since DECIMALS_DIFFERENCE_SCALING and EXCHANGE_RATE_SCALING_FACTOR are constants
        // and equal, we can simplifying the formula to: amount * PAN_TO_VISION_EXCHANGE_RATE
        return amount * PAN_TO_VISION_EXCHANGE_RATE;
    }

    /**
     * @notice Returns the converted Vision token amount for a given Best token amount
     *
     * @param amount The amount of Pantos tokens
     *
     * @return uint256 The converted amount of Vision tokens
     */
    function _previewBestMigration(uint256 amount) internal pure returns (uint256) {
        // The original formula:
        // (amount * BEST_TO_VISION_EXCHANGE_RATE * DECIMALS_DIFFERENCE_SCALING)
        // / EXCHANGE_RATE_SCALING_FACTOR
        // Since DECIMALS_DIFFERENCE_SCALING and EXCHANGE_RATE_SCALING_FACTOR are constants and equal,
        // we can simplifying the formula to: amount * BEST_TO_VISION_EXCHANGE_RATE
        return amount * BEST_TO_VISION_EXCHANGE_RATE;
    }

    /**
     * @notice Returns the total converted Vision token amount for
     * given Pantos and BEST token amounts
     *
     * @param pantosAmount The amount of Pantos tokens
     * @param bestAmount The amount of BEST tokens
     *
     * @return uint256 The total converted amount of Vision tokens
     */
    function _previewPantosAndBestMigration(uint256 pantosAmount, uint256 bestAmount)
        internal
        pure
        returns (uint256)
    {
        return _previewPantosMigration(pantosAmount) + _previewBestMigration(bestAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTERS                                                           
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the Pantos to Vision exchange rate
     *
     * @return uint256 The Pantos to Vision exchange rate
     */
    function getPantosToVisionExchangeRate() external pure returns (uint256) {
        return PAN_TO_VISION_EXCHANGE_RATE;
    }

    /**
     * @notice Returns the Best to Vision exchange rate
     *
     * @return uint256 The Best to Vision exchange rate
     */
    function getBestToVisionExchangeRate() external pure returns (uint256) {
        return BEST_TO_VISION_EXCHANGE_RATE;
    }

    /**
     * @notice Returns the exchange rate scaling factor
     *
     * @return uint256 The exchange rate scaling factor
     */
    function getExchangeRateScalingFactor() external pure returns (uint256) {
        return EXCHANGE_RATE_SCALING_FACTOR;
    }

    /**
     * @notice Returns the address of the Pantos token
     *
     * @return uint256 The address of the Pantos token
     */
    function getPantosTokenAddress() external view returns (address) {
        return address(_pantosToken);
    }

    /**
     * @notice Returns the address of the Best token
     *
     * @return uint256 The address of the Best token
     */
    function getBestTokenAddress() external view returns (address) {
        return address(_bestToken);
    }

    /**
     * @notice Returns the address of the Vision token
     *
     * @return uint256 The address of the Vision token
     */
    function getVisionTokenAddress() external view returns (address) {
        return address(_visionToken);
    }
}
