pragma solidity ^0.4.18;

import "./openzeppelin/math/SafeMath.sol";
import "./openzeppelin/lifecycle/Pausable.sol";
import "./token/EtherDollar.sol";

contract ReserveBank is Pausable {
    using SafeMath for uint256;
    EtherDollar token;
    uint256 constant public MIN_DEPOSIT_RATE = 1500; // 1500 = 1.5 * PRECISION_POINT
    uint256 constant public PRECISION_POINT = 1000;
    uint256 constant public ETHER_TO_WEI = 10 ** 18;
    uint256 constant public DOLLAR_TO_CENT = 10 ** 2;

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
    uint64[] private debtors;
    mapping(uint64 => Loan) private loans;
    event Get(address borrower, uint256 collateralAmount, uint256 amount);
    event Settle(address borrower, uint256 collateralAmount, uint256 amount);


    function ReserveBank(address _token)
        public
    {
        token = EtherDollar(_token);
    }


    /**
     * @dev check the loan exists.
     * @param loanId The loan id.
     * @param debtor The debtor's address.
     */
    function isLoanOwner(uint64 loanId, address debtor)
        internal
        constant
        returns(bool)
    {
        if(debtors.length == 0) return false;
        if(debtors.length <= loanId) return false;
        return(loans[loanId].debtor == debtor);
    }


    /**
     * @dev get market ether price in USD.
     */
    function getWeiPrice()
        internal view returns(uint256)
    {
    }


    /**
     * @dev get market etherDollar price in USD.
     */
    function getCentPrice()
        internal view returns(uint256)
    {
    }


    /**
     * @dev multiplication function for fractions.
     * @param number.
     * @param fraction.
     */
    function multiplyFraction(uint number, uint[2] fraction) returns (uint) {
        uint numerator = interestRate[0];
        uint denominator = interestRate[1];
        return (number.mul(numerator)).div(denominator);
    }


    /**
     * @dev deposit ethereum to borrow etherDollar.
     * @param The amount of requsted loan.
     */
    function get(uint256 amount)
        payable
        public
        whenNotPaused
    {
        require(amount != 0);
        uint256 etherPrice = getEtherPrice()
        require((msg.value * etherPrice * DIV_FACTOR * DOLLAR_TO_CENT) >= (amount * MIN_DEPOSIT_RATE * ETHER_TO_WEI));
        token.mint(msg.sender, amount);
        emit Get(msg.sender, msg.value, amount);
        uint64 loanId = debtors.length;
        loans[loanId].debtor = msg.sender;
        loans[loanId].collateralAmount = msg.value;
        loans[loanId].amount = amount;
        loans[loanId].state = DebtState.ACTIVE;
        debtors.push(msg.sender);
    }


    /**
     * @dev payback etherDollars.
     * @param amount The etherDollar amount payed back.
     * @param loanId The loan id.
     */
    function settle(uint256 amount, uint64 loanId)
        public
        whenNotPaused
    {
        require(amount <= token.allowance(loans[loanId].debtor, this));
        require(isLoanOwner(loanId, msg.sender));
        require(loans[loanId].state == LoanState.ACTIVE);
        uint256 paybackAmount = (loans[loanId].collateralAmount.mul(amount)) / loans[loanId].amount;
        token.transferFrom(msg.sender, this, amount);
        token.burn(amount);
        emit PayBack(msg.sender, paybackAmount, amount);
        if(loans[loanId].amount == amount){
            loans[loanId].state = LoanState.SETTLED;
        }
        loans[loanId].collateralAmount -= paybackAmount;
        loans[loanId].amount -= amount;
        msg.sender.transfer(paybackAmount);
    }


    /**
     * @dev Auctioning collateral of the loan.
     * @param The loan id.
     */
    function auction(uint64 loanId)
        public
        whenNotPaused
    {
        loans[loanId].state = LoanState.UNDER_LIQUIDATION;
        //TO_DO
    }


    /**
     * @dev Fallback function.
     */
    function() external payable {
        deposit(2);
    }
}