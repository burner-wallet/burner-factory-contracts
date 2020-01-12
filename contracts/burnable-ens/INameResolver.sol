pragma solidity ^0.5.0;

contract INameResolver {
    function supportsInterface(bytes4 interfaceID) public pure returns (bool);
    function name(bytes32 node) external view returns (string memory);
}
