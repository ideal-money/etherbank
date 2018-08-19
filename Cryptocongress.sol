pragma solidity ^0.4.22;


contract Cryptocongress {
    address public owner;
    bool public recruitingFinished = false;
    uint64 public congressSize;

    struct Congressman {
        address account;
        uint64 score;
        bool isActive;
    }

    mapping(address => Congressman) private congress;

    constructor()
        public {
            owner = msg.sender;
            congressSize = 0;
        }

    /**
     * @dev Manipulate (add/remove/edit score) member of congress.
     * @param _congressmanAccount The account of the member of congress.
     */
    function editCongress(address _account, uint64 _score)
        external
        onlyOwner
        canRecruiting
        whenNotPaused
    {
        require(_account != address(0));
        if (accountsIndexes[_account].score != 0 && accountsIndexes[_account].isActive == false) {
            congress[_account].isActive = true;
            congressSize += 1;
        } else if (accountsIndexes[_account].score == 0 && accountsIndexes[_account].isActive == true) {
            congress[_account].isActive = false;
            congressSize -= 1;
        }
        congress[_account].score = _score;
        congress[_account].account = _account;
    }

    /**
     * @dev Get score of the congressman.
     * @param _congressmanAccount The account of the member of congress.
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
        emit recruitingFinished();
    }

    /**
     * @dev Throws if called by any account other than owner.
     */
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Throws if recruiting finished.
     */
    modifier canRecruiting() {
        require(!recruitingFinished);
        _;
    }

}
