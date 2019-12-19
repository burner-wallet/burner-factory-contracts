pragma solidity ^0.5.8;

import "./IProxyHost.sol";
import "./IWallet.sol";

contract WalletProxy {
  bytes32 private constant HOST_SLOT = 0x36ea5a899f007351627d257f82d4383e5e83a8533e5a1c1d27d29a16d656070d;

  /**
   * @dev Contract constructor.
   * @param factory Address of the proxy factory.
   * @param owner Data to send as msg.data to the implementation to initialize the proxied contract.
   * It should include the signature and the parameters of the function to be called, as described in
   * https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding.
   * This parameter is optional, if no data is given the initialization call to proxied contract will be skipped.
   */
  constructor(address factory, address owner) public {
    assert(HOST_SLOT == keccak256("burner-wallet-factory"));
    setFactory(factory);

    bytes memory data = abi.encodeWithSelector(IWallet(0).initialize.selector, factory, owner);
    (bool success,) = _implementation().delegatecall(data);
    // solhint-disable-previous-line unused-local-variable
    require(success);
  }

  /**
   * @dev Returns the current implementation.
   * @return Address of the current implementation
   */
  function _implementation() internal view returns (address) {
    return IProxyHost(factoryAddress()).getImplementation();
  }

  function setFactory(address factory) internal {
    bytes32 slot = HOST_SLOT;
    assembly {
      sstore(slot, factory)
    }
  }

  function factoryAddress() internal view returns(address factory) {
    bytes32 slot = HOST_SLOT;
    assembly {
      factory := sload(slot)
    }
  }

  /**
   * @dev Fallback function.
   * Implemented entirely in `_fallback`.
   */
  function () payable external {
    _fallback();
  }

  /**
   * @dev Delegates execution to an implementation contract.
   * This is a low level function that doesn't return to its internal call site.
   * It will return to the external caller whatever the implementation returns.
   * @param implementation Address to delegate.
   */
  function _delegate(address implementation) internal {
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize)

      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas, implementation, 0, calldatasize, 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize)

      switch result
      // delegatecall returns 0 on error.
      case 0 { revert(0, returndatasize) }
      default { return(0, returndatasize) }
    }
  }

  /**
   * @dev fallback implementation.
   * Extracted to enable manual triggering.
   */
  function _fallback() internal {
    _delegate(_implementation());
  }
}
