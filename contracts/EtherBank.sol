pragma solidity ^0.4.24;

import "./openzeppelin/contracts/math/SafeMath.sol";
import "./EtherDollar.sol";
import "./Liquidator.sol";


/**
 * @title EtherBank contract.
 */
contract EtherBank {
    using SafeMath for uint256;

    uint256 public lastLoanId;

    uint256 public etherPrice;
    uint256 public depositRate;
    uint256 public liquidationDuration;

    address public oracleAddr;
    address public liquidatorAddr;
    address public etherDollarAddr;

    EtherDollar internal token;
    Liquidator internal liquidator;

    uint256 constant internal PRECISION_POINT = 10 ** 3;
    uint256 constant internal ETHER_TO_WEI = 10 ** 18;

    enum Types {
        ETHER_PRICE,
        DEPOSIT_RATE,
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

    mapping(uint256 => Loan) private loans;

    event LoanGot(address indexed borrower, uint256 indexed loanId, uint256 collateralAmount, uint256 amount);
    event IncreasedCollatral(address indexed borrower, uint256 indexed loanId, uint256 collateralAmount);
    event LoanSettled(address borrower, uint256 indexed loanId, uint256 collateralAmount, uint256 amount);

    string private constant INVALID_ADDRESS = "INVALID_ADDRESS";
    string private constant INVALID_AMOUNT = "INVALID_AMOUNT";
    string private constant INITIALIZED_BEFORE = "INITIALIZED_BEFORE";
    string private constant SUFFICIENT_COLLATERAL = "SUFFICIENT_COLLATERAL";
    string private constant INSUFFICIENT_COLLATERAL = "INSUFFICIENT_COLLATERAL";
    string private constant INSUFFICIENT_ALLOWANCE = "INSUFFICIENT_ALLOWANCE";
    string private constant ONLY_LOAN_OWNER = "ONLY_LOAN_OWNER";
    string private constant ONLY_LIQUIDATOR = "ONLY_LIQUIDATOR";
    string private constant ONLY_ORACLES = "ONLY_ORACLE";
    string private constant INVALID_LOAN_STATE = "INVALID_LOAN_STATE";
    string private constant EXCEEDED_MAX_LOAN = "EXCEEDED_MAX_LOAN";

    constructor(address _tokenAdd)
        public
    {
        token = EtherDollar(_tokenAdd);
        etherDollarAddr = _tokenAdd;
        depositRate = 1500; // = 1.5 * PRECISION_POINT
        liquidationDuration = 7200; // = 2 hours
    }

    /**
     * @dev Fallback function.
     */
    function() external
      payable
    {
        if (msg.value > 0) {
            uint256 amount = msg.value.mul(PRECISION_POINT).mul(etherPrice).div(depositRate).div(ETHER_TO_WEI).div(2);
            getLoan(amount);
        }
    }

    /**
     * @notice Set Liquidator contract.
     * @param _liquidatorAddr The Liquidator's contract address.
     */
    function setLiquidator(address _liquidatorAddr)
        external
    {
        require(_liquidatorAddr != address(0), INVALID_ADDRESS);
        require (liquidatorAddr == address(0), INITIALIZED_BEFORE);

        liquidatorAddr = _liquidatorAddr;
        liquidator = Liquidator(_liquidatorAddr);
    }

    /**
     * @notice Set oracle address.
     * @param _oracleAddr The oracle's contract address.
     */
    function setOracle(address _oracleAddr)
        external
    {
        require(_oracleAddr != address(0), INVALID_ADDRESS);
        require (oracleAddr == address(0), INITIALIZED_BEFORE);

        oracleAddr = _oracleAddr;
    }

    /**
     * @notice Set important varibales by oracles.
     * @param _type Code of the variable.
     * @param value Amount of the variable.
     */
    function setVariable(uint256 _type, uint256 value)
        external
        onlyOracles
        throwIfEqualToZero(value)
    {
        if (uint(Types.ETHER_PRICE) == _type) {
            etherPrice = value;
        } else if (uint(Types.DEPOSIT_RATE) == _type) {
            depositRate = value;
        } else if (uint(Types.LIQUIDATION_DURATION) == _type) {
            liquidationDuration = value;
        }
    }

    /**
     * @notice Deposit ether to borrow etherDollar.
     * @param amount The amount of requsted loan in etherDollar.
     */
    function getLoan(uint256 amount)
        public
        payable
        throwIfEqualToZero(amount)
        throwIfEqualToZero(msg.value)
    {
        require (amount <= 1000000, EXCEEDED_MAX_LOAN);
        require (minCollateral(amount) <= msg.value, INSUFFICIENT_COLLATERAL);
        uint256 loanId = ++lastLoanId;
        loans[loanId].debtor = msg.sender;
        loans[loanId].collateralAmount = msg.value;
        loans[loanId].amount = amount;
        loans[loanId].state = LoanState.ACTIVE;
        emit LoanGot(msg.sender, loanId, msg.value, amount);
        token.mint(msg.sender, amount);
    }

    /**
     * @notice Increase the loan's collatral.
     * @param loanId The loan id.
     */
    function increaseCollatral(uint256 loanId)
        external
        payable
        checkLoanState(loanId, LoanState.ACTIVE)
    {
        require(msg.value > 0, INSUFFICIENT_COLLATERAL);
        loans[loanId].collateralAmount = loans[loanId].collateralAmount.add(msg.value);
        emit IncreasedCollatral(msg.sender, loanId, msg.value);
    }

    /**
     * @notice payback etherDollars to settle the loan.
     * @param amount The etherDollar amount payed back.
     * @param loanId The loan id.
     */
    function settleLoan(uint256 amount, uint256 loanId)
        external
        checkLoanState(loanId, LoanState.ACTIVE)
        throwIfEqualToZero(amount)
    {
        require(amount <= token.allowance(msg.sender, address(this)), INSUFFICIENT_ALLOWANCE);
        require(amount <= loans[loanId].amount, INVALID_AMOUNT);
        uint256 paybackCollateralAmount = loans[loanId].collateralAmount.mul(amount).div(loans[loanId].amount);
        if (token.transferFrom(msg.sender, address(this), amount)) {
            token.burn(amount);
            loans[loanId].collateralAmount = loans[loanId].collateralAmount.sub(paybackCollateralAmount);
            loans[loanId].amount = loans[loanId].amount.sub(amount);
            if (loans[loanId].amount == 0) {
                loans[loanId].state = LoanState.SETTLED;
            }
            emit LoanSettled(loans[loanId].debtor, loanId, paybackCollateralAmount, amount);
            loans[loanId].debtor.transfer(paybackCollateralAmount);
        }
    }

    /**
     * @notice Liquidate collateral of the loan.
     * @param loanId The loan id.
     */
    function liquidate(uint256 loanId)
        external
        checkLoanState(loanId, LoanState.ACTIVE)
    {
        require (minCollateral(loans[loanId].amount) > loans[loanId].collateralAmount, SUFFICIENT_COLLATERAL);
        loans[loanId].state = LoanState.UNDER_LIQUIDATION;
        liquidator.startLiquidation(
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
    function liquidated(uint256 loanId, uint256 amount, address buyer)
        external
        onlyLiquidator
        checkLoanState(loanId, LoanState.UNDER_LIQUIDATION)
    {
        require (amount <= loans[loanId].collateralAmount, INVALID_AMOUNT);
        loans[loanId].state = LoanState.LIQUIDATED;
        loans[loanId].collateralAmount = loans[loanId].collateralAmount.sub(amount);
        loans[loanId].amount = 0;
        buyer.transfer(amount);
    }

    /**
     * @dev Pay back extera collateral.
     * @param loanId The loan id.
     * @param amount The amout of extera colatral.
     */
    function withdraw(uint256 loanId, uint256 amount)
        external
        onlyLoanOwner(loanId)
    {
        require(loans[loanId].state != LoanState.UNDER_LIQUIDATION, INVALID_LOAN_STATE);
        require(minCollateral(loans[loanId].amount) <= loans[loanId].collateralAmount.sub(amount), INSUFFICIENT_COLLATERAL);
        loans[loanId].collateralAmount = loans[loanId].collateralAmount.sub(amount);
        loans[loanId].debtor.transfer(amount);
    }

    /**
     * @notice Count minimum wei which is require to borrow `loan` ether dollar.
     * @param loan The amount of loan in cent.
     */
    function minCollateral(uint256 loan)
        public
        view
        returns (uint256)
    {
        uint256 min = loan.mul(depositRate).mul(ETHER_TO_WEI).div(PRECISION_POINT).div(etherPrice);
        return min;
    }

    /**
     * @dev Throws if called by any account other than our Oracle.
     */
    modifier onlyOracles() {
        require(msg.sender == oracleAddr, ONLY_ORACLES);
        _;
    }

    /**
     * @dev Throws if called by any account other than our Liquidator.
     */
    modifier onlyLiquidator() {
        require(msg.sender == liquidatorAddr, ONLY_LIQUIDATOR);
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
     * @dev Throws if called by any account other than the owner of the loan.
     * @param loanId The loan id.
     */
    modifier onlyLoanOwner(uint256 loanId) {
        require(loans[loanId].debtor == msg.sender, ONLY_LOAN_OWNER);
        _;
    }

    /**
     * @dev Throws if state is not equal to needState.
     * @param loanId The id of the loan.
     * @param needState The state which needed.
     */
    modifier checkLoanState(uint256 loanId, LoanState needState) {
        require(loans[loanId].state == needState, INVALID_LOAN_STATE);
        _;
    }
}
