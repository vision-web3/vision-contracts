// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@solmate/contracts/tokens/ERC20.sol";
import {ERC4626} from "@solmate/contracts/tokens/ERC4626.sol";
import {SafeTransferLib} from "@solmate/contracts/utils/SafeTransferLib.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IStakedVision, RewardsCycle, UserCooldown} from "./interfaces/IStakedVision.sol";

/**
 * @title Staked Vision
 *
 * @notice The staking contract incentivizes users to lock tokens by distributing rewards.
 * It receives Vision tokens from various sources and distributes them linearly over reward cycles.
 * The contract enforces rules such as a cooldown period for withdrawals and a yield cap on the pool.
 *
 * @dev If the cooldown duration is set to zero, the contract follows the ERC4626 standard,
 * disabling the `cooldownShares` and `cooldownAssets` functions.
 * If the cooldown duration is greater than zero, the standard ERC4626 `withdraw` and `redeem`
 * functions are disabled, enabling `cooldownShares` and `cooldownAssets` instead.
 */
contract StakedVision is IStakedVision, ERC4626, AccessControl, Pausable {
    /*//////////////////////////////////////////////////////////////
                             USED LIBRARIES                            
    //////////////////////////////////////////////////////////////*/

    using SafeTransferLib for ERC20;
    using SafeCast for uint256;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS                             
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 internal constant CRITICAL_OPS_ROLE = keccak256("CRITICAL_OPS_ROLE");
    /// @dev 1BPS = 0.0000000001%
    /// @dev 10000000000BPM = 1%
    uint256 private constant BASIS_POINT_SCALE = 1e12;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES                                                 
    //////////////////////////////////////////////////////////////*/

    uint256 internal totalAssets_;
    uint256 public cooldownDuration;
    uint256 public maximumRewardsCycleDuration = 60 days;
    RewardsCycle public rewardsCycle;
    mapping(address => UserCooldown) public cooldowns;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier ensureCooldownOff() {
        if (cooldownDuration != 0) revert OperationNotAllowed();
        _;
    }

    modifier ensureCooldownOn() {
        if (cooldownDuration == 0) revert OperationNotAllowed();
        _;
    }

    /**
     * @notice Construct a Staked Vision instance
     *
     * @param asset_ The Vision token contract address
     * @param cooldownDuration_ The cooldown duration when exiting
     * @param pauser The address of the pauser role
     * @param criticalOps The address of the critical operation role
     * @param defaultAdmin The address of the default admin of the roles
     */
    constructor(ERC20 asset_, uint256 cooldownDuration_, address pauser, address criticalOps, address defaultAdmin)
        ERC4626(asset_, "Staked VSN", "sVSN")
    {
        if (pauser == address(0) || criticalOps == address(0) || address(defaultAdmin) == address(0)) {
            revert InvalidZeroAddress();
        }
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(CRITICAL_OPS_ROLE, criticalOps);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _updateCooldownDuration(cooldownDuration_);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC                    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints vault shares to receiver by depositing
     * exactly amount of underlying tokens
     *
     * @param assets The amount of assets to deposit
     * @param receiver The address of the vault shares receiver
     *
     * @return The amount of vault shares received
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        distributeRewards();
        return super.deposit(assets, receiver);
    }

    /**
     * @notice Mints exactly shares vault shares to receiver by depositing
     * amount of underlying tokens.
     *
     * @param shares The amount of vault shares to be received
     * @param receiver The address of the vault shares receiver
     *
     * @return The amount of assets to deposit
     */
    function mint(uint256 shares, address receiver) public override returns (uint256) {
        distributeRewards();
        return super.mint(shares, receiver);
    }

    /**
     * @notice Burns vault shares from owner and sends exactly assets of
     * underlying tokens to receiver
     *
     * @param assets The amount of assets to be received
     * @param receiver The address of the assets receiver
     * @param owner The owner of the vault shares
     *
     * @return The amount of vault shares to be burned
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        ensureCooldownOff
        returns (uint256)
    {
        distributeRewards();
        return super.withdraw(assets, receiver, owner);
    }

    /**
     * @notice Burns exactly shares from owner and sends assets of
     * underlying tokens to receiver
     *
     * @param shares The amount of shares to be burned
     * @param receiver The address of the assets receiver
     * @param owner The owner of the vault shares
     *
     * @return The The amount of assets to be received
     */
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        ensureCooldownOff
        returns (uint256)
    {
        distributeRewards();
        return super.redeem(shares, receiver, owner);
    }

    /**
     * @dev See {IStakedVision-cooldownAssets}
     */
    function cooldownAssets(uint256 assets) external ensureCooldownOn returns (uint256) {
        distributeRewards();

        uint256 shares = previewWithdraw(assets);

        totalAssets_ -= assets;

        cooldowns[msg.sender].cooldownEnd = block.timestamp.toUint104() + cooldownDuration.toUint104();
        cooldowns[msg.sender].lockedAmount += assets.toUint152();

        _burn(msg.sender, shares);

        emit CooldownStarted(msg.sender, assets, shares, cooldowns[msg.sender].cooldownEnd);

        return shares;
    }

    /**
     * @dev See {IStakedVision-cooldownShares}
     */
    function cooldownShares(uint256 shares) external ensureCooldownOn returns (uint256) {
        distributeRewards();

        uint256 assets = previewRedeem(shares);

        totalAssets_ -= assets;

        cooldowns[msg.sender].cooldownEnd = block.timestamp.toUint104() + cooldownDuration.toUint104();
        cooldowns[msg.sender].lockedAmount += assets.toUint152();

        _burn(msg.sender, shares);

        emit CooldownStarted(msg.sender, assets, shares, cooldowns[msg.sender].cooldownEnd);

        return assets;
    }

    /**
     * @dev See {IStakedVision-claim}
     */
    function claim(address receiver) external whenNotPaused {
        UserCooldown storage userCooldown = cooldowns[msg.sender];
        uint256 assets = userCooldown.lockedAmount;

        // slither-disable-next-line timestamp
        if (block.timestamp >= userCooldown.cooldownEnd || cooldownDuration == 0) {
            userCooldown.cooldownEnd = 0;
            userCooldown.lockedAmount = 0;

            asset.safeTransfer(receiver, assets);

            emit AssetsClaimed(msg.sender, receiver, assets);
        } else {
            revert CooldownNotElapsed();
        }
    }

    function afterDeposit(uint256 amount, uint256) internal override {
        totalAssets_ += amount;
    }

    function beforeWithdraw(uint256 amount, uint256) internal override {
        totalAssets_ -= amount;
    }

    /*//////////////////////////////////////////////////////////////
                             REWARDS LOGIC                           
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IStakedVision-distributeRewards}
     */
    function distributeRewards() public whenNotPaused {
        (uint256 rewards, uint256 surplusRewards, uint256 uncappedRewards) = previewDistributeRewards();

        // slither-disable-next-line timestamp
        if (rewards != 0) {
            rewardsCycle.unvestedAmount -= uncappedRewards;
            rewardsCycle.surplus += surplusRewards;
            rewardsCycle.lastDistributionTimestamp = block.timestamp;
            totalAssets_ += rewards;
            emit DistributeRewards(rewards);
        }
    }

    /**
     * @dev See {IStakedVision-previewDistributeRewards}
     */
    function previewDistributeRewards() public view returns (uint256, uint256, uint256) {
        uint256 elapsedTimeSinceLastRewards;
        // slither-disable-next-line timestamp
        if (block.timestamp < rewardsCycle.endTimestamp) {
            elapsedTimeSinceLastRewards = block.timestamp - rewardsCycle.lastDistributionTimestamp;
        } else {
            if (rewardsCycle.lastDistributionTimestamp >= rewardsCycle.endTimestamp) return (0, 0, 0);
            /// @dev Distribute the remaining rewards of the previous cycle
            elapsedTimeSinceLastRewards = rewardsCycle.endTimestamp - rewardsCycle.lastDistributionTimestamp;
        }

        uint256 uncappedRewards = rewardsCycle.unvestedAmount.mulDiv(
            elapsedTimeSinceLastRewards, rewardsCycle.endTimestamp - rewardsCycle.lastDistributionTimestamp
        );
        /// @dev No cap on the rewards
        // slither-disable-next-line incorrect-equality
        if (rewardsCycle.bpsYieldCapPerSecond == 0) {
            return (uncappedRewards, 0, uncappedRewards);
        }
        uint256 cappedRewards =
            totalAssets_.mulDiv(elapsedTimeSinceLastRewards * rewardsCycle.bpsYieldCapPerSecond, BASIS_POINT_SCALE);
        uint256 surplusRewards = cappedRewards < uncappedRewards ? uncappedRewards - cappedRewards : 0;
        uint256 rewards = uncappedRewards - surplusRewards;

        return (rewards, surplusRewards, uncappedRewards);
    }

    /**
     * @dev See {ERC4626-totalAssets}
     */
    function totalAssets() public view override returns (uint256) {
        (uint256 rewards,,) = previewDistributeRewards();
        return totalAssets_ + rewards;
    }

    /*//////////////////////////////////////////////////////////////
                            RBAC OPERATIONS                          
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IStakedVision-createRewardsCycle}
     */
    function createRewardsCycle(uint256 rewardsAmount, uint256 rewardsCycleEndTimestamp, uint256 bpsYieldCapPerSecond)
        external
        onlyRole(CRITICAL_OPS_ROLE)
    {
        /// @dev Distribute remaining rewards of the previous cycle if necessary
        distributeRewards();

        // slither-disable-next-line timestamp
        if (rewardsCycleEndTimestamp <= block.timestamp) {
            revert CycleEndTimestampInThePast();
        }
        // slither-disable-next-line timestamp
        if (rewardsCycle.endTimestamp > block.timestamp) {
            revert PreviousCycleNotFinished();
        }
        // slither-disable-next-line timestamp
        if (rewardsCycleEndTimestamp - block.timestamp > maximumRewardsCycleDuration) {
            revert RewardsCycleDurationTooLong();
        }
        /// @dev Funds sent to the contract, but unaccounted for
        uint256 availableRewards = asset.balanceOf(address(this)) - totalAssets_ - rewardsCycle.surplus;
        if (rewardsAmount > availableRewards) revert NotEnoughRewardFunds();

        rewardsCycle.unvestedAmount = rewardsAmount;
        rewardsCycle.endTimestamp = rewardsCycleEndTimestamp;
        rewardsCycle.lastDistributionTimestamp = block.timestamp;
        rewardsCycle.bpsYieldCapPerSecond = bpsYieldCapPerSecond;

        emit RewardsCycleCreated(
            rewardsCycle.unvestedAmount, rewardsCycleEndTimestamp, rewardsCycle.bpsYieldCapPerSecond
        );
    }

    /**
     * @dev See {IStakedVision-withdrawSurplusRewards}
     */
    function withdrawSurplusRewards(address receiver) external onlyRole(CRITICAL_OPS_ROLE) {
        if (rewardsCycle.surplus == 0) revert NoSurplusToWithdraw();
        uint256 surplusRewards = rewardsCycle.surplus;
        rewardsCycle.surplus = 0;
        asset.safeTransfer(receiver, surplusRewards);
        emit WithdrawSurplus(receiver, surplusRewards);
    }

    /**
     * @dev See {IStakedVision-rescueTokens}
     */
    function rescueTokens(address token, uint256 amount, address to) external onlyRole(CRITICAL_OPS_ROLE) {
        if (token == address(asset)) revert InvalidToken();
        ERC20(token).safeTransfer(to, amount);
    }

    /**
     * @dev See {IStakedVision-updateCooldownDuration}
     */
    function updateCooldownDuration(uint256 cooldownDuration_) external onlyRole(CRITICAL_OPS_ROLE) {
        if (cooldownDuration_ == cooldownDuration) {
            revert SameCooldownDuration();
        }
        _updateCooldownDuration(cooldownDuration_);
    }

    /**
     * @dev See {IStakedVision-updateBpsYieldCapPerSecond}
     */
    function updateBpsYieldCapPerSecond(uint256 bpsYieldCapPerSecond) external onlyRole(CRITICAL_OPS_ROLE) {
        uint256 previousBpsYieldCapPerSecond = rewardsCycle.bpsYieldCapPerSecond;
        if (previousBpsYieldCapPerSecond == bpsYieldCapPerSecond) {
            revert SameBpsYieldCapPerSecond();
        }
        rewardsCycle.bpsYieldCapPerSecond = bpsYieldCapPerSecond;
        emit BpsYieldCapPerSecondUpdated(previousBpsYieldCapPerSecond, bpsYieldCapPerSecond);
    }

    /**
     * @dev Updates the maximum rewards cycle duration.
     * @param newMaximumRewardsCycleDuration The new maximum duration in seconds.
     */
    function updateMaximumRewardsCycleDuration(uint256 newMaximumRewardsCycleDuration)
        external
        onlyRole(CRITICAL_OPS_ROLE)
    {
        if (newMaximumRewardsCycleDuration == maximumRewardsCycleDuration) {
            revert SameMaximumRewardsCycleDuration();
        }
        uint256 previousDuration = maximumRewardsCycleDuration;
        maximumRewardsCycleDuration = newMaximumRewardsCycleDuration;
        emit MaximumRewardsCycleDurationUpdated(previousDuration, newMaximumRewardsCycleDuration);
    }

    /**
     * @dev See {IStakedVision-pause}
     */
    function pause() external override onlyRole(PAUSER_ROLE) {
        super._pause();
    }

    /**
     * @dev See {IStakedVision-unpause}
     */
    function unpause() external override onlyRole(PAUSER_ROLE) {
        super._unpause();
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL                             
    //////////////////////////////////////////////////////////////*/

    function _updateCooldownDuration(uint256 cooldownDuration_) internal {
        uint256 previousCooldownDuration = cooldownDuration;
        cooldownDuration = cooldownDuration_;
        emit CooldownDurationUpdated(previousCooldownDuration, cooldownDuration);
    }
}
