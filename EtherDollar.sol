pragma solidity ^0.4.18;

import "./openzeppelin/contracts/token/MintableToken.sol";
import "./openzeppelin/contracts/token/BurnableToken.sol";
import "./openzeppelin/contracts/ownership/Claimable.sol";


/**
 * @title EtherDollar token contract.
  * @dev ERC20 token contract.
 */
contract EtherDollar is MintableToken, BurnableToken, Claimable {
    string public constant name = "EtherDollar";
    string public constant symbol = "ETD";
    uint32 public constant decimals = 2;
}
