const Wallet = artifacts.require('Wallet');

contract('WalletFactory', ([admin, user1, user2, user3]) => {
  it('should be able to add and remove owners', async () => {
    const wallet = await Wallet.new(admin, user1, { from: user1 });

    assert.isFalse(await wallet.isOwner(user2));
    await wallet.addOwner(user2, { from: user1 });
    assert.isTrue(await wallet.isOwner(user2));
    await wallet.addOwner(user3, { from: user2 });
    assert.isTrue(await wallet.isOwner(user3));
    await wallet.removeOwner(user2, { from: user3 });
    assert.isFalse(await wallet.isOwner(user2));
  });

  it('should be able to call itself', async () => {
    const wallet = await Wallet.new(admin, user1, { from: user1 });

    const data = wallet.contract.methods.addOwner(user2).encodeABI();
    await wallet.execute(wallet.address, data, '0');

    assert.isTrue(await wallet.isOwner(user2));
  });
});
