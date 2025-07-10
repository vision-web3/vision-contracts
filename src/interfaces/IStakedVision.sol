// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Represents a rewards cycle, including unvested rewards,
/// cycle duration, and yield cap
/// @dev To compute the yield cap: define APY, multiply it with 1e10,
/// and then divide it by the number of seconds in a year.
/// For example, a bpsYieldCapPerSecond corresponding to a 5% APY is:
/// 5e10 / 365 * 24 * 3600 = 1585
/// A bpsYieldCapPerSecond value of 0 indicates that there is no cap on the rewards
struct RewardsCycle {
    uint256 unvestedAmount;
    uint256 endTimestamp;
    uint256 lastDistributionTimestamp;
    uint256 surplus;
    uint256 bpsYieldCapPerSecond;
}

/// @notice Represents a user's cooldown state, including
/// the end of the cooldown period and the locked amount
struct UserCooldown {
    uint104 cooldownEnd;
    uint152 lockedAmount;
}

interface IStakedVision {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS                                                           
    //////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when the cooldown period starts for a user
    event CooldownStarted(address owner, uint256 assets, uint256 shares, uint104 cooldownEnd);
    /// @notice Event emitted when a user claims their assets
    event AssetsClaimed(address owner, address receiver, uint256 assets);
    /// @notice Event emitted when the cooldown duration is updated
    event CooldownDurationUpdated(uint256 previousDuration, uint256 newDuration);
    /// @notice Event emitted when a new rewards cycle is created
    event RewardsCycleCreated(
        uint256 rewardsCycleAmount, uint256 rewardsCycleEndTimestamp, uint256 newBpsYieldCapPerSecond
    );
    /// @notice Event emitted when the cycle's surplus is withdrawn
    event WithdrawSurplus(address receiver, uint256 surplus);
    /// @notice Event emitted when the rewards are distributed
    event DistributeRewards(uint256 rewards);
    /// @notice Event emitted when the BPS yield cap per second is updated
    event BpsYieldCapPerSecondUpdated(uint256 previousBpsYieldCapPerSecond, uint256 newBpsYieldCapPerSecond);
    /// @notice Event emitted when the maximum rewards cycle duration is updated
    event MaximumRewardsCycleDurationUpdated(uint256 previousDuration, uint256 newDuration);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS                          
    //////////////////////////////////////////////////////////////*/

    /// @notice Error emitted when user is not allowed to perform an operation
    error OperationNotAllowed();
    /// @notice Error emitted when the zero address is given
    error InvalidZeroAddress();
    /// @notice Error emitted when the critical ops attempts to create
    /// a new cycle with an end timestamp in the past
    error CycleEndTimestampInThePast();
    /// @notice Error emitted when the critical ops attempts to create
    /// a new cycle before the previous one ends
    error PreviousCycleNotFinished();
    /// @notice Error emitted when the critical ops attempts to create
    /// a rewards cycle with duration that is too long
    error RewardsCycleDurationTooLong();
    /// @notice Error emitted when the critical ops attempts to rescue Vision tokens
    error InvalidToken();
    /// @notice Error emitted when the cooldown period for claiming tokens has not elapsed
    error CooldownNotElapsed();
    /// @notice Error emitted when attempting to create a rewards cycle with insufficient rewards
    error NotEnoughRewardFunds();
    /// @notice Error emitted when the critical ops attempts to withdraw surplus
    /// when there is none available
    error NoSurplusToWithdraw();
    /// @notice Error emitted when the critical ops attempts to update the
    /// cooldown duration with the same value
    error SameCooldownDuration();
    /// @notice Error emitted when the critical ops attempts to update the
    /// bpsYieldCapPerSecond with the same value
    error SameBpsYieldCapPerSecond();
    /// @notice Error emitted when the critical ops attempts to update the
    /// maximum rewards cycle duration with the same value
    error SameMaximumRewardsCycleDuration();

    /*//////////////////////////////////////////////////////////////
                                 GETTERS                                                           
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the cooldown duration in seconds
     *
     * @return uint256 The cooldown duration in seconds
     */
    function cooldownDuration() external view returns (uint256);

    /**
     * @notice Returns the current rewards cycle details
     * @return unvestedAmount The amount of rewards yet to be vested
     * @return endTimestamp The timestamp when the current cycle ends
     * @return lastDistributionTimestamp The timestamp of the last rewards distribution
     * @return surplus The amount of rewards surplus so far of the cycle
     * @return bpsYieldCapPerSecond The yield cap per second in basis points scaled
     */
    function rewardsCycle()
        external
        view
        returns (
            uint256 unvestedAmount,
            uint256 endTimestamp,
            uint256 lastDistributionTimestamp,
            uint256 surplus,
            uint256 bpsYieldCapPerSecond
        );

    /**
     * @notice Returns the cooldown state of a given user
     *
     * @param user The address of the user
     *
     * @return cooldownEnd The timestamp when the cooldown period ends
     * @return lockedAmount The amount of assets locked during the cooldown
     */
    function cooldowns(address user) external view returns (uint104 cooldownEnd, uint152 lockedAmount);

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC                                        
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Redeem assets and initiates a cooldown period before claiming the
     * converted underlying asset. If the user calls this or the `cooldownShares`
     * function again before the previously initiated cooldown period ends,
     * the newly requested assets are added to the locked amount, but the cooldownEnd
     * timestamp is reset for all locked assets, including those already partway
     * through their cooldown
     *
     * @dev Unlike `withdraw` or `redeem`, this function cannot be
     * triggered by an approved operator on behalf of the user.
     * Only direct calls from the owner are permitted
     *
     * @param assets The amount of assets to redeem
     *
     * @return uint256 The amount of exchanged shares
     */
    function cooldownAssets(uint256 assets) external returns (uint256);

    /**
     * @notice Redeem assets and initiates a cooldown period before claiming the
     * converted underlying asset. If the user calls this or the `cooldownAssets`
     * function again before the previously initiated cooldown period ends,
     * the newly requested assets are added to the locked amount, but the cooldownEnd
     * timestamp is reset for all locked assets, including those already partway
     * through their cooldown
     *
     * @dev Unlike `withdraw` or `redeem`, this function cannot be
     * triggered by an approved operator on behalf of the user.
     * Only direct calls from the owner are permitted
     *
     * @param shares The amount of shares to exchange
     *
     * @return uint256 The amount of redeemed assets
     */
    function cooldownShares(uint256 shares) external returns (uint256);

    /**
     * @notice Claim the staking amount after the cooldown period ends.
     * The caller must withdraw the full amount of assets
     *
     * @dev `claim` can also be called if the cooldown is set to zero,
     * allowing users to claim any remaining assets locked
     *
     * @param receiver The address receiving the withdrawn assets
     */
    function claim(address receiver) external;

    /*//////////////////////////////////////////////////////////////
                             REWARDS LOGIC                                                     
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Previews the rewards distribution including uncapped, capped,
     * and surplus rewards. The rewards are calculated based on the
     * elapsed time since the last distribution and applies any yield cap if set
     *
     * @return uint256 The amount of rewards eligible for distribution
     * @return uint256 The amount of surplus rewards exceeding the capped rewards
     * @return uint256 The uncapped rewards, before applying any cap
     */
    function previewDistributeRewards() external view returns (uint256, uint256, uint256);

    /**
     * @notice Distributes rewards to the staking contract.
     * The function updates the rewards cycle state, including unvested rewards,
     * surplus, and last distribution timestamp
     *
     * @dev Only updates the state and transfers rewards if there are rewards to distribute.
     * If there are surplus rewards, they are added to the surplus pool.
     * The total assets are updated with the distributed rewards.
     */
    function distributeRewards() external;

    /*//////////////////////////////////////////////////////////////
                            RBAC OPERATIONS                          
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Create a new rewards cycle
     *
     * @param rewardsAmount The total amount of rewards to be distributed in this cycle
     * @param rewardsCycleEndTimestamp The timestamp indicating when the cycle ends
     * @param bpsYieldCapPerSecond The yield cap per second, measured in
     * basis points scaled (1BPS = 0.00000001% or 100000000BPM = 1%)
     */
    function createRewardsCycle(uint256 rewardsAmount, uint256 rewardsCycleEndTimestamp, uint256 bpsYieldCapPerSecond)
        external;

    /**
     * @notice Withdraws surplus rewards from the contract
     *
     * @param receiver The address that will receive the surplus rewards
     */
    function withdrawSurplusRewards(address receiver) external;

    /**
     * @notice Rescues tokens mistakenly sent to the contract and
     * transfers them to a specified address
     *
     * @param token The address of the token to be rescued
     * @param amount The amount of tokens to transfer
     * @param to The recipient address of the rescued tokens
     */
    function rescueTokens(address token, uint256 amount, address to) external;

    /**
     * @notice Update the cooldown duration required before users can claim the assets
     *
     * @param cooldownDuration_ The new cooldown duration in seconds
     */
    function updateCooldownDuration(uint256 cooldownDuration_) external;

    /**
     * @notice Updates the yield cap per second, measured in basis points scaled
     *
     * @param bpsYieldCapPerSecond The new yield cap per second in basis points scaled
     */
    function updateBpsYieldCapPerSecond(uint256 bpsYieldCapPerSecond) external;

    /**
     * @notice Pauses the contract, preventing any further operations
     *
     * @dev This function should only be called by an authorized role
     */
    function pause() external;

    /**
     * @notice Unpauses the contract, allowing any operations to happen
     *
     * @dev This function should only be called by an authorized role
     */
    function unpause() external;
}
