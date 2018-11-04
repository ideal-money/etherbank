pragma solidity ^0.4.22;

import "./openzeppelin/lifecycle/Pausable.sol";
import "./EtherBank.sol";
import "./Oracles.sol";


contract Concentrator is Pausable {
    using SafeMath for uint256;

    EtherBank public bank;
    Oracles public oracles;
    uint256 public max;
    uint256 public min;
    uint256 public sum;
    uint256 public sumScores;
    uint256 public votingNo;
    uint256 public totalScore;
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

    event LogBallot(address oracle, uint256 etherPrice, uint256 loanFeeRatio, uint256 depositRate);
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
     * @dev Set Oracles smart contract.
     * @param _address The Oracles smart contract address.
     */
    function setOracles(address _address)
        external
        onlyOwner
        whenNotPaused
    {
        require(_address != address(0));

        oracles = Oracles(_address);
    }

    /**
     * @dev Set EtherBank smart contract.
     * @param _EtherBankAdd The EtherBank smart contract address.
     */
    function setEtherBank(address _EtherBankAdd)
        external
        onlyOwner
        whenNotPaused
    {
        require(_EtherBankAdd != address(0));

        bank = EtherBank(_EtherBankAdd);
    }

    /**
     * @dev Set Oracles size.
     */
    function loadTotalScore()
        external
        whenNotPaused
    {
        totalScore = oracles.getTotalScore();
    }

    /**
     * @dev Sign a ballot.
     * @param _value The value of a variable.
     */
    function balloting(uint256 _value)
        public
        whenNotPaused
        onlyOracles
        throwIfEqualToZero(_value)
    {
        require(min <= _value && _value <= max);

        address oracle = msg.sender;
        uint256 score = oracles.getScore(oracle);
        if (ballotBox[oracle].votingNo == votingNo) {
            sum -= ballotBox[oracle].value.mul(score);
            sumScores -= score;
        }
        ballotBox[oracle].value = _value;
        ballotBox[oracle].votingNo = votingNo;
        sum += _value.mul(score);
        sumScores += score;
        if ((totalScore / sumScores) == 1) {
            updateEtherBank();
        }
        emit LogBallot(oracle, type, _value);
    }

    /**
     * @dev Update the EtherBank variable.
     */
    function updateEtherBank()
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
     * @dev Throws if called by any account other than a oracle.
     */
    modifier onlyOracles() {
        uint256 score = oracles.getScore(msg.sender);
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
