pragma solidity ^0.5.0;

import '../RelayableERC777.sol';

contract TestRelayableERC777 is RelayableERC777 {
  constructor() public RelayableERC777("Test Token", "TST", new address[](0)) {
    _mint(msg.sender, msg.sender, 100 ether, new bytes(0), new bytes(0));
  }
}
