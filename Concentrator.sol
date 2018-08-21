pragma solidity ^0.4.22;

import "./openzeppelin/lifecycle/Pausable.sol";
import "./ReserveBank.sol";
import "./Congress.sol";


contract Concentrator is Pausable {
    using SafeMath for uint256;

    ReserveBank public bank;
    Congress public congress;
    uint256 public max;
    uint256 public min;
    uint256 public sum;
    uint256 public sumScores;
    uint256 public votingNo;
    uint256 public congressSize;
    uint8 public type;
    address public owner;
    // type {
    //     1 : ETHER_PRICE,
    //     2 : DEPOSIT_RATE,
    //     3 : LOAN_FEE_RATIO,
    //     4 : LIQUIDATION_DURATION
    // }

    struct Ballot {
        uint256 value;
        uint256 votingNo;
    }

    mapping(address => Ballot) private ballotBox;

    event LogBallot(address congressman, uint256 etherPrice, uint256 loanFeeRatio, uint256 depositRate);
    event LogUpdate(uint256 depositRate, uint256 etherPrice, uint256 loanFeeRatio);

    constructor(uint256 _min, uint256 _max, uint8 _type)
        public {
            owner = msg.sender;
            sum = 0;
            sumScores = 0;
            votingNo = 0;
            min = _min;
            max = _max;
            type = _type;
        }

    /**
     * @dev Set Congress smart contract.
     * @param _congressAdd The CryptoCongress smart contract address.
     */
    function setCongress(address _congressAdd)
        external
        onlyOwner
        whenNotPaused
    {
        require(_congressAdd != address(0));

        congress = Congress(_congressAdd);
    }

    /**
     * @dev Set ReserveBank smart contract.
     * @param _reserveBankAdd The ReserveBank smart contract address.
     */
    function setReserveBank(address _reserveBankAdd)
        external
        onlyOwner
        whenNotPaused
    {
        require(_reserveBankAdd != address(0));

        bank = ReserveBank(_reserveBankAdd);
    }

    /**
     * @dev Set Congress size.
     */
    function setCongressSize()
        external
        whenNotPaused
    {
        congressSize = congress.getCongressSize();
    }

    /**
     * @dev Sign a ballot.
     * @param _value The value of a variable.
     */
    function balloting(uint256 _value)
        public
        whenNotPaused
        onlyCongressmans
        throwIfEqualToZero(_value)
    {
        require(min <= _value && _value <= max);

        address congressman = msg.sender;
        uint256 score = congress.getScore(congressman);
        if (ballotBox[congressman].votingNo == votingNo) {
            sum -= ballotBox[congressman].value.mul(score);
            sumScores -= score;
        }
        ballotBox[congressman].value = _value;
        ballotBox[congressman].votingNo = votingNo;
        sum += _value.mul(score);
        sumScores += score;
        if ((congressSize / sumScores) == 1) {
            updateReserveBank();
        }
        emit LogBallot(congressman, type, _value);
    }

    /**
     * @dev Update the ReserveBank variable.
     */
    function updateReserveBank()
    internal
    {
        calculatdValue = sum / sumScores;
        bank.setVariable(type, calculatdValue);
        sum = 0;
        sumScores = 0;
        ++votingNo;
        emit LogUpdate(type, calculatdValue);
    }

    /**
     * @dev Throws if called by any account other than a congressman.
     */
    modifier onlyCongressmans() {
        uint256 score = congress.getScore(msg.sender);
        require(score != 0);
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
}
