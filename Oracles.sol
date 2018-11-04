pragma solidity ^0.4.22;

import "./openzeppelin/lifecycle/Pausable.sol";


contract Oracles is Pausable {
    address public owner;
    bool public recruitingFinished = false;
    uint64 public totalScore;

    struct oracle {
        address account;
        uint64 score;
        bool isActive;
    }

    mapping(address => oracle) private oracles;

    event LogEditOracles(address oracle, uint256 score);
    event LogFinishRecruiting();


    constructor()
        public {
            owner = msg.sender;
            totalScore = 0;
        }

    /**
     * @dev Manipulate (add/remove/edit score) member of oracles.
     * @param _account The oracle account.
     * @param _account The score of oracle.
     */
    function edit(address _account, uint64 _score)
        external
        onlyOwner
        canRecruiting
        whenNotPaused
    {
        require(_account != address(0));
        if (_score != 0 && oracles[_account].isActive == false) {
            oracles[_account].isActive = true;
            oracles[_account].score = _score;
            oracles[_account].account = _account;
            totalScore += _score;
        } else if (_score != 0 && oracles[_account].isActive == true) {
            totalScore -= oracles[_account].score;
            totalScore += _score;
            oracles[_account].score = _score;
        } else if (_score == 0 && oracles[_account].isActive == true) {
            oracles[_account].isActive = false;
            oracles[_account].score = _score;
            totalScore -= _score;
        }
        emit LogEditOracles(_account, _score);
    }

    /**
     * @dev Get score of the oracle.
     * @param account The account of the oracle.
     */
    function getScore(address account)
        public
        view
        whenNotPaused
        returns(uint64)
    {
        return oracles[oracle].score;
    }

    /**
     * @dev Get total oracles' scores.
     */
    function getTotalScore()
        public
        view
        whenNotPaused
        returns(uint64)
    {
        return totalScore;
    }

    /**
    * @dev Function to stop recruiting new oracle.
    */
    function finishRecruiting()
    public
    onlyOwner
    canRecruiting
    returns (bool) {
        recruitingFinished = true;
        emit LogFinishRecruiting();
    }

    /**
     * @dev Throws if recruiting finished.
     */
    modifier canRecruiting() {
        require(!recruitingFinished);
        _;
    }

}
