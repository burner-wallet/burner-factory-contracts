pragma solidity ^0.5.8;

interface IProxyHost {
  function getImplementation() external view returns (address);
  // function setImplementation(address implementation) external;
  // function getDefaultImplementation() external returns (address);
  function setDefaultImplementation(address implementation) external;
}
