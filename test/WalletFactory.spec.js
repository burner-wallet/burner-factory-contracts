const Wallet = artifacts.require('Wallet');
const WalletFactory = artifacts.require('WalletFactory');

contract('WalletFactory', ([admin, user1]) => {
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
});
