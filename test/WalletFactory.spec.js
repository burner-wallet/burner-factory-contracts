const Wallet = artifacts.require('Wallet');
const WalletFactory = artifacts.require('WalletFactory');
const IRelayHub = artifacts.require('IRelayHub');
const { GSNProvider } = require("@openzeppelin/gsn-provider");
const { startRelay } = require('./lib');

const { toWei } = web3.utils;

contract('WalletFactory', ([admin, user1]) => {
  let relayProcess;
  before(async () => {
    relayProcess = await startRelay(admin);
  });

  after(() => relayProcess.kill());

  afterEach(() => WalletFactory.setProvider(web3.currentProvider));

  it('should generate a wallet using create2', async () => {
    const factory = await WalletFactory.new({ from: admin });

    const walletAddress = await factory.getAddress(user1);

    await factory.createWallet(user1, { from: user1 });

    const wallet = await Wallet.at(walletAddress);

    assert.equal(await wallet.creator(), user1);
  });

  it('should let the creator execute calls against their wallet', async () => {
    const factory = await WalletFactory.new({ from: admin });

    const walletAddress = await factory.getAddress(user1);
    await web3.eth.sendTransaction({ to: walletAddress, from: user1, value: '1000' });

    await factory.createWallet(user1, { from: user1 });

    const wallet = await Wallet.at(walletAddress);
    const { address: recipient } = web3.eth.accounts.create();
    await wallet.execute(recipient, '0x', '1000', { from: user1 });

    assert.equal(await web3.eth.getBalance(recipient), '1000');
  });

  it('should create a wallet and call a transaction in the same tx', async () => {
    const factory = await WalletFactory.new({ from: admin });

    const walletAddress = await factory.getAddress(user1);
    await web3.eth.sendTransaction({ to: walletAddress, from: user1, value: '1000' });

    const { address: recipient } = web3.eth.accounts.create();
    await factory.createAndExecute(recipient, '0x', '1000', { from: user1 });

    assert.equal(await web3.eth.getBalance(recipient), '1000');
  });

  it('should use GNS to pay for gas using the contract wallet', async () => {
    const factory = await WalletFactory.new({ from: admin });
    const relayHub = await IRelayHub.at(await factory.getHubAddr());
    await relayHub.depositFor(factory.address, { value: toWei('0.5', 'ether'), from: admin });

    const gsnAccount = web3.eth.accounts.create();
    const walletAddress = await factory.getAddress(gsnAccount.address);
    await web3.eth.sendTransaction({ to: walletAddress, from: user1, value: toWei('.5', 'ether') });

    const gsnProvider = new GSNProvider(web3.currentProvider, { signKey: gsnAccount.privateKey });
    WalletFactory.setProvider(gsnProvider);

    const { address: recipient } = web3.eth.accounts.create();
    await factory.createAndExecute(recipient, '0x', '1000', {
      from: gsnAccount.address,
      gas: 800000,
    });

    assert.equal(await web3.eth.getBalance(recipient), '1000');
    assert.equal((await relayHub.balanceOf(factory.address)).toString(), toWei('0.5', 'ether'));
  });
});
