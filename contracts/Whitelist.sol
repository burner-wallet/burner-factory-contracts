pragma solidity ^0.5.0;

contract Whitelist {
  event WhitelistChanged(address indexed target, address user, bool isWhitelisted);

  mapping(address => mapping(address => bool)) private whitelist;

  constructor() public {
    whitelist[address(this)][msg.sender] = true;
    emit WhitelistChanged(address(this), msg.sender, true);
  }

  modifier onlyAdmin(address target) {
    require(target == msg.sender || isWhitelisted(address(this), msg.sender));
    _;
  }

  function isWhitelisted(address target, address user) public view returns (bool) {
    return whitelist[target][address(0)] || whitelist[target][user];
  }

  function setWhitelisted(address target, address user, bool _isWhitelisted) external onlyAdmin(target) {
    whitelist[target][user] = _isWhitelisted;
    emit WhitelistChanged(target, user, _isWhitelisted);
  }

  function setWhitelistAll(address target, bool _isWhitelisted) external onlyAdmin(target) {
    whitelist[target][address(0)] = _isWhitelisted;
    emit WhitelistChanged(target, address(0), _isWhitelisted);
  }
}
