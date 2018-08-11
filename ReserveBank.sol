pragma solidity ^0.4.18;

import "./openzeppelin/math/SafeMath.sol";
import "./openzeppelin/lifecycle/Pausable.sol";
import "./token/EtherDollar.sol";

contract ReserveBank is Pausable {

    using SafeMath for uint256;
    EtherDollar token;

    uint256 constant public MIN_DEPOSIT_RATE = 1500; // 1.5 * PRECISION_POINT
    uint256 constant public PRECISION_POINT = 10 ** 3;
    uint256 constant public ETHER_TO_WEI = 10 ** 18;
    uint256 constant public DOLLAR_TO_CENT = 10 ** 2;
    uint256 constant public MIN_LOAN_FEE_RATION = 1; // 0.001 * PRECISION_POINT or 0.1%
    uint256 constant public MAX_LOAN_FEE_RATION = 10; // 0.01 * PRECISION_POINT or 1%

    address public our_oracle;
    uint256 public loan_fee_ratio;

    uint256 public deposit_rate;
    uint256 public ether_price;
    uint256 public etherDollar_price;
    address public owner;

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

    uint64 private LAST_LOAN_ID = 0;
    mapping(uint64 => Loan) private loans;

    event Get(address borrower, uint256 collateralAmount, uint256 amount);
    event Settle(address borrower, uint256 collateralAmount, uint256 amount);


    function ReserveBank(address _token)
        public
    {
        token = EtherDollar(_token);
        owner = msg.sender;
        our_oracle = 0xe8fb09228d1373f931007ca7894a08344b80901c;
        loan_fee_ratio = 5;
    }


	/**
	* @dev Throws if called by any account other than the owner.
	*/
	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
	}


    /**
     * @dev Set oracle address.
     * @param _oracle_address The oracle's address.
     */
    function setOracle(address _oracle_address)
        external onlyOwner
    {
        require (_oracle_address != address(0));
        our_oracle = _oracle_address;
    }


    /**
     * @dev Set loan fee.
     * @param _loan_fee_ratio The fee of loans.
     */
    function setLoanFeeRatio(uint256 _loan_fee_ratio)
        external onlyOwner
    {
        require(MIN_LOAN_FEE_RATION <= _loan_fee_ratio && _loan_fee_ratio <= MAX_LOAN_FEE_RATION);
        loan_fee_ratio = _loan_fee_ratio;
    }


    /**
     * @dev Set important varibales.
     * @param _deposit_rate Collateral:loan ratio.
     * @param _ether_price The price of ether in the market.
     * @param _etherDollar_price The price of etherDollar in the market.
     */
    function setVariables(uint256 _deposit_rate, uint256 _ether_price, uint256 _etherDollar_price)
        external
    {
        require (msg.sender == our_oracle);
        require (_deposit_rate.mul(PRECISION_POINT) >= MIN_DEPOSIT_RATE);
        require (_ether_price != 0 && _etherDollar_price != 0);
        deposit_rate = _deposit_rate.mul(PRECISION_POINT);
        ether_price = _ether_price;
        etherDollar_price = _etherDollar_price;
    }


    /**
     * @dev Check the loan exists.
     * @param loanId The loan id.
     * @param debtor The debtor's address.
     */
    function isLoanOwner(uint64 loanId, address debtor)
        internal
        constant
        returns(bool)
    {
    	if (LAST_LOAN_ID == 0 || loanId > LAST_LOAN_ID) return false;
        return(loans[loanId].debtor == debtor);
    }


    /**
     * @dev deposit ethereum to borrow etherDollar.
     * @param amount The amount of requsted loan.
     */
    function get(uint256 amount)
        payable
        public
        whenNotPaused
    {
        require(amount != 0);
        require((msg.value * ether_price * PRECISION_POINT * DOLLAR_TO_CENT) >= (amount * deposit_rate * ETHER_TO_WEI));
        token.mint(msg.sender, amount);
		uint loan_fee = msg.value.mul(loan_fee_ratio).div(PRECISION_POINT);
		this.transfer(loan_fee);
        emit Get(msg.sender, msg.value, amount);
        uint64 loanId = LAST_LOAN_ID + 1;
        loans[loanId].debtor = msg.sender;
        loans[loanId].collateralAmount = msg.value.sub(loan_fee);
        loans[loanId].amount = amount;
        loans[loanId].state = LoanState.ACTIVE;
        LAST_LOAN_ID++;
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
        require (amount <= loans[loanId].amount);
        require(isLoanOwner(loanId, msg.sender));
        require(loans[loanId].state == LoanState.ACTIVE);
        uint256 paybackAmount = (loans[loanId].collateralAmount.mul(amount)) / loans[loanId].amount;
        token.transferFrom(msg.sender, this, amount);
        token.burn(amount);
        emit Settle(msg.sender, paybackAmount, amount);
        if(loans[loanId].amount == amount){
            loans[loanId].state = LoanState.SETTLED;
        }
        loans[loanId].collateralAmount -= paybackAmount;
        loans[loanId].amount -= amount;
        msg.sender.transfer(paybackAmount);
    }


    /**
     * @dev Auctioning collateral of the loan.
     * @param loanId The loan id.
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
    	uint256 amount = msg.value.mul(PRECISION_POINT).div(deposit_rate);
        get(amount);
    }
}