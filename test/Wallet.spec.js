const { deploySingletons } = require('./lib');
const Wallet = artifacts.require('Wallet');
const TestRelayableERC777 = artifacts.require('TestRelayableERC777');

const { sha3 } = web3.utils;

function fixSignature (signature) {
  // in geth its always 27/28, in ganache its 0/1. Change to 27/28 to prevent
  // signature malleability if version is 0/1
  // see https://github.com/ethereum/go-ethereum/blob/v1.8.23/internal/ethapi/api.go#L465
  let v = parseInt(signature.slice(130, 132), 16);
  if (v < 27) {
    v += 27;
  }
  const vHex = v.toString(16);
  return signature.slice(0, 130) + vHex;
}

function bytesToByteLength (bytes) {
  return ((bytes.length - 2) / 2).toString();
}

contract('Wallet', ([admin, user1, user2, user3]) => {
  before(deploySingletons);

  it('should be able to add and remove owners', async () => {
    const wallet = await Wallet.new({ from: user1 });
    await wallet.initialize(admin, user1, { from: user1 });

    assert.isFalse(await wallet.isOwner(user2));
    await wallet.addOwner(user2, { from: user1 });
    assert.isTrue(await wallet.isOwner(user2));
    await wallet.addOwner(user3, { from: user2 });
    assert.isTrue(await wallet.isOwner(user3));
    await wallet.removeOwner(user2, { from: user3 });
    assert.isFalse(await wallet.isOwner(user2));
  });

  it('should be able to call itself', async () => {
    const wallet = await Wallet.new({ from: user1 });
    await wallet.initialize(admin, user1, { from: user1 });

    const data = wallet.contract.methods.addOwner(user2).encodeABI();
    await wallet.execute(wallet.address, data, '0');

    assert.isTrue(await wallet.isOwner(user2));
  });

  it('should validate signatures using ERC1271', async () => {
    const wallet = await Wallet.new({ from: user1 });
    await wallet.initialize(admin, user1, { from: user1 });
    const data = sha3('Test');
    const signature = fixSignature(await web3.eth.sign(data, user1));

    assert.equal(await wallet.isValidSignature(data, signature), '0x20c13b0b');
  });

  it('should emit a Transfer event when transfering ETH', async () => {
    const wallet = await Wallet.new({ from: user1 });
    await wallet.initialize(admin, user1, { from: user1 });

    await web3.eth.sendTransaction({ to: wallet.address, from: user1, value: '1000' });

    const { address: recipient } = web3.eth.accounts.create();
    const { logs } = await wallet.execute(recipient, '0x', '1000');

    assert.equal(logs.length, 1);
    assert.equal(logs[0].event, 'Transfer');
    assert.equal(logs[0].args.from, wallet.address);
    assert.equal(logs[0].args.to, recipient);
    assert.equal(logs[0].args.value, 1000);
  });

  it('should run batch executions', async () => {
    const wallet = await Wallet.new({ from: user1 });
    await wallet.initialize(admin, user1, { from: user1 });

    await web3.eth.sendTransaction({ to: wallet.address, from: user1, value: '1000' });

    const { address: recipient } = web3.eth.accounts.create();
    const data1 = wallet.contract.methods.addOwner(user2).encodeABI();
    const data2 = wallet.contract.methods.addOwner(user3).encodeABI();

    const { logs } = await wallet.executeBatch(
      [recipient, wallet.address, wallet.address],
      data1 + data2.substr(2),
      ['0', bytesToByteLength(data1), bytesToByteLength(data2)],
      ['1000', '0', '0'],
      { from: user1 },
    );

    assert.equal(logs.length, 1);
    assert.equal(logs[0].event, 'Transfer');
    assert.equal(logs[0].args.from, wallet.address);
    assert.equal(logs[0].args.to, recipient);
    assert.equal(logs[0].args.value, 1000);

    assert.equal(await web3.eth.getBalance(recipient), '1000');
    assert.isTrue(await wallet.isOwner(user2));
    assert.isTrue(await wallet.isOwner(user3));
  });

  it('should be able to receive ERC777 tokens', async () => {
    const wallet = await Wallet.new({ from: user1 });
    await wallet.initialize(admin, user1, { from: user1 });

    const token = await TestRelayableERC777.new();

    await token.send(wallet.address, '1000', '0x');
  });
});
