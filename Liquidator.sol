pragma solidity ^0.4.22;

import "./openzeppelin/lifecycle/Pausable.sol";
import "./token/EtherDollar.sol";
import "./ReserveBank.sol";


contract Liquidator is Pausable {
    using SafeMath for uint256;
    EtherDollar public token;
    ReserveBank public bank;

    address public owner;
    address public reserveBankAdd;
    address public etherDollarAdd;
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
    event LogDeposit(address depositorAccount, uint256 amount);
    event LogWithdraw(address withdrawalAccount, uint256 amount);

    constructor()
        public {
            owner = msg.sender;
            reserveBankAdd = 0x0;
            etherDollarAdd = 0x0;
            lastLiquidationId = 0;
        }

    /**
     * @dev Set ReserveBank smart contract address.
     * @param _reserveBankAdd The ReserveBank smart contract address.
     */
    function setReserveBank(address _reserveBankAdd)
        external
        onlyOwner
        whenNotPaused
    {
        require(_reserveBankAdd != address(0));
        reserveBankAdd = _reserveBankAdd;
        bank = ReserveBank(reserveBankAdd);
    }

    /**
     * @dev Set EtherDollar smart contract address.
     * @param _etherDollarAdd The EtherDollar smart contract address.
     */
    function setEtherDollar(address _etherDollarAdd)
        external
        onlyOwner
        whenNotPaused
    {
        require(_etherDollarAdd != address(0));
        etherDollarAdd = _etherDollarAdd;
        token = EtherDollar(etherDollarAdd);
    }

    /**
     * @dev Deposit EtherDollar.
     * @param depositor The address which deposite EtherDollar.
     * @param amount The deposite amount.
     */
    function deposit(address depositor, uint256 amount)
        public
        onlyEtherDollarSC
        whenNotPaused
        throwIfEqualToZero(amount)
    {
        deposits[depositor] += amount;
        emit LogDeposit(depositor, amount);
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
        require(amount <= deposits[msg.sender]);
        deposits[msg.sender] -= amount;
        token.transferFrom(this, msg.sender, amount); //??????
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
        onlyReserveBankSC
        throwIfEqualToZero(_collateralAmount)
        throwIfEqualToZero(_loanAmount)
        throwIfEqualToZero(_numberOfBlocks)
    {
        uint256 startBlock = block.number;
        uint256 endBlock = startBlock.add(_numberOfBlocks);
        lastLiquidationId++;
        liquidations[lastLiquidationId].loanId = _loanId;
        liquidations[lastLiquidationId].collateralAmount = _collateralAmount;
        liquidations[lastLiquidationId].loanAmount = _loanAmount;
        liquidations[lastLiquidationId].startBlock = startBlock;
        liquidations[lastLiquidationId].endBlock = endBlock;
        liquidations[lastLiquidationId].state = LiquidationState.ACTIVE;
        emit LogStartLiquidation(lastLiquidationId, _collateralAmount, _loanAmount, startBlock, endBlock);
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
        require(liquidations[liquidationId].endBlock <= block.number);
        require(liquidations[liquidationId].bestBid != 0);
        liquidations[liquidationId].state = LiquidationState.FINISHED;
        token.burn(liquidations[liquidationId].loanAmount);
        bank.payBestBidderEther(
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
        require(deposits[msg.sender] >= liquidations[liquidationId].loanAmount);
        require(bidAmount < liquidations[liquidationId].bestBid);
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
     * @dev Throws if called by any account other than owner.
     */
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Throws if state is not equal to needState.
     * @param liquidationId The id of the liquidation.
     * @param needState The state which needed.
     */
    modifier checkLiquidationState(uint64 liquidationId, LiquidationState needState) {
        require(liquidations[liquidationId].state == needState);
        _;
    }

    /**
     * @dev Throws if the number is equal to zero.
     * @param number The number to validate.
     */
    modifier throwIfEqualToZero(uint number) {
        require(number != 0);
        _;
    }

    /**
     * @dev Throws if called by any account other than our EtherDollar smart conrtact.
     */
    modifier onlyEtherDollarSC() {
        require(msg.sender == etherDollarAdd);
        _;
    }

    /**
     * @dev Throws if called by any account other than our ReserveBank smart conrtact.
     */
    modifier onlyReserveBankSC() {
        require(msg.sender == reserveBankAdd);
        _;
    }
}
