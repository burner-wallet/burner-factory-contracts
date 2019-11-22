const Wallet = artifacts.require('Wallet');
const WalletFactory = artifacts.require('WalletFactory');

contract('WalletFactory', ([admin, user1]) => {
  it('should generate a wallet using create2', async () => {
    const factory = await WalletFactory.new({ from: admin });

    const walletAddress = await factory.getAddress(user1);
    console.log(walletAddress);

    await factory.createWallet(user1, { from: user1 });

    const wallet = await Wallet.at(walletAddress);

    assert.equal(await wallet.creator(), user1);
  });
});
