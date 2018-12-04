pragma solidity ^0.4.18;

import "./openzeppelin/contracts/token/ERC20/MintableToken.sol";
import "./openzeppelin/contracts/token/ERC20/BurnableToken.sol";


/**
 * @title EtherDollar token contract.
  * @dev ERC20 token contract.
 */
contract EtherDollar is MintableToken, BurnableToken {
    string public constant name = "EtherDollar";
    string public constant symbol = "ETD";
    uint32 public constant decimals = 2;
}
