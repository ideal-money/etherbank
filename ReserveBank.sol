pragma solidity ^0.4.22;

import "./openzeppelin/math/SafeMath.sol";
import "./openzeppelin/lifecycle/Pausable.sol";
import "./token/EtherDollar.sol";
import "./Liquidator.sol";


contract ReserveBank is Pausable {

    using SafeMath for uint256;
    EtherDollar public token;
    Liquidator public liquidator;

    uint256 constant public MIN_DEPOSIT_RATE = 1500; // 1.5 * PRECISION_POINT
    uint256 constant public PRECISION_POINT = 10 ** 3;
    uint256 constant public ETHER_TO_WEI = 10 ** 18;
    uint256 constant public DOLLAR_TO_CENT = 10 ** 2;
    uint256 constant public MIN_LOAN_FEE_RATION = 1; // 0.001 * PRECISION_POINT or 0.1%
    uint256 constant public MAX_LOAN_FEE_RATION = 10; // 0.01 * PRECISION_POINT or 1%

    address public ourOracle;
    address public liquidatorAdd;
    address public etherDollarAdd;
    uint256 public loanFeeRatio;
    uint64 public lastLoanId;
    uint256 public depositRate;
    uint256 public etherPrice;
    uint256 public etherDollarPrice;
    address public owner;
    uint256 public numberOfBlocks;

    enum LoanState {
        ACTIVE,
        UNDER_LIQUIDATION,
        LIQUIDATED,
        SETTLED
    }

    struct Loan {
        address debtor;
        uint256 collateralAmount;
        uint256 amount;
        LoanState state;
    }

    mapping(uint64 => Loan) private loans;

    event LogGet(address borrower, uint256 collateralAmount, uint256 amount, uint64 loanId);
    event LogSettle(address borrower, uint256 collateralAmount, uint256 amount, uint64 loanId);

    constructor()
        public {
            owner = msg.sender;
            ourOracle = 0x0;
            loanFeeRatio = 5;
            lastLoanId = 0;
            numberOfBlocks = 480; // 480 blocks or 2 hours.
        }

    /**
     * @dev Fallback function.
     */
    function() external payable {
        uint256 amount = msg.value.mul(PRECISION_POINT).div(depositRate);
        getLoan(amount);
    }

    /**
     * @dev Set Liquidator smart contract.
     * @param _liquidatorAdd The Liquidator smart contract address.
     */
    function setLiquidator(address _liquidatorAdd)
        external
        onlyOwner
    {
        require(_liquidatorAdd != address(0));

        liquidatorAdd = _liquidatorAdd;
        liquidator = Liquidator(liquidatorAdd);
    }

    /**
     * @dev Set EtherDollar smart contract address.
     * @param _etherDollarAdd The EtherDollar smart contract address.
     */
    function setEtherDollar(address _etherDollarAdd)
        external
        onlyOwner
    {
        require(_etherDollarAdd != address(0));

        etherDollarAdd = _etherDollarAdd;
        token = EtherDollar(etherDollarAdd);
    }

    /**
     * @dev Set oracle address.
     * @param _oracleAddress The oracle's address.
     */
    function setOracle(address _oracleAddress)
        external
        onlyOwner
    {
        require(_oracleAddress != address(0));

        ourOracle = _oracleAddress;
    }

    /**
     * @dev Lets owner to set loan fee.
     * @param _loanFeeRatio The fee of loans.
     */
    function setLoanFeeRatio(uint256 _loanFeeRatio)
        external
        onlyOwner
    {
        require(MIN_LOAN_FEE_RATION <= _loanFeeRatio && _loanFeeRatio <= MAX_LOAN_FEE_RATION);

        loanFeeRatio = _loanFeeRatio;
    }

    /**
     * @dev Lets oracle to set important varibales.
     * @param _depositRate The collateral:loan ratio.
     * @param _etherPrice The price of ether in the market.
     * @param _etherDollarPrice The price of etherDollar in the market.
     */
    function setVariables(uint256 _depositRate, uint256 _etherPrice, uint256 _etherDollarPrice)
        public
        onlyOurOracle
        throwIfEqualToZero(_etherPrice)
        throwIfEqualToZero(_etherDollarPrice)
    {
        require(_depositRate >= MIN_DEPOSIT_RATE);

        depositRate = _depositRate;
        etherPrice = _etherPrice;
        etherDollarPrice = _etherDollarPrice;
        numberOfBlocks = _numberOfBlocks;
    }

    /**
     * @dev deposit ethereum to borrow etherDollar.
     * @param amount The amount of requsted loan.
     */
    function getLoan(uint256 amount)
        public
        payable
        whenNotPaused
        throwIfEqualToZero(amount)
        enoughCollateral(amount)
    {
        uint loanFee = msg.value.mul(loanFeeRatio).div(PRECISION_POINT);
        uint64 loanId = lastLoanId + 1;
        loans[loanId].debtor = msg.sender;
        loans[loanId].collateralAmount = msg.value.sub(loanFee);
        loans[loanId].amount = amount;
        loans[loanId].state = LoanState.ACTIVE;
        lastLoanId++;
        token.mint(msg.sender, amount);
        emit LogGet(msg.sender, msg.value, amount, loanId);
    }

    /**
     * @dev payback etherDollars.
     * @param amount The etherDollar amount payed back.
     * @param loanId The loan id.
     */
    function settleLoan(uint256 amount, uint64 loanId)
        public
        whenNotPaused
        isLoanOwner(loanId)
        throwIfEqualToZero(amount)
    {
        require(amount <= token.allowance(loans[loanId].debtor, this));
        require(amount <= loans[loanId].amount);
        require(loans[loanId].state == LoanState.ACTIVE);

        uint256 paybackAmount = (loans[loanId].collateralAmount.mul(amount)).div(loans[loanId].amount);
        token.transferFrom(msg.sender, this, amount);
        token.burn(amount);
        if (loans[loanId].amount == amount)
            loans[loanId].state = LoanState.SETTLED;

        loans[loanId].collateralAmount -= paybackAmount;
        loans[loanId].amount -= amount;
        emit LogSettle(msg.sender, paybackAmount, amount, loanId);
        msg.sender.transfer(paybackAmount);
    }

    /**
     * @dev liquidate collateral of the loan.
     * @param loanId The loan id.
     */
    function callStartLiquidation(uint64 loanId)
        public
        whenNotPaused
    {
        loans[loanId].state = LoanState.UNDER_LIQUIDATION;
        liquidator.startLiquidation(
            numberOfBlocks,
            loanId,
            loans[loanId].collateralAmount,
            loans[loanId].amount
        );
    }

    /**
     * @dev pay winner of auction's ether.
     * @param loanId The loan id.
     * @param bestBid The bid of winner.
     * @param bestBidder The winner account.
     */
    function payBestBidderEther(uint64 loanId, uint256 bestBid, address bestBidder)
        public
        whenNotPaused
    {
        loans[loanId].state = LoanState.LIQUIDATED;
        loans[loanId].collateralAmount -= bestBid;
        loans[loanId].amount = 0;
        bestBidder.transfer(bestBid);
    }

    /**
     * @dev Throws if called by any account other than our oracle.
     */
    modifier onlyOurOracle() {
        require(msg.sender == ourOracle);
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
     * @dev Throws if the collateral is not enough for requested loan.
     * @param loanAmount The amount of requsted loan.
     */
    modifier enoughCollateral(uint256 loanAmount) {
        require((msg.value * etherPrice * PRECISION_POINT * DOLLAR_TO_CENT) >= (loanAmount * depositRate * ETHER_TO_WEI));
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner of the loan.
     * @param loanId The loan id.
     */
    modifier isLoanOwner(uint64 loanId) {
        require(loans[loanId].debtor == msg.sender);
        _;
    }

}
