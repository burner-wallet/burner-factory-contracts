pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/GSN/GSNRecipient.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "./Factory2.sol";
import "./Wallet.sol";

interface InnerWalletFactory {
  function create(address factory, address creator) external returns (Wallet);
  function getAddress(address factory, address creator) view external returns (address);
  function setSalt(uint salt) external returns (InnerWalletFactory);
}

contract WalletFactory is GSNRecipient {
  using Address for address;
  using SafeMath for uint256;

  InnerWalletFactory public innerFactory;

  function () external payable {
  }

  constructor() public {
    innerFactory = createFactory();
  }

  function createFactory() internal returns (InnerWalletFactory) {
    return InnerWalletFactory(address(new Factory2(type(Wallet).creationCode, InnerWalletFactory(0).create.selector)));
  }

  function getAddress(address creator) public view returns (address) {
    return innerFactory.getAddress(address(this), creator);
  }

  function createWallet(address creator) public returns (address) {
    return address(innerFactory.create(address(this), creator));
  }

  function createAndExecute(
    address target,
    bytes calldata data,
    uint256 value
  ) external returns (bytes memory response) {
    address sender = _msgSender();
    address walletAddress = getAddress(sender);

    if (!walletAddress.isContract()) {
      createWallet(sender);
    }

    return Wallet(walletAddress).execute(target, data, value);
  }

  function execute(
    address target,
    bytes calldata data,
    uint256 value
  ) external returns (bytes memory response) {
    Wallet wallet = Wallet(getAddress(_msgSender()));
    return wallet.execute(target, data, value);
  }

  function acceptRelayedCall(
    address,
    address from,
    bytes calldata,
    uint256 transactionFee,
    uint256 gasPrice,
    uint256,
    uint256,
    bytes calldata,
    uint256 maxPossibleCharge
  ) external view returns (uint256, bytes memory) {
    address walletAddress = getAddress(from);

    if (walletAddress.balance < maxPossibleCharge) {
      return _rejectRelayedCall(0);
    }

    return _approveRelayedCall(abi.encode(from, walletAddress, maxPossibleCharge, transactionFee, gasPrice));
  }

  /**
   * @dev Implements the precharge to the user. The maximum possible charge (depending on gas limit, gas price, and
   * fee) will be deducted from the user balance of gas payment token. Note that this is an overestimation of the
   * actual charge, necessary because we cannot predict how much gas the execution will actually need. The remainder
   * is returned to the user in {_postRelayedCall}.
   */
  function _preRelayedCall(bytes memory context) internal returns (bytes32) {
    (address from, address walletAddress, uint256 maxPossibleCharge) = abi.decode(context, (address, address, uint256));

    if (!walletAddress.isContract()) {
      address created = createWallet(from);
      // require(walletAddress == created);
    }

    // Wallet(walletAddress).execute(address(this), new bytes(0), 0);
  }

  /**
   * @dev Returns to the user the extra amount that was previously charged, once the actual execution cost is known.
   */
  function _postRelayedCall(bytes memory context, bool, uint256 actualCharge, bytes32) internal {
    (address from, uint256 maxPossibleCharge, uint256 transactionFee, uint256 gasPrice) =
        abi.decode(context, (address, uint256, uint256, uint256));

    // actualCharge is an _estimated_ charge, which assumes postRelayedCall will use all available gas.
    // This implementation's gas cost can be roughly estimated as 10k gas, for the two SSTORE operations in an
    // ERC20 transfer.
    // uint256 overestimation = _computeCharge(POST_RELAYED_CALL_MAX_GAS.sub(10000), gasPrice, transactionFee);
    // actualCharge = actualCharge.sub(overestimation);

    // After the relayed call has been executed and the actual charge estimated, the excess pre-charge is returned
    // from.toPayable().transfer(maxPossibleCharge.sub(actualCharge));
  }

}
