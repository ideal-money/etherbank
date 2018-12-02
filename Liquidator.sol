pragma solidity ^0.4.22;

import "./openzeppelin/contracts/lifecycle/Pausable.sol";
import "./EtherDollar.sol";
import "./EtherBank.sol";


contract Liquidator is Pausable {
    using SafeMath for uint256;

    EtherDollar public token;
    EtherBank public bank;

    address public owner;
    address public EtherBankAdd;
    uint64 public lastLiquidationId;

    enum LiquidationState {
        ACTIVE,
        FINISHED,
        FAILED
    }

    struct Liquidation {
        uint64 loanId;
        uint256 collateralAmount;
        uint256 loanAmount;
        uint256 startBlock;
        uint256 endBlock;
        uint256 bestBid;
        address bestBidder;
        LiquidationState state;
    }

    mapping(uint256 => Liquidation) private liquidations;
    mapping(address => uint256) private deposits;

    event LogStartLiquidation(uint64 liquidationId, uint256 collateralAmount, uint256 loanAmount, uint256 startBlock, uint256 endBlock);
    event LogStopLiquidation(uint64 liquidationId, uint256 bestBid, address bestBidder);
    event LogWithdraw(address withdrawalAccount, uint256 amount);

    string private constant INVALID_ADDRESS = "INVALID_ADDRESS";
    string private constant ONLY_ETHER_BANK = "ONLY_ETHER_BANK";
    string private constant INVALID_AMOUNT = "INVALID_AMOUNT";
    string private constant NOT_ACTIVE_LOAN = "NOT_ACTIVE_LOAN";
    string private constant OPEN_LIQUIDATION = "OPEN_LIQUIDATION";
    string private constant NO_BID = "NO_BID";
    string private constant INADEQUATE_BIDDING = "INADEQUATE_BIDDING";
    string private constant INSUFFICIENT_FUNDS = "INSUFFICIENT_FUNDS";

    constructor()
        public {
            owner = msg.sender;
            EtherBankAdd = 0x0;
            lastLiquidationId = 0;
        }

    /**
     * @dev Set EtherBank smart contract address.
     * @param _EtherBankAdd The EtherBank smart contract address.
     */
    function setEtherBank(address _EtherBankAdd)
        external
        onlyOwner
        whenNotPaused
    {
        require(_EtherBankAdd != address(0), INVALID_ADDRESS);
        EtherBankAdd = _EtherBankAdd;
        bank = EtherBank(EtherBankAdd);
    }

    /**
     * @dev Set EtherDollar smart contract address.
     * @param _tokenAdd The EtherDollar smart contract address.
     */
    function setEtherDollar(address _tokenAdd)
        external
        onlyOwner
        whenNotPaused
    {
        require(_tokenAdd != address(0), INVALID_ADDRESS);
        token = EtherDollar(_tokenAdd);
    }

    /**
     * @dev Get amount of the deposit.
     */
    function getDepositAmount()
        public
        view
        whenNotPaused
        returns(uint256)
    {
        return deposits[msg.sender];
    }

    /**
     * @dev Withdraw EtherDollar.
     * @param amount The deposite amount.
     */
    function withdraw(uint256 amount)
        public
        whenNotPaused
        throwIfEqualToZero(amount)
    {
        require(amount <= deposits[msg.sender], INVALID_AMOUNT);
        deposits[msg.sender] -= amount;
        token.transfer(msg.sender, amount);
        emit LogWithdraw(msg.sender, amount);
    }

    /**
     * @dev Start an liquidation.
     * @param _numberOfBlocks The number of blocks which liquidation should take.
     * @param _loanId The id of the loan which is under liquidation.
     * @param _collateralAmount The amount of the loan's collateral.
     * @param _loanAmount The amount of the loan's etherDollar.
     */
    function startLiquidation(
        uint256 _numberOfBlocks,
        uint64 _loanId,
        uint256 _collateralAmount,
        uint256 _loanAmount
    )
        public
        whenNotPaused
        onlyEtherBankSC
        throwIfEqualToZero(_collateralAmount)
        throwIfEqualToZero(_loanAmount)
        throwIfEqualToZero(_numberOfBlocks)
    {
        uint256 startBlock = block.number;
        uint256 endBlock = startBlock.add(_numberOfBlocks);
        uint64 liquidationId = ++lastLiquidationId;
        liquidations[liquidationId].loanId = _loanId;
        liquidations[liquidationId].collateralAmount = _collateralAmount;
        liquidations[liquidationId].loanAmount = _loanAmount;
        liquidations[liquidationId].startBlock = startBlock;
        liquidations[liquidationId].endBlock = endBlock;
        liquidations[liquidationId].state = LiquidationState.ACTIVE;
        emit LogStartLiquidation(liquidationId, _collateralAmount, _loanAmount, startBlock, endBlock);
    }

    /**
     * @dev stop an liquidation.
     * @param liquidationId The id of the liquidation.
     */
    function stopLiquidation(uint64 liquidationId)
        public
        checkLiquidationState(liquidationId, LiquidationState.ACTIVE)
        whenNotPaused
    {
        require(liquidations[liquidationId].endBlock <= block.number, OPEN_LIQUIDATION);
        require(liquidations[liquidationId].bestBid != 0, NO_BID);
        liquidations[liquidationId].state = LiquidationState.FINISHED;
        token.burn(liquidations[liquidationId].loanAmount);
        bank.liquidated(
            liquidations[liquidationId].loanId,
            liquidations[liquidationId].bestBid,
            liquidations[liquidationId].bestBidder
        );
        emit LogStopLiquidation(liquidationId, liquidations[liquidationId].bestBid, liquidations[liquidationId].bestBidder);
    }

    /**
     * @dev palce a bid on the liquidation.
     * @param liquidationId The id of the liquidation.
     */
    function placeBid(uint64 liquidationId, uint256 bidAmount)
        public
        whenNotPaused
        checkLiquidationState(liquidationId, LiquidationState.ACTIVE)
    {
        require(liquidations[liquidationId].loanAmount <= token.allowance(msg.sender, this), INSUFFICIENT_FUNDS);
        require(bidAmount < liquidations[liquidationId].bestBid, INADEQUATE_BIDDING);
        token.transferFrom(msg.sender, this, liquidations[liquidationId].loanAmount);
        deposits[msg.sender] += liquidations[liquidationId].loanAmount;
        deposits[liquidations[liquidationId].bestBidder] += liquidations[liquidationId].loanAmount;
        deposits[msg.sender] -= liquidations[liquidationId].loanAmount;
        liquidations[liquidationId].bestBidder = msg.sender;
        liquidations[liquidationId].bestBid = bidAmount;
    }

    /**
     * @dev Get the best bid of the liquidation.
     * @param liquidationId The id of the liquidation.
     */
    function getBestBid(uint64 liquidationId)
        public
        view
        whenNotPaused
        checkLiquidationState(liquidationId, LiquidationState.ACTIVE)
        returns(uint256)
    {
        return liquidations[liquidationId].bestBid;
    }

    /**
     * @dev Throws if state is not equal to needState.
     * @param liquidationId The id of the liquidation.
     * @param needState The state which needed.
     */
    modifier checkLiquidationState(uint64 liquidationId, LiquidationState needState) {
        require(liquidations[liquidationId].state == needState, NOT_ACTIVE_LOAN);
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
        require(msg.sender == EtherBankAdd, ONLY_ETHER_BANK);
        _;
    }
}
