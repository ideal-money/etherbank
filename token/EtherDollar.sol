pragma solidity ^0.4.18;

import "./Loanable.sol";


/**
 * @title EtherDollar token contract.
  * @dev ERC20 token contract.
 */
contract EtherDollar is LoanableToken {
    string public constant name = "EtherDollar";
    string public constant symbol = "ETD";
    uint32 public constant decimals = 2;
}
