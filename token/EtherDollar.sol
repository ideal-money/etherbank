pragma solidity ^0.4.18;

import "../openzeppelin/token/MintableToken.sol";
import "../openzeppelin/token/BurnableToken.sol";
import "../openzeppelin/ownership/Claimable.sol";

/**
 * @title EtherDollar token contract.
  * @dev ERC20 token contract.
 */
contract EtherDollar is MintableToken, BurnableToken, Claimable  {
    string public constant name = "EtherDollar";
    string public constant symbol = "ETD";
    uint32 public constant decimals = 2;
}