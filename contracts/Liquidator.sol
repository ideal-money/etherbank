pragma solidity ^0.4.22;

import "./openzeppelin/contracts/lifecycle/Pausable.sol";
import "./EtherDollar.sol";
import "./EtherBank.sol";


/**
 * @title EtherBank's Liquidator contract.
 */
contract Liquidator is Pausable {
    using SafeMath for uint256;

    address public owner;

    EtherDollar internal token;
    EtherBank internal bank;

    address internal etherBankAddr;
    uint256 internal lastLiquidationId;

    enum LiquidationState {
        ACTIVE,
        FINISHED,
        FAILED
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

    string private constant INVALID_ADDRESS = "INVALID_ADDRESS";
    string private constant ONLY_ETHER_BANK = "ONLY_ETHER_BANK";
    string private constant NO_DEPOSIT = "NO_DEPOSIT";
    string private constant INVALID_AMOUNT = "INVALID_AMOUNT";
    string private constant NOT_ACTIVE_LIQUIDATION = "NOT_ACTIVE_LIQUIDATION";
    string private constant OPEN_LIQUIDATION = "OPEN_LIQUIDATION";
    string private constant NO_BID = "NO_BID";
    string private constant INADEQUATE_BIDDING = "INADEQUATE_BIDDING";
    string private constant INSUFFICIENT_FUNDS = "INSUFFICIENT_FUNDS";

    constructor(address _tokenAddr, address _etherBankAddr)
        public {
            owner = msg.sender;
            lastLiquidationId = 0;
            etherBankAddr = _etherBankAddr;
            bank = EtherBank(etherBankAddr);
            token = EtherDollar(_tokenAddr);
        }

    /**
     * @notice Set EtherBank smart contract address.
     * @param _etherBankAddr The EtherBank smart contract address.
     */
    function setEtherBank(address _etherBankAddr)
        external
        onlyOwner
        whenNotPaused
    {
        require(_etherBankAddr != address(0), INVALID_ADDRESS);
        etherBankAddr = _etherBankAddr;
        bank = EtherBank(etherBankAddr);
    }

    /**
     * @notice Set EtherDollar smart contract address.
     * @param _tokenAddr The EtherDollar smart contract address.
     */
    function setEtherDollar(address _tokenAddr)
        external
        onlyOwner
        whenNotPaused
    {
        require(_tokenAddr != address(0), INVALID_ADDRESS);
        token = EtherDollar(_tokenAddr);
    }

    /**
     * @notice Get amount of the deposit.
     */
    function getDepositAmount()
        external
        view
        whenNotPaused
        returns(uint256)
    {
        return deposits[msg.sender];
    }

    /**
     * @notice Withdraw EtherDollar.
     */
    function withdraw()
        external
        whenNotPaused
    {

        require (deposits[msg.sender] > 0, NO_DEPOSIT);
        uint256 amount = deposits[msg.sender];
        deposits[msg.sender] = 0;
        emit Withdraw(msg.sender, amount);
        token.transfer(msg.sender, amount);
    }

    /**
     * @dev Start an liquidation.
     * @param _loanId The id of the loan which is under liquidation.
     * @param _collateralAmount The amount of the loan's collateral.
     * @param _loanAmount The amount of the loan's etherDollar.
     */
    function startLiquidation(
        uint256 _loanId,
        uint256 _collateralAmount,
        uint256 _loanAmount
    )
        external
        whenNotPaused
        onlyEtherBankSC
        throwIfEqualToZero(_collateralAmount)
        throwIfEqualToZero(_loanAmount)
    {
        uint256 startTime = now;
        uint256 endTime = startTime + bank.liquidationDuration();
        uint256 liquidationId = ++lastLiquidationId;
        liquidations[liquidationId].loanId = _loanId;
        liquidations[liquidationId].collateralAmount = _collateralAmount;
        liquidations[liquidationId].loanAmount = _loanAmount;
        liquidations[liquidationId].startTime = startTime;
        liquidations[liquidationId].endTime = endTime;
        liquidations[liquidationId].state = LiquidationState.ACTIVE;
        emit StartLiquidation(liquidationId, _loanId, _collateralAmount, _loanAmount, startTime, endTime);
    }

    /**
     * @notice stop an liquidation.
     * @param liquidationId The id of the liquidation.
     */
    function stopLiquidation(uint256 liquidationId)
        external
        checkLiquidationState(liquidationId, LiquidationState.ACTIVE)
        whenNotPaused
    {
        require(liquidations[liquidationId].endTime <= now, OPEN_LIQUIDATION);
        require(liquidations[liquidationId].bestBid != 0, NO_BID);
        liquidations[liquidationId].state = LiquidationState.FINISHED;
        token.burn(liquidations[liquidationId].loanAmount);
        bank.liquidated(
            liquidations[liquidationId].loanId,
            liquidations[liquidationId].bestBid,
            liquidations[liquidationId].bestBidder
        );
        emit StopLiquidation(liquidationId, liquidations[liquidationId].loanId, liquidations[liquidationId].bestBid, liquidations[liquidationId].bestBidder);
    }

    /**
     * @notice palce a bid on the liquidation.
     * @param liquidationId The id of the liquidation.
     */
    function placeBid(uint256 liquidationId, uint256 bidAmount)
        external
        whenNotPaused
        checkLiquidationState(liquidationId, LiquidationState.ACTIVE)
    {
        require(liquidations[liquidationId].loanAmount <= token.allowance(msg.sender, this), INSUFFICIENT_FUNDS);
        if (liquidations[liquidationId].bestBid != 0){
            require(bidAmount < liquidations[liquidationId].bestBid, INADEQUATE_BIDDING);
        }
        token.transferFrom(msg.sender, this, liquidations[liquidationId].loanAmount);
        deposits[liquidations[liquidationId].bestBidder] += liquidations[liquidationId].loanAmount;
        liquidations[liquidationId].bestBidder = msg.sender;
        liquidations[liquidationId].bestBid = bidAmount;
    }

    /**
     * @notice Get the best bid of the liquidation.
     * @param liquidationId The id of the liquidation.
     */
    function getBestBid(uint256 liquidationId)
        external
        view
        whenNotPaused
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
    modifier onlyEtherBankSC() {
        require(msg.sender == etherBankAddr, ONLY_ETHER_BANK);
        _;
    }
}
