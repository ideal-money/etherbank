pragma solidity ^0.4.24;

import "./openzeppelin/contracts/math/SafeMath.sol";
import "./EtherDollar.sol";
import "./EtherBank.sol";


/**
 * @title EtherBank's Liquidator contract.
 */
contract Liquidator {
    using SafeMath for uint256;

    EtherDollar internal token;
    EtherBank internal bank;

    uint256 internal lastLiquidationId;

    enum LiquidationState {
        ACTIVE,
        FINISHED
    }

    struct Liquidation {
        uint256 loanId;
        uint256 collateral;
        uint256 amount;
        uint256 endTime;
        uint256 bestBid;
        address bestBidder;
        LiquidationState state;
    }

    mapping(uint256 => Liquidation) public liquidations;
    mapping(address => uint256) public deposits;

    event LiquidationStarted(uint256 indexed liquidationId, uint256 indexed loanId, uint256 collateral, uint256 amount, uint256 endTime);
    event LiquidationStopped(uint256 indexed liquidationId, uint256 indexed loanId, uint256 bestBid, address bestBidder);
    event Withdrew(address indexed withdrawalAccount, uint256 amount);

    string private constant ONLY_ETHER_BANK = "ONLY_ETHER_BANK";
    string private constant NO_DEPOSIT = "NO_DEPOSIT";
    string private constant INVALID_AMOUNT = "INVALID_AMOUNT";
    string private constant NOT_ACTIVE_LIQUIDATION = "NOT_ACTIVE_LIQUIDATION";
    string private constant OPEN_LIQUIDATION = "OPEN_LIQUIDATION";
    string private constant NO_BID = "NO_BID";
    string private constant INADEQUATE_BIDDING = "INADEQUATE_BIDDING";
    string private constant INSUFFICIENT_FUNDS = "INSUFFICIENT_FUNDS";

    constructor(address _tokenAddr, address _etherBankAddr)
        public
    {
        bank = EtherBank(_etherBankAddr);
        token = EtherDollar(_tokenAddr);
    }

    /**
     * @notice Withdrew EtherDollar.
     */
    function withdraw()
        external
    {
        require (deposits[msg.sender] > 0, NO_DEPOSIT);

        uint256 amount = deposits[msg.sender];
        deposits[msg.sender] = 0;
        emit Withdraw(msg.sender, amount);
        token.transfer(msg.sender, amount);
    }

    /**
     * @dev Start a liquidation.
     * @param loadId The id of the loan which is under liquidation.
     * @param collateral The amount of the loan's collateral.
     * @param amount The amount of the loan.
     * @param duration The duration of the liquidation.
     */
    function startLiquidation(
        uint256 loadId,
        uint256 collateral,
        uint256 amount,
        uint256 duration
    )
        external
        onlyEtherBank
        throwIfEqualToZero(collateral)
        throwIfEqualToZero(amount)
    {
        uint256 liquidationId = ++lastLiquidationId;
        uint256 endTime = duration.add(now);
        liquidations[liquidationId].loanId = loadId;
        liquidations[liquidationId].collateral = collateral;
        liquidations[liquidationId].amount = amount;
        liquidations[liquidationId].endTime = endTime;
        liquidations[liquidationId].state = LiquidationState.ACTIVE;
        emit LiquidationStarted(liquidationId, loadId, collateral, amount, endTime);
    }

    /**
     * @notice Stop the liquidation.
     * @param liquidationId The id of the liquidation.
     */
    function stopLiquidation(uint256 liquidationId)
        external
        onlyActive(liquidationId)
    {
        require(liquidations[liquidationId].endTime <= now, OPEN_LIQUIDATION);
        require(liquidations[liquidationId].bestBid != 0, NO_BID);
        liquidations[liquidationId].state = LiquidationState.FINISHED;
        token.burn(liquidations[liquidationId].amount);
        emit LiquidationStopped(liquidationId, liquidations[liquidationId].loanId, liquidations[liquidationId].bestBid, liquidations[liquidationId].bestBidder);
        bank.liquidated(
            liquidations[liquidationId].loanId,
            liquidations[liquidationId].bestBid,
            liquidations[liquidationId].bestBidder
        );
    }

    /**
     * @notice palce a bid on the liquidation.
     * @param liquidationId The id of the liquidation.
     */
    function placeBid(uint256 liquidationId, uint256 bidAmount)
        external
        onlyActive(liquidationId)
    {
        require(bidAmount <= liquidations[liquidationId].collateral, INADEQUATE_BIDDING);
        if (liquidations[liquidationId].bestBid != 0){
            require(bidAmount < liquidations[liquidationId].bestBid, INADEQUATE_BIDDING);
        }
        uint256 allowance = token.allowance(msg.sender, address(this));
        if (token.transferFrom(msg.sender, address(this), allowance)) {
            deposits[msg.sender] = deposits[msg.sender].add(allowance);
        }
        require(liquidations[liquidationId].amount <= deposits[msg.sender], INSUFFICIENT_FUNDS);
        deposits[msg.sender] = deposits[msg.sender].sub(liquidations[liquidationId].amount);
        deposits[liquidations[liquidationId].bestBidder] = deposits[liquidations[liquidationId].bestBidder].add(liquidations[liquidationId].amount);
        liquidations[liquidationId].bestBidder = msg.sender;
        liquidations[liquidationId].bestBid = bidAmount;
    }

    /**
     * @dev Throws if state is not equal to needState.
     * @param liquidationId The id of the liquidation.
     * @param needState The state which needed.
     */
    modifier onlyActive(uint256 liquidationId) {
        require(liquidations[liquidationId].state == LiquidationState.ACTIVE, NOT_ACTIVE_LIQUIDATION);
        _;
    }

    /**
     * @dev Throws if the number is equal to zero.
     * @param number The number to validate.
     */
    modifier throwIfEqualToZero(uint number) {
        require(number != 0, INVALID_AMOUNT);
        _;
    }

    /**
     * @dev Throws if called by any account other than our EtherBank smart conrtact.
     */
    modifier onlyEtherBank() {
        require(msg.sender == address(bank), ONLY_ETHER_BANK);
        _;
    }
}
