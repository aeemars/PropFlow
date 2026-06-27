// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./PropToken.sol";

/**
 * @title RentDistributor
 * @author PropFlow
 * @notice Accepts USDC rent deposits and allows PropToken holders to pull (claim)
 *         their proportional share of earned rent.
 * @dev Instead of pushing rent to all holders in a single transaction (O(n)),
 *      this contract registers each holder's proportional share locally on deposit.
 *      Users can claim their accrued rent monthly. Expired rent (older than 12 months)
 *      can be pushed automatically to the user's address.
 *
 *      Deploy after PropToken:
 *      KYCRegistry → PropToken → RentDistributor → PropertyRegistry
 */
contract RentDistributor is Ownable {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────
    //  Data Structures
    // ──────────────────────────────────────────────

    struct RentPayment {
        uint256 amount;
        uint256 timestamp;
        bool claimed;
    }

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice The PropToken contract whose holders receive rent.
    PropToken public propToken;

    /// @notice The USDC ERC-20 contract (6 decimals on Arc).
    IERC20 public usdcToken;

    /// @notice Track rent payments for each holder.
    mapping(address => RentPayment[]) public rentPayments;

    /// @notice Running total of all USDC ever deposited.
    uint256 public totalDeposited;

    /// @notice Running total of all USDC ever claimed.
    uint256 public totalClaimed;

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when rent USDC is deposited into the distributor.
    event RentDeposited(address indexed depositor, uint256 amount);

    /// @notice Emitted when a holder claims their rent.
    event RentClaimed(address indexed holder, uint256 amount);

    /// @notice Emitted when expired rent is automatically paid out.
    event AutoRentPaid(address indexed holder, uint256 amount);

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    /**
     * @notice Deploy the RentDistributor.
     * @param _propToken Address of the PropToken contract.
     * @param _usdcToken Address of the USDC ERC-20 contract.
     */
    constructor(
        address _propToken,
        address _usdcToken
    ) Ownable(msg.sender) {
        require(_propToken != address(0), "RentDistributor: zero PropToken");
        require(_usdcToken != address(0), "RentDistributor: zero USDC");

        propToken = PropToken(_propToken);
        usdcToken = IERC20(_usdcToken);
    }

    // ──────────────────────────────────────────────
    //  Deposit
    // ──────────────────────────────────────────────

    /**
     * @notice Deposit USDC rent into the distributor.
     * @dev Calculates and registers the proportional rent share for all current holders.
     *      Caller must approve this contract on USDC first.
     * @param amount USDC amount to deposit (6-decimal units).
     */
    function depositRent(uint256 amount) external {
        require(amount > 0, "RentDistributor: zero deposit");

        usdcToken.safeTransferFrom(msg.sender, address(this), amount);
        totalDeposited += amount;

        uint256 supply = propToken.totalSupply();
        require(supply > 0, "RentDistributor: no tokens minted");

        address[] memory holders = propToken.getHolders();
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 balance = propToken.balanceOf(holder);
            if (balance == 0) continue;

            // Proportional share: (balance * amount) / supply
            uint256 share = (balance * amount) / supply;
            if (share == 0) continue;

            rentPayments[holder].push(RentPayment({
                amount: share,
                timestamp: block.timestamp,
                claimed: false
            }));
        }

        emit RentDeposited(msg.sender, amount);
    }

    // ──────────────────────────────────────────────
    //  Claim Flow
    // ──────────────────────────────────────────────

    /**
     * @notice Claim all accumulated unclaimed rent.
     */
    function claimRent() external {
        _claimRentFor(msg.sender);
    }

    /**
     * @notice Claim all accumulated unclaimed rent for a specific holder.
     * @param holder Address of the holder.
     */
    function claimRentFor(address holder) external {
        _claimRentFor(holder);
    }

    /**
     * @dev Internal helper to execute claims.
     */
    function _claimRentFor(address holder) internal {
        uint256 claimable = 0;
        uint256 length = rentPayments[holder].length;

        for (uint256 i = 0; i < length; i++) {
            if (!rentPayments[holder][i].claimed) {
                claimable += rentPayments[holder][i].amount;
                rentPayments[holder][i].claimed = true;
            }
        }

        require(claimable > 0, "RentDistributor: no rent to claim");
        totalClaimed += claimable;

        usdcToken.safeTransfer(holder, claimable);

        emit RentClaimed(holder, claimable);
    }

    /**
     * @notice Auto-payout expired rent (older than 12 months / 365 days).
     * @dev Can be triggered by keepers or backend cron jobs.
     * @param holder Address of the holder to payout.
     */
    function payoutExpiredRent(address holder) external {
        uint256 expiredAmount = 0;
        uint256 length = rentPayments[holder].length;

        for (uint256 i = 0; i < length; i++) {
            if (!rentPayments[holder][i].claimed && (block.timestamp - rentPayments[holder][i].timestamp >= 365 days)) {
                expiredAmount += rentPayments[holder][i].amount;
                rentPayments[holder][i].claimed = true;
            }
        }

        require(expiredAmount > 0, "RentDistributor: no expired rent to distribute");
        totalClaimed += expiredAmount;

        usdcToken.safeTransfer(holder, expiredAmount);

        emit AutoRentPaid(holder, expiredAmount);
    }

    // ──────────────────────────────────────────────
    //  Views
    // ──────────────────────────────────────────────

    /**
     * @notice Returns total claimable rent for a holder.
     * @param holder Address of the holder.
     */
    function getClaimableRent(address holder) external view returns (uint256) {
        uint256 claimable = 0;
        uint256 length = rentPayments[holder].length;

        for (uint256 i = 0; i < length; i++) {
            if (!rentPayments[holder][i].claimed) {
                claimable += rentPayments[holder][i].amount;
            }
        }
        return claimable;
    }

    /**
     * @notice Returns total expired rent for a holder.
     * @param holder Address of the holder.
     */
    function getExpiredRent(address holder) external view returns (uint256) {
        uint256 expiredAmount = 0;
        uint256 length = rentPayments[holder].length;

        for (uint256 i = 0; i < length; i++) {
            if (!rentPayments[holder][i].claimed && (block.timestamp - rentPayments[holder][i].timestamp >= 365 days)) {
                expiredAmount += rentPayments[holder][i].amount;
            }
        }
        return expiredAmount;
    }

    /**
     * @notice Returns the number of rent payment records for a holder.
     * @param holder Address of the holder.
     */
    function getRentPaymentsCount(address holder) external view returns (uint256) {
        return rentPayments[holder].length;
    }
}
