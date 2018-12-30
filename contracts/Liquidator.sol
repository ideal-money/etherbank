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
        uint256 collateralAmount;
        uint256 loanAmount;
        uint256 startTime;
        uint256 endTime;
        uint256 bestBid;
        address bestBidder;
        LiquidationState state;
    }

    mapping(uint256 => Liquidation) private liquidations;
    mapping(address => uint256) private deposits;

    event StartLiquidation(uint256 indexed liquidationId, uint256 indexed loanId, uint256 collateralAmount, uint256 loanAmount, uint256 startTime, uint256 endTime);
    event StopLiquidation(uint256 indexed liquidationId, uint256 indexed loanId, uint256 bestBid, address bestBidder);
    event Withdraw(address indexed withdrawalAccount, uint256 amount);

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
     * @notice Get amount of the deposit.
     */
    function getDepositAmount()
        external
        view
        returns(uint256)
    {
        return deposits[msg.sender];
    }

    /**
     * @notice Withdraw EtherDollar.
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
     * @param _loanId The id of the loan which is under liquidation.
     * @param _collateralAmount The amount of the loan's collateral.
     * @param _loanAmount The amount of the loan.
     */
    function startLiquidation(
        uint256 _loanId,
        uint256 _collateralAmount,
        uint256 _loanAmount
    )
        external
        onlyEtherBank
        throwIfEqualToZero(_collateralAmount)
        throwIfEqualToZero(_loanAmount)
    {
        uint256 liquidationId = ++lastLiquidationId;
        uint256 startTime = now;
        uint256 endTime = startTime.add(bank.liquidationDuration());
        liquidations[liquidationId].loanId = _loanId;
        liquidations[liquidationId].collateralAmount = _collateralAmount;
        liquidations[liquidationId].loanAmount = _loanAmount;
        liquidations[liquidationId].startTime = startTime;
        liquidations[liquidationId].endTime = endTime;
        liquidations[liquidationId].state = LiquidationState.ACTIVE;
        emit StartLiquidation(liquidationId, _loanId, _collateralAmount, _loanAmount, startTime, endTime);
    }

    /**
     * @notice Stop the liquidation.
     * @param liquidationId The id of the liquidation.
     */
    function stopLiquidation(uint256 liquidationId)
        external
        checkLiquidationState(liquidationId, LiquidationState.ACTIVE)
    {
        require(liquidations[liquidationId].endTime <= now, OPEN_LIQUIDATION);
        require(liquidations[liquidationId].bestBid != 0, NO_BID);
        liquidations[liquidationId].state = LiquidationState.FINISHED;
        token.burn(liquidations[liquidationId].loanAmount);
        emit StopLiquidation(liquidationId, liquidations[liquidationId].loanId, liquidations[liquidationId].bestBid, liquidations[liquidationId].bestBidder);
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
        checkLiquidationState(liquidationId, LiquidationState.ACTIVE)
    {
        require(bidAmount <= liquidations[liquidationId].collateralAmount, INADEQUATE_BIDDING);
        require(liquidations[liquidationId].loanAmount <= token.allowance(msg.sender, address(this)).add(deposits[msg.sender]), INSUFFICIENT_FUNDS);
        if (liquidations[liquidationId].bestBid != 0){
            require(bidAmount < liquidations[liquidationId].bestBid, INADEQUATE_BIDDING);
        }
        uint256 allowance = token.allowance(msg.sender, address(this));
        if (token.transferFrom(msg.sender, address(this), allowance)) {
            deposits[msg.sender] = deposits[msg.sender].add(allowance).sub(liquidations[liquidationId].loanAmount);
            deposits[liquidations[liquidationId].bestBidder] = deposits[liquidations[liquidationId].bestBidder].add(liquidations[liquidationId].loanAmount);
            liquidations[liquidationId].bestBidder = msg.sender;
            liquidations[liquidationId].bestBid = bidAmount;
        }
    }

    /**
     * @notice Get the best bid of the liquidation.
     * @param liquidationId The id of the liquidation.
     */
    function getBestBid(uint256 liquidationId)
        external
        view
        returns(address,uint256)
    {
        return (liquidations[liquidationId].bestBidder, liquidations[liquidationId].bestBid);
    }

    /**
     * @dev Throws if state is not equal to needState.
     * @param liquidationId The id of the liquidation.
     * @param needState The state which needed.
     */
    modifier checkLiquidationState(uint256 liquidationId, LiquidationState needState) {
        require(liquidations[liquidationId].state == needState, NOT_ACTIVE_LIQUIDATION);
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
