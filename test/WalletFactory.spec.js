const Wallet = artifacts.require('Wallet');
const WalletFactory = artifacts.require('WalletFactory');
const IRelayHub = artifacts.require('IRelayHub');
const TestWalletImplementation = artifacts.require('TestWalletImplementation');
const { GSNProvider } = require("@openzeppelin/gsn-provider");
const { startRelay } = require('./lib');

const { toWei, soliditySha3 } = web3.utils;

contract('WalletFactory', ([admin, user1, user2]) => {
  let relayProcess;
  let implementation;
  before(async () => {
    relayProcess = await startRelay(admin);
    const implementationInstance = await Wallet.new();
    implementation = implementationInstance.address;
  });

  after(() => relayProcess.kill());

  afterEach(() => WalletFactory.setProvider(web3.currentProvider));

  it('should generate a wallet using create2', async () => {
    const factory = await WalletFactory.new(implementation, { from: admin });

    const walletAddress = await factory.getAddress(user1);

    await factory.createWallet(user1, { from: user1 });

    const wallet = await Wallet.at(walletAddress);

    assert.equal(await wallet.creator(), user1);
  });

  it('should let the creator execute calls against their wallet', async () => {
    const factory = await WalletFactory.new(implementation, { from: admin });

    const walletAddress = await factory.getAddress(user1);
    await web3.eth.sendTransaction({ to: walletAddress, from: user1, value: '1000' });

    await factory.createWallet(user1, { from: user1 });

    const wallet = await Wallet.at(walletAddress);
    const { address: recipient } = web3.eth.accounts.create();
    await wallet.execute(recipient, '0x', '1000', { from: user1 });

    assert.equal(await web3.eth.getBalance(recipient), '1000');
  });

  it('should create a wallet and call a transaction in the same tx', async () => {
    const factory = await WalletFactory.new(implementation, { from: admin });

    const walletAddress = await factory.getAddress(user1);
    await web3.eth.sendTransaction({ to: walletAddress, from: user1, value: '1000' });

    const { address: recipient } = web3.eth.accounts.create();
    const { receipt } = await factory.createAndExecute(recipient, '0x', '1000', { from: user1 });
    console.log('createAndExecute gas cost:', receipt.gasUsed);

    assert.equal(await web3.eth.getBalance(recipient), '1000');
  });

  it('should use GNS to pay for gas using the contract wallet', async () => {
    const factory = await WalletFactory.new(implementation, { from: admin });
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
      gas: 1000000,
    });

    assert.equal(await web3.eth.getBalance(recipient), '1000');
    assert.equal((await relayHub.balanceOf(factory.address)).toString(), toWei('0.5', 'ether'));
  });

  it('should allow contract execution using a signature', async () => {
    const factory = await WalletFactory.new(implementation, { from: admin });
    const account = web3.eth.accounts.create();

    const walletAddress = await factory.getAddress(account.address);
    await web3.eth.sendTransaction({ to: walletAddress, from: user1, value: '1000' });
    await factory.createWallet(account.address, { from: user1 });

    const { address: recipient } = web3.eth.accounts.create();
    const hash = web3.utils.soliditySha3(
      { type: 'address', value: walletAddress },
      { type: 'address', value: recipient },
      '0x',
      '1000'
    );
    const { signature } = account.sign(hash);

    await factory.executeWithSignature(walletAddress, recipient, '0x', '1000', signature, { from: user1 });
    assert.equal(await web3.eth.getBalance(recipient), '1000');
  });

  it('should let a user add themself as a signer using signatures', async () => {
    const factory = await WalletFactory.new(implementation, { from: admin });
    const account = web3.eth.accounts.create();

    const walletAddress = await factory.getAddress(account.address);
    await web3.eth.sendTransaction({ to: walletAddress, from: user1, value: '1000' });
    await factory.createWallet(account.address, { from: user1 });

    const wallet = await Wallet.at(walletAddress);
    const data = wallet.contract.methods.addOwner(user1).encodeABI();

    const hash = web3.utils.soliditySha3(
      { type: 'address', value: walletAddress },
      { type: 'address', value: walletAddress },
      data,
      '0'
    );
    const { signature } = account.sign(hash);

    await factory.executeWithSignature(walletAddress, walletAddress, data, '0', signature, { from: user1 });

    assert.isTrue(await wallet.owners(user1));
  });

  it('should let the owner update the wallet implementation', async () => {
    const factory = await WalletFactory.new(implementation, { from: admin });
    const newImplementation = await TestWalletImplementation.new();

    await factory.createWallet(user1, { from: user1 });

    await factory.setDefaultImplementation(newImplementation.address);

    const wallet = await TestWalletImplementation.at(await factory.getAddress(user1));
    await wallet.changeCreator(user2, { from: user1 });

    assert.equal(await wallet.creator(), user2);
  });

  it('should let a user add themself as a signer and execute a transaction', async () => {
    const factory = await WalletFactory.new(implementation, { from: admin });
    const account = web3.eth.accounts.create();

    const walletAddress = await factory.getAddress(account.address);
    await factory.createWallet(account.address, { from: user1 });
    await web3.eth.sendTransaction({ to: walletAddress, from: user1, value: '1000' });

    const wallet = await Wallet.at(walletAddress);

    const hash = web3.utils.soliditySha3('burn:', walletAddress, user1);
    const { signature } = account.sign(hash);

    const { address: recipient } = web3.eth.accounts.create();
    await factory.addOwnerAndExecute(walletAddress, recipient, '0x', '1000', signature, { from: user1 });

    assert.isTrue(await wallet.owners(user1));
    assert.equal(await web3.eth.getBalance(recipient), '1000');
  });

  it('should let a user create, add owner and execute in a single transaction', async () => {
    const factory = await WalletFactory.new(implementation, { from: admin });
    const nullWallet = await Wallet.at(implementation);

    const identityAccount = web3.eth.accounts.create();
    const { address: recipient } = web3.eth.accounts.create();

    const wallet = await factory.getAddress(identityAccount.address);
    await web3.eth.sendTransaction({ to: wallet, from: user1, value: '1000' });

    const hash = soliditySha3('burn:', wallet, user1);
    const { signature } = identityAccount.sign(hash);

    await factory.createAddOwnerAndExecute(identityAccount.address, recipient, '0x', '1000', signature, { from: user1 });

    const walletContract = await Wallet.at(wallet);
    assert.isTrue(await walletContract.owners(user1));
    assert.equal(await web3.eth.getBalance(recipient), '1000');
  });

});
