pragma solidity ^0.4.22;

import "./openzeppelin/math/SafeMath.sol";
import "./openzeppelin/lifecycle/Pausable.sol";
import "./EtherDollar.sol";
import "./Liquidator.sol";


contract EtherBank is Pausable {

    using SafeMath for uint256;
    EtherDollar public token;
    Liquidator public liquidator;

    uint256 constant public PRECISION_POINT = 10 ** 3;
    uint256 constant public ETHER_TO_WEI = 10 ** 18;

    address public concentratorAdd;
    address public liquidatorAdd;
    uint256 public loanFeeRatio;
    uint64 public lastLoanId;
    uint256 public depositRate;
    uint256 public etherPrice; // cent of EtherDollar
    address public owner;
    uint256 public liquidationDuration; // duration of liquidation in number of blocks.

    enum Types {
        ETHER_PRICE,
        DEPOSIT_RATE,
        LOAN_FEE_RATIO,
        LIQUIDATION_DURATION
    }

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

    event LoanGot(address borrower, uint256 collateralAmount, uint256 amount, uint64 loanId);
    event LoanSettled(address borrower, uint256 collateralAmount, uint256 amount, uint64 loanId);

    constructor()
        public {
            owner = msg.sender;
            concentratorAdd = 0x0;
            loanFeeRatio = 5;
            lastLoanId = 0;
            liquidationDuration = 480; // 480 blocks or 2 hours.
        }

    /**
     * @dev Fallback function.
     */
    function() external payable {
        uint256 amount = msg.value.mul(PRECISION_POINT * etherPrice).div(2 * depositRate * ETHER_TO_WEI);
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
    function setEtherDollar(address _tokenAdd)
        external
        onlyOwner
    {
        require(_tokenAdd != address(0));

        token = EtherDollar(_tokenAdd);
    }

    /**
     * @dev Set oracle address.
     * @param _concentratorAdd The oracle's address.
     */
    function setConcentrator(address _concentratorAdd)
        external
        onlyOwner
    {
        require(_concentratorAdd != address(0));

        concentratorAdd = _concentratorAdd;
    }

    /**
     * @dev Lets Concentrator to set important varibales.
     * @param type Code of the variable.
     * @param value Amount of the variable.
     */
    function setVariable(uint256 type, uint256 value)
        public
        onlyConcentrator
    {
        if (uint(Type.ETHER_PRICE) == type) {
            etherPrice = value;
        } else if (uint(Type.DEPOSIT_RATE) == type) {
            depositRate = value;
        } else if (uint(Type.LOAN_FEE_RATIO) == type) {
            loanFeeRatio = value;
        } else if (uint(Type.LIQUIDATION_DURATION) == type) {
            liquidationDuration = value;
        }
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
        uint64 loanId = ++lastLoanId;
        loans[loanId].debtor = msg.sender;
        loans[loanId].collateralAmount = msg.value.sub(loanFee);
        loans[loanId].amount = amount;
        loans[loanId].state = LoanState.ACTIVE;
        token.mint(msg.sender, amount);
        emit LoanGot(msg.sender, msg.value, amount, loanId);
    }

    /**
     * @dev payback etherDollars.
     * @param amount The etherDollar amount payed back.
     * @param loanId The loan id.
     */
    function settleLoan(uint256 amount, uint64 loanId)
        public
        whenNotPaused
        onlyLoanOwner(loanId)
        throwIfEqualToZero(amount)
    {
        require(amount <= token.allowance(msg.sender, this));
        require(amount <= loans[loanId].amount);
        require(loans[loanId].state == LoanState.ACTIVE);

        token.transferFrom(msg.sender, this, amount);
        uint256 paybackCollateralAmount = (loans[loanId].collateralAmount.mul(amount)).div(loans[loanId].amount);
        token.burn(amount);
        loans[loanId].collateralAmount -= paybackCollateralAmount;
        loans[loanId].amount -= amount;
        if (loans[loanId].amount == 0) {
            loans[loanId].state = LoanState.SETTLED;
        }
        emit LoanSettled(msg.sender, paybackCollateralAmount, amount, loanId);
        msg.sender.transfer(paybackCollateralAmount);
    }

    /**
     * @dev liquidate collateral of the loan.
     * @param loanId The loan id.
     */
    function liquidate(uint64 loanId)
        public
        whenNotPaused
    {
        require((loans[loanId].collateralAmount * etherPrice * PRECISION_POINT) < (loans[loanId].amount * depositRate * ETHER_TO_WEI));
        loans[loanId].state = LoanState.UNDER_LIQUIDATION;
        liquidator.startLiquidation(
            liquidationDuration,
            loanId,
            loans[loanId].collateralAmount,
            loans[loanId].amount
        );
    }

    /**
     * @dev pay winner of auction's ether.
     * @param loanId The loan id.
     * @param amount The bid of winner.
     * @param buyer The winner account.
     */
    function liquidated(uint64 loanId, uint256 amount, address buyer)
        public
        whenNotPaused
        onlyLiquidator
    {
        loans[loanId].state = LoanState.LIQUIDATED;
        loans[loanId].collateralAmount -= amount;
        loans[loanId].amount = 0;
        buyer.transfer(amount);
    }

    /**
     * @dev Throws if called by any account other than our Concentrator.
     */
    modifier onlyConcentrator() {
        require(msg.sender == concentratorAdd);
        _;
    }

    /**
     * @dev Throws if called by any account other than our Liquidator.
     */
    modifier onlyLiquidator() {
        require(msg.sender == liquidatorAdd);
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
        require((msg.value * etherPrice * PRECISION_POINT) >= (loanAmount * depositRate * ETHER_TO_WEI));
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner of the loan.
     * @param loanId The loan id.
     */
    modifier onlyLoanOwner(uint64 loanId) {
        require(loans[loanId].debtor == msg.sender);
        _;
    }
}
