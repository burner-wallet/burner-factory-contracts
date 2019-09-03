pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC777/IERC777.sol";
import "openzeppelin-solidity/contracts/token/ERC777/IERC777Recipient.sol";
import "openzeppelin-solidity/contracts/token/ERC777/IERC777Sender.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "openzeppelin-solidity/contracts/introspection/IERC1820Registry.sol";

import "tabookey-gasless/contracts/GsnUtils.sol";
import "tabookey-gasless/contracts/RelayRecipient.sol";
import "tabookey-gasless/contracts/IRelayHub.sol";

contract RelayableERC777 is IERC777, IERC20, RelayRecipient {
  using SafeMath for uint256;
  using Address for address;

  IERC1820Registry internal _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

  mapping(address => uint256) private _balances;

  uint256 private _totalSupply;

  string private _name;
  string private _symbol;

  // We inline the result of the following hashes because Solidity doesn't resolve them at compile time.
  // See https://github.com/ethereum/solidity/issues/4024.

  // keccak256("ERC777TokensSender")
  bytes32 constant private TOKENS_SENDER_INTERFACE_HASH =
      0x29ddb589b1fb5fc7cf394961c1adf5f8c6454761adf795e67fe149f658abe895;

  // keccak256("ERC777TokensRecipient")
  bytes32 constant private TOKENS_RECIPIENT_INTERFACE_HASH =
      0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b;

  bytes4 constant private SEND_SIGNATURE = 0x9bd9bbc6;
  bytes4 constant private TRANSFER_SIGNATURE = 0xa9059cbb;
  bytes4 constant private TRANSFER_FROM_SIGNATURE = 0x23b872dd;
  bytes4 constant private APPROVE_SIGNATURE = 0x095ea7b3;

  uint256 constant private MAX_SENDER_BALANCE = 0.1 ether;

  // This isn't ever read from - it's only used to respond to the defaultOperators query.
  address[] private _defaultOperatorsArray;

  // Immutable, but accounts may revoke them (tracked in __revokedDefaultOperators).
  mapping(address => bool) private _defaultOperators;

  // For each account, a mapping of its operators and revoked default operators.
  mapping(address => mapping(address => bool)) private _operators;
  mapping(address => mapping(address => bool)) private _revokedDefaultOperators;

  // ERC20-allowances
  mapping (address => mapping (address => uint256)) private _allowances;


  constructor (string memory name,
    string memory symbol,
    address[] memory defaultOperators,
    address hubAddress
  ) public {
    _name = name;
    _symbol = symbol;

    _defaultOperatorsArray = defaultOperators;
    for (uint256 i = 0; i < _defaultOperatorsArray.length; i++) {
      _defaultOperators[_defaultOperatorsArray[i]] = true;
    }

    if (hubAddress != address(0x0)) {
      setRelayHub(IRelayHub(hubAddress));
    }

    // register interfaces
    _erc1820.setInterfaceImplementer(address(this), keccak256("ERC777Token"), address(this));
    _erc1820.setInterfaceImplementer(address(this), keccak256("ERC20Token"), address(this));
  }


  //
  // Token view functions
  //


  /**
   * @dev See {IERC777-name}.
   */
  function name() public view returns (string memory) {
    return _name;
  }

  /**
   * @dev See {IERC777-symbol}.
   */
  function symbol() public view returns (string memory) {
    return _symbol;
  }

  /**
   * @dev See {ERC20Detailed-decimals}.
   *
   * Always returns 18, as per the
   * [ERC777 EIP](https://eips.ethereum.org/EIPS/eip-777#backward-compatibility).
   */
  function decimals() public pure returns (uint8) {
    return 18;
  }

  /**
   * @dev See {IERC777-granularity}.
   *
   * This implementation always returns `1`.
   */
  function granularity() public view returns (uint256) {
    return 1;
  }

  /**
   * @dev See {IERC777-totalSupply}.
   */
  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  /**
   * @dev Returns the amount of tokens owned by an account (`tokenHolder`).
   */
  function balanceOf(address tokenHolder) public view returns (uint256) {
      return _balances[tokenHolder];
  }

  function defaultOperators() public view returns (address[] memory) {
    return _defaultOperatorsArray;
  }

  //
  // Relay functions
  //

  function accept_relayed_call(address relay, address from, bytes memory encoded_function,
      uint gas_price, uint transaction_fee ) public view returns(uint32) {
    return uint32(acceptRelayedCall(relay, from, encoded_function, gas_price, transaction_fee, new bytes(0), new bytes(0)));
  }

  function acceptRelayedCall(address /*relay*/, address from, bytes memory encodedFunction,
      uint /*gasPrice*/, uint /*transactionFee*/, bytes memory /*signature*/,
      bytes memory /* approval */) public view returns(uint) {
    bytes4 signature = GsnUtils.getMethodSig(encodedFunction);
    if (!(signature == SEND_SIGNATURE || signature == TRANSFER_SIGNATURE
      || signature == APPROVE_SIGNATURE || signature == TRANSFER_FROM_SIGNATURE)) {
      return 1;
    }

    if (from.balance > MAX_SENDER_BALANCE) {
      return 1;
    }

    return 0;
  }

  function preRelayedCall(address /*relay*/, address /*from*/, bytes memory /*encodedFunction*/,
      uint /*transactionFee*/) public returns (bytes32) {
    return 0;
  }

  function post_relayed_call(address relay, address from, bytes memory encoded_function,
      bool success, uint used_gas, uint transaction_fee) public {
    postRelayedCall(relay, from, encoded_function, success, used_gas, transaction_fee, bytes32(0));
  }

  //nothing to be done post-call. still, we must implement this method.
  function postRelayedCall(address /*relay*/, address /*from*/,
    bytes memory /*encodedFunction*/, bool /*success*/, uint /*usedGas*/, uint /*transactionFee*/,
    bytes32 /*preRetVal*/) public { }

  function get_hub_addr() external view returns (address) {
    return address(getRelayHub());
  }

  function get_recipient_balance() external view returns (uint256) {
    return relayBalance();
  }

  function relayBalance() public view returns (uint256) {
    return getRelayHub().balanceOf(address(this));
  }

  function depositForRelay() public payable {
    getRelayHub().depositFor.value(msg.value)(address(this));
  }

  function _withdrawFromRelay() internal returns (uint256) {
    uint256 balance = getRelayHub().balanceOf(address(this));
    getRelayHub().withdraw(balance);
    return balance;
  }


  //
  // Stanard ERC20/ERC777 funcitions
  //


  function send(address recipient, uint256 amount, bytes calldata data) external {
    address from = getSender();
    _send(from, from, recipient, amount, data, "", true);
  }

  function transfer(address recipient, uint256 amount) external returns (bool) {
    require(recipient != address(0), "ERC777: transfer to the zero address");

    address from = getSender();

    _callTokensToSend(from, from, recipient, amount, "", "");

    _move(from, from, recipient, amount, "", "");

    _callTokensReceived(from, from, recipient, amount, "", "", false);

    return true;
  }

  function burn(uint256 amount, bytes calldata data) external {
    address from = getSender();
    _burn(from, from, amount, data, "");
  }

  function isOperatorFor(
    address operator,
    address tokenHolder
  ) public view returns (bool) {
    return operator == tokenHolder ||
      (_defaultOperators[operator] && !_revokedDefaultOperators[tokenHolder][operator]) ||
      _operators[tokenHolder][operator];
  }

  function authorizeOperator(address operator) external {
    address from = getSender();
    require(from != operator, "ERC777: authorizing self as operator");

    if (_defaultOperators[operator]) {
        delete _revokedDefaultOperators[from][operator];
    } else {
        _operators[from][operator] = true;
    }

    emit AuthorizedOperator(operator, from);
  }

  function revokeOperator(address operator) external {
    address from = getSender();
    require(operator != from, "ERC777: revoking self as operator");

    if (_defaultOperators[operator]) {
        _revokedDefaultOperators[from][operator] = true;
    } else {
        delete _operators[from][operator];
    }

    emit RevokedOperator(operator, from);
  }

  function operatorSend(
    address sender,
    address recipient,
    uint256 amount,
    bytes calldata data,
    bytes calldata operatorData
  )
  external
  {
    address from = getSender();
    require(isOperatorFor(from, sender), "ERC777: caller is not an operator for holder");
    _send(from, sender, recipient, amount, data, operatorData, true);
  }

  function operatorBurn(address account, uint256 amount, bytes calldata data, bytes calldata operatorData) external {
    address from = getSender();
    require(isOperatorFor(from, account), "ERC777: caller is not an operator for holder");
    _burn(from, account, amount, data, operatorData);
  }

  function allowance(address holder, address spender) public view returns (uint256) {
    return _allowances[holder][spender];
  }

  function approve(address spender, uint256 value) external returns (bool) {
    address holder = getSender();
    _approve(holder, spender, value);
    return true;
  }

  function transferFrom(address holder, address recipient, uint256 amount) external returns (bool) {
    require(recipient != address(0), "ERC777: transfer to the zero address");
    require(holder != address(0), "ERC777: transfer from the zero address");

    address spender = getSender();

    _callTokensToSend(spender, holder, recipient, amount, "", "");

    _move(spender, holder, recipient, amount, "", "");
    _approve(holder, spender, _allowances[holder][spender].sub(amount));

    _callTokensReceived(spender, holder, recipient, amount, "", "", false);

    return true;
  }

  //
  // Private funcitons
  //

  function _mint(
    address operator,
    address account,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData
  )
    internal
  {
    require(account != address(0), "ERC777: mint to the zero address");

    // Update state variables
    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);

    _callTokensReceived(operator, address(0), account, amount, userData, operatorData, true);

    emit Minted(operator, account, amount, userData, operatorData);
    emit Transfer(address(0), account, amount);
  }

  /**
   * @dev Send tokens
   * @param operator address operator requesting the transfer
   * @param from address token holder address
   * @param to address recipient address
   * @param amount uint256 amount of tokens to transfer
   * @param userData bytes extra information provided by the token holder (if any)
   * @param operatorData bytes extra information provided by the operator (if any)
   * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
   */
  function _send(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData,
    bool requireReceptionAck
  )
    private
  {
    require(from != address(0), "ERC777: send from the zero address");
    require(to != address(0), "ERC777: send to the zero address");

    _callTokensToSend(operator, from, to, amount, userData, operatorData);

    _move(operator, from, to, amount, userData, operatorData);

    _callTokensReceived(operator, from, to, amount, userData, operatorData, requireReceptionAck);
  }

  /**
   * @dev Burn tokens
   * @param operator address operator requesting the operation
   * @param from address token holder address
   * @param amount uint256 amount of tokens to burn
   * @param data bytes extra information provided by the token holder
   * @param operatorData bytes extra information provided by the operator (if any)
   */
  function _burn(
    address operator,
    address from,
    uint256 amount,
    bytes memory data,
    bytes memory operatorData
  )
    private
  {
    require(from != address(0), "ERC777: burn from the zero address");

    _callTokensToSend(operator, from, address(0), amount, data, operatorData);

    // Update state variables
    _totalSupply = _totalSupply.sub(amount);
    _balances[from] = _balances[from].sub(amount);

    emit Burned(operator, from, amount, data, operatorData);
    emit Transfer(from, address(0), amount);
  }

  function _move(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData
  )
    internal
  {
    _balances[from] = _balances[from].sub(amount);
    _balances[to] = _balances[to].add(amount);

    emit Sent(operator, from, to, amount, userData, operatorData);
    emit Transfer(from, to, amount);
  }

  function _approve(address holder, address spender, uint256 value) private {
    // TODO: restore this require statement if this function becomes internal, or is called at a new callsite. It is
    // currently unnecessary.
    //require(holder != address(0), "ERC777: approve from the zero address");
    require(spender != address(0), "ERC777: approve to the zero address");

    _allowances[holder][spender] = value;
    emit Approval(holder, spender, value);
  }

  /**
   * @dev Call from.tokensToSend() if the interface is registered
   * @param operator address operator requesting the transfer
   * @param from address token holder address
   * @param to address recipient address
   * @param amount uint256 amount of tokens to transfer
   * @param userData bytes extra information provided by the token holder (if any)
   * @param operatorData bytes extra information provided by the operator (if any)
   */
  function _callTokensToSend(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData
  )
    private
  {
    address implementer = _erc1820.getInterfaceImplementer(from, TOKENS_SENDER_INTERFACE_HASH);
    if (implementer != address(0)) {
      IERC777Sender(implementer).tokensToSend(operator, from, to, amount, userData, operatorData);
    }
  }

  /**
   * @dev Call to.tokensReceived() if the interface is registered. Reverts if the recipient is a contract but
   * tokensReceived() was not registered for the recipient
   * @param operator address operator requesting the transfer
   * @param from address token holder address
   * @param to address recipient address
   * @param amount uint256 amount of tokens to transfer
   * @param userData bytes extra information provided by the token holder (if any)
   * @param operatorData bytes extra information provided by the operator (if any)
   * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
   */
  function _callTokensReceived(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData,
    bool requireReceptionAck
  )
    private
  {
    address implementer = _erc1820.getInterfaceImplementer(to, TOKENS_RECIPIENT_INTERFACE_HASH);
    if (implementer != address(0)) {
      IERC777Recipient(implementer).tokensReceived(operator, from, to, amount, userData, operatorData);
    } else if (requireReceptionAck) {
      require(!to.isContract(), "ERC777: token recipient contract has no implementer for ERC777TokensRecipient");
    }
  }
}
