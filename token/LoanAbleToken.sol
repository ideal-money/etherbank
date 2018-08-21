pragma solidity ^0.4.18;

import "../openzeppelin/token/MintableToken.sol";
import "../openzeppelin/token/BurnableToken.sol";
import "../openzeppelin/ownership/Claimable.sol";


/**
 * @title EtherDollar token contract.
  * @dev ERC20 token contract.
 */
contract LoanableToken is MintableToken, BurnableToken, Claimable {
}
