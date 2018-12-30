pragma solidity ^0.4.24;

import "./openzeppelin/contracts/ownership/Ownable.sol";
import "./openzeppelin/contracts/math/SafeMath.sol";
import "./EtherBank.sol";


/**
 * @title EtherBank's Oracles contract.
 */
contract Oracles is Ownable {
    using SafeMath for uint256;

    address public owner;

    EtherBank internal bank;

    bool public recruitingFinished = false;

    uint256 private totalScore;

    struct Vote {
        uint256 value;
        uint256 votingNo;
    }

    struct Voting {
        uint256 sum;
        uint256 sumScores;
        uint256 No;
    }

    mapping(bytes32 => Vote) private votes;
    mapping(uint8 => Voting) private votings;
    mapping(address => uint256) private oracles;

    event EditOracles(address oracle, uint256 score);
    event FinishRecruiting();
    event SetVote(address oracle, uint8 _type, uint256 _value);
    event Update(uint8 indexed _type, uint256 _value);

    string private constant INVALID_ADDRESS = "INVALID_ADDRESS";
    string private constant RECRUITING_FINISHED = "RECRUITING_FINISHED";
    string private constant INVALID_SCORE = "INVALID_SCORE";

    constructor(address _etherBankAddr)
        public
    {
        owner = msg.sender;
        bank = EtherBank(_etherBankAddr);
    }

    /**
     * @notice Sign a ballot.
     * @param _value The value of a variable.
     * @param _type The variable code.
     */
    function vote(uint8 _type, uint256 _value)
        external
    {
        address oracle = msg.sender;
        uint256 score = oracles[oracle];
        bytes32 votesKey = keccak256(abi.encodePacked(oracle,_type));
        if (votings[_type].No == 0) {
            votings[_type].No++;
        }
        if (votes[votesKey].votingNo == votings[_type].No) {
            votings[_type].sum = votings[_type].sum.sub(votes[votesKey].value.mul(score));
            votings[_type].sumScores = votings[_type].sumScores.sub(score);
        }
        votes[votesKey].value = _value;
        votes[votesKey].votingNo = votings[_type].No;
        votings[_type].sum = votings[_type].sum.add(_value.mul(score));
        votings[_type].sumScores = votings[_type].sumScores.add(score);
        emit SetVote(oracle, _type, _value);
        if (totalScore.div(votings[_type].sumScores) < 2) {
            updateEtherBank(_type);
        }
    }

    /**
     * @notice Update the EtherBank variable.
     * @param _type The variable code.
     */
    function updateEtherBank(uint8 _type)
        internal
    {
        uint256 _value = votings[_type].sum.div(votings[_type].sumScores);
        bank.setVariable(_type, _value);
        votings[_type].sum = 0;
        votings[_type].sumScores = 0;
        votings[_type].No++;
        emit Update(_type, _value);
    }

    /**
     * @notice Manipulate (add/remove/edit score) member of oracles.
     * @param _account The oracle account.
     * @param _score The score of oracle.
     */
    function setScore(address _account, uint256 _score)
        external
        onlyOwner
        canRecruiting
    {
        require(_account != address(0), INVALID_ADDRESS);
        require(0 <= _score && _score <= 100, INVALID_SCORE);
        totalScore = totalScore.sub(oracles[_account]);
        totalScore = totalScore.add(_score);
        oracles[_account] = _score;
        emit EditOracles(_account, _score);
    }

    /**
    * @notice Function to stop recruiting new oracle.
    */
    function finishRecruiting()
        external
        onlyOwner
        canRecruiting
    {
        recruitingFinished = true;
        emit FinishRecruiting();
    }

    /**
     * @dev Throws if recruiting finished.
     */
    modifier canRecruiting() {
        require(!recruitingFinished, RECRUITING_FINISHED);
        _;
    }
}
