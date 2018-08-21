pragma solidity ^0.4.22;

import "./openzeppelin/lifecycle/Pausable.sol";


contract Congress is Pausable {
    address public owner;
    bool public recruitingFinished = false;
    uint64 public congressSize;

    struct Congressman {
        address account;
        uint64 score;
        bool isActive;
    }

    mapping(address => Congressman) private congress;

    event LogEditCongress(address congressman, uint256 score);
    event LogFinishRecruiting();


    constructor()
        public {
            owner = msg.sender;
            congressSize = 0;
        }

    /**
     * @dev Manipulate (add/remove/edit score) member of congress.
     * @param _account The account of the member of congress.
     * @param _account The score of the member of congress.
     */
    function editCongress(address _account, uint64 _score)
        external
        onlyOwner
        canRecruiting
        whenNotPaused
    {
        require(_account != address(0));
        if (_score != 0 && congress[_account].isActive == false) {
            congress[_account].isActive = true;
            congress[_account].score = _score;
            congress[_account].account = _account;
            congressSize += _score;
        } else if (_score != 0 && congress[_account].isActive == true) {
            congressSize -= congress[_account].score;
            congressSize += _score;
            congress[_account].score = _score;
        } else if (_score == 0 && congress[_account].isActive == true) {
            congress[_account].isActive = false;
            congress[_account].score = _score;
            congressSize -= _score;
        }
        emit LogEditCongress(_account, _score);
    }

    /**
     * @dev Get score of the congressman.
     * @param congressmanAccount The account of the member of congress.
     */
    function getScore(address congressmanAccount)
        public
        view
        whenNotPaused
        returns(uint64)
    {
        return congress[congressmanAccount].score;
    }

    /**
     * @dev Get number of congressmans.
     */
    function getCongressSize()
        public
        view
        whenNotPaused
        returns(uint64)
    {
        return congressSize;
    }

    /**
    * @dev Function to stop recruiting new congressman.
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
