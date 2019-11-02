pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/GSN/GSNRecipient.sol";
import "openzeppelin-solidity/contracts/token/ERC777/ERC777.sol";

contract RelayableERC777 is ERC777, GSNRecipient {
  constructor(string memory name, string memory symbol, address[] memory defaultOperators)
  public
  ERC777(name, symbol, defaultOperators) {}

  // accept all requests
  function acceptRelayedCall(
    address,
    address,
    bytes calldata,
    uint256,
    uint256,
    uint256,
    uint256,
    bytes calldata,
    uint256
  ) external view returns (uint256, bytes memory) {
    return _approveRelayedCall();
  }

  function getRecipientBalance() public view returns (uint) {
    return getRelayHub().balanceOf(address(this));
  }

  function depositForRelay() public payable {
    getRelayHub().depositFor.value(msg.value)(address(this));
  }

  function _withdrawFromRelay() internal returns (uint256) {
    uint256 balance = getRelayHub().balanceOf(address(this));
    getRelayHub().withdraw(balance, address(uint160(address(this))));
    return balance;
  }

  function getRelayHub() internal view returns (IRelayHub) {
    return IRelayHub(getHubAddr());
  }

  function _preRelayedCall(bytes memory) internal returns (bytes32) {
    // solhint-disable-previous-line no-empty-blocks
  }

  function _postRelayedCall(bytes memory, bool, uint256, bytes32) internal {
    // solhint-disable-previous-line no-empty-blocks
  }

}
