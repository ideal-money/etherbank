pragma solidity ^0.4.22;

import "./openzeppelin/contracts/math/SafeMath.sol";
import "./openzeppelin/contracts/lifecycle/Pausable.sol";
import "./EtherDollar.sol";
import "./Liquidator.sol";


/**
 * @title EtherBank contract.
 */
contract EtherBank is Pausable {
    using SafeMath for uint256;

    address public owner;

    address public oracleAddr;
    address public liquidatorAddr;
    address public etherDollarAddr;

    uint256 public lastLoanId;

    uint256 public etherPrice; // cent
    uint256 public depositRate;
    uint256 public liquidationDuration; // duration of liquidation in Seconds

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
    event IncreaseCollatral(address indexed borrower, uint256 indexed loanId, uint256 collateralAmount);
    event LoanSettled(address borrower, uint256 indexed loanId, uint256 collateralAmount, uint256 amount);

    string private constant INVALID_ADDRESS = "INVALID_ADDRESS";
    string private constant ONLY_ORACLES = "ONLY_ORACLE";
    string private constant INVALID_AMOUNT = "INVALID_AMOUNT";
    string private constant COLLATERAL_NOT_ENOUGH = "COLLATERAL_NOT_ENOUGH";
    string private constant ONLY_LOAN_OWNER = "ONLY_LOAN_OWNER";
    string private constant NOT_ENOUGH_ALLOWANCE = "NOT_ENOUGH_ALLOWANCE";
    string private constant NOT_ACTIVE_LOAN = "NOT_ACTIVE_LOAN";
    string private constant ENOUGH_COLLATERAL = "ENOUGH_COLLATERAL";
    string private constant ONLY_LIQUIDATOR = "ONLY_LIQUIDATOR";

    constructor(address _tokenAdd)
        public {
            token = EtherDollar(_tokenAdd);
            owner = msg.sender;
            etherPrice = 0; // IN Cent
            depositRate = 1500; // = 1.5
            lastLoanId = 0;
            liquidationDuration = 7200; // IN Seconds
        }

    /**
     * @dev Fallback function.
     */
    function() external payable {
        uint256 amount = msg.value.mul(PRECISION_POINT * etherPrice).div(2 * depositRate * ETHER_TO_WEI);
        getLoan(amount);
    }

    /**
     * @notice Set Liquidator smart contract.
     * @param _liquidatorAddr The Liquidator smart contract address.
     */
    function setLiquidator(address _liquidatorAddr)
        external
        onlyOwner
    {
        require(_liquidatorAddr != address(0), INVALID_ADDRESS);

        liquidatorAddr = _liquidatorAddr;
        liquidator = Liquidator(liquidatorAddr);
    }

    /**
     * @notice Set EtherDollar smart contract address.
     * @param _tokenAdd The EtherDollar smart contract address.
     */
    function setEtherDollar(address _tokenAdd)
        external
        onlyOwner
    {
        require(_tokenAdd != address(0), INVALID_ADDRESS);

        token = EtherDollar(_tokenAdd);
    }

    /**
     * @notice Set oracle address.
     * @param _oracleAddr The oracle's address.
     */
    function setOracle(address _oracleAddr)
        external
        onlyOwner
    {
        require(_oracleAddr != address(0), INVALID_ADDRESS);

        oracleAddr = _oracleAddr;
    }

    /**
     * @notice Lets Oracle to set important varibales.
     * @param _type Code of the variable.
     * @param value Amount of the variable.
     */
    function setVariable(uint256 _type, uint256 value)
        external
        onlyOracles
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
     * @notice deposit ethereum to borrow etherDollar.
     * @param amount The amount of requsted loan.
     */
    function getLoan(uint256 amount)
        public
        payable
        whenNotPaused
        throwIfEqualToZero(amount)
        enoughCollateral(amount)
    {
        uint256 weis_per_cent = ETHER_TO_WEI.div(etherPrice);
        uint256 loanId = ++lastLoanId;
        loans[loanId].debtor = msg.sender;
        loans[loanId].collateralAmount = msg.value;
        loans[loanId].amount = amount;
        loans[loanId].state = LoanState.ACTIVE;
        emit LoanGot(msg.sender, loanId, msg.value, amount);
        token.mint(msg.sender, amount);
    }

    /**
     * @notice increase the loan's collatral.
     * @param loanId The loan id.
     */
    function increaseCollatral(uint256 loanId)
        external
        payable
        whenNotPaused
        onlyLoanOwner(loanId)
    {
        require(msg.value > 0, COLLATERAL_NOT_ENOUGH);
        require(loans[loanId].state == LoanState.ACTIVE, NOT_ACTIVE_LOAN);
        loans[loanId].collateralAmount.add(msg.value);
		emit IncreaseCollatral(msg.sender, loanId, msg.value);
    }

    /**
     * @notice payback etherDollars.
     * @param amount The etherDollar amount payed back.
     * @param loanId The loan id.
     */
    function settleLoan(uint256 amount, uint256 loanId)
        external
        whenNotPaused
        onlyLoanOwner(loanId)
        throwIfEqualToZero(amount)
    {
        require(amount <= token.allowance(msg.sender, this), NOT_ENOUGH_ALLOWANCE);
        require(amount <= loans[loanId].amount, INVALID_AMOUNT);
        require(loans[loanId].state == LoanState.ACTIVE, NOT_ACTIVE_LOAN);
        uint256 paybackCollateralAmount = loans[loanId].collateralAmount.mul(amount).div(loans[loanId].amount);
        if (token.transferFrom(msg.sender, this, amount)) {
            token.burn(amount);
            loans[loanId].collateralAmount -= paybackCollateralAmount;
            loans[loanId].amount -= amount;
            if (loans[loanId].amount == 0) {
                loans[loanId].state = LoanState.SETTLED;
            }
            emit LoanSettled(msg.sender, loanId, paybackCollateralAmount, amount);
            msg.sender.transfer(paybackCollateralAmount);
        }
    }

    /**
     * @notice liquidate collateral of the loan.
     * @param loanId The loan id.
     */
    function liquidate(uint256 loanId)
        external
        whenNotPaused
    {
        require((loans[loanId].collateralAmount * etherPrice * PRECISION_POINT) < (loans[loanId].amount * depositRate * ETHER_TO_WEI), ENOUGH_COLLATERAL);
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
        whenNotPaused
        onlyLiquidator
    {
        loans[loanId].state = LoanState.LIQUIDATED;
        loans[loanId].collateralAmount -= amount;
        loans[loanId].amount = 0;
        buyer.transfer(amount);
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
     * @dev Throws if the collateral is not enough for requested loan.
     * @param loanAmount The amount of requsted loan.
     */
    modifier enoughCollateral(uint256 loanAmount) {
        require((msg.value * etherPrice * PRECISION_POINT) >= (loanAmount * depositRate * ETHER_TO_WEI), COLLATERAL_NOT_ENOUGH);
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
}
