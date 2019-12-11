const Wallet = artifacts.require('Wallet');

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

contract('Wallet', ([admin, user1, user2, user3]) => {
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

  it('should validate signatures using ERC1271', async () => {
    const wallet = await Wallet.new(admin, user1, { from: user1 });
    const data = sha3('Test');
    const signature = fixSignature(await web3.eth.sign(data, user1));

    assert.equal(await wallet.isValidSignature(data, signature), '0x20c13b0b');
  });
});
