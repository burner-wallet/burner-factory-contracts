pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/GSN/GSNRecipient.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "../FreeGas.sol";
import "./Factory2.sol";
import "./ProxyHost.sol";
import "./IWallet.sol";
import "./WalletProxy.sol";

interface InnerWalletFactory {
  function create(address factory, address creator) external returns (address payable);
  function getAddress(address factory, address creator) view external returns (address payable);
  function setSalt(uint salt) external returns (InnerWalletFactory);
}

contract WalletFactory is ProxyHost, FreeGas {
  using Address for address;
  using Address for address payable;
  using SafeMath for uint256;

  InnerWalletFactory public innerFactory;

  bytes4 constant public ERC1271_RETURN_VALID_SIGNATURE = 0x20c13b0b; // TODO: Likely needs to be updated

  constructor(address walletImplementation) public ProxyHost(walletImplementation) {
    innerFactory = createFactory();
  }

  function createFactory() internal returns (InnerWalletFactory) {
    return InnerWalletFactory(address(new Factory2(type(WalletProxy).creationCode, InnerWalletFactory(0).create.selector)));
  }

  function getAddress(address creator) public view returns (address payable) {
    return innerFactory.getAddress(address(this), creator);
  }

  function createWallet(address creator) public returns (address payable) {
    return innerFactory.create(address(this), creator);
  }

  function createAndExecute(
    address target,
    bytes calldata data,
    uint256 value
  ) external returns (bytes memory response) {
    address sender = _msgSender();
    address payable walletAddress = getAddress(sender);

    if (!walletAddress.isContract()) {
      createWallet(sender);
    }

    return IWallet(walletAddress).execute(target, data, value);
  }

  function execute(
    address target,
    bytes calldata data,
    uint256 value
  ) external returns (bytes memory response) {
    IWallet wallet = IWallet(getAddress(_msgSender()));
    return wallet.execute(target, data, value);
  }

  /**
    * Known issues with this implementation
    * - Does not prevent replay attacks (there is no nonce)
    * - Does not prevent cross-chain replay attacks (should use the chainID opcode)
    */
  function executeWithSignature(
    address payable wallet,
    address target,
    bytes calldata data,
    uint256 value,
    bytes calldata signature
  ) external returns (bytes memory response) {
    IWallet _wallet = IWallet(wallet);

    bytes memory packed = abi.encodePacked(wallet, target, data, value);
    bytes32 hash = keccak256(packed);
    require(_wallet.isValidSignature(hash, signature) == ERC1271_RETURN_VALID_SIGNATURE, "Invalid signature");

    return _wallet.execute(target, data, value);
  }

  function addOwnerAndExecute(
    address payable wallet,
    address target,
    bytes calldata data,
    uint256 value,
    bytes calldata signature
  ) external returns (bytes memory response) {
    IWallet _wallet = IWallet(wallet);
    address sender =  _msgSender();

    bytes memory packed = abi.encodePacked("burn:", wallet, sender);
    bytes32 hash = keccak256(packed);
    require(_wallet.isValidSignature(hash, signature) == ERC1271_RETURN_VALID_SIGNATURE, "Invalid signature");
    _wallet.addOwner(sender);

    return _wallet.execute(target, data, value);
  }

  function createAddOwnerAndExecute(
    address owner,
    address target,
    bytes calldata data,
    uint256 value,
    bytes calldata signature
  ) external returns (bytes memory response) {
    address payable walletAddress = getAddress(owner);
    address sender =  _msgSender();

    if (!walletAddress.isContract()) {
      createWallet(owner);
    }

    bytes memory packed = abi.encodePacked("burn:", walletAddress, sender);
    bytes32 hash = keccak256(packed);
    require(IWallet(walletAddress).isValidSignature(hash, signature) == ERC1271_RETURN_VALID_SIGNATURE, "Invalid signature");
    IWallet(walletAddress).addOwner(sender);

    return IWallet(walletAddress).execute(target, data, value);
  }
}
