pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./IProxyHost.sol";

contract ProxyHost is Ownable, IProxyHost {
  address public defaultImplementation;

  event DefaultImplementationChanged(address implementation);

  constructor(address _defaultImplementation) public {
    defaultImplementation = _defaultImplementation;
  }

  function getImplementation() external view returns (address) {
    return defaultImplementation;
  }

  function setDefaultImplementation(address implementation) external onlyOwner {
    defaultImplementation = implementation;
    emit DefaultImplementationChanged(implementation);
  }
}
