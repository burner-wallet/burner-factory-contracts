const NameToken = artifacts.require('NameToken');
const Resolver = artifacts.require('Resolver');

const ENSRegistry = artifacts.require("@ensdomains/ens/ENSRegistry.sol");
const PublicResolver = artifacts.require("@ensdomains/resolver/PublicResolver.sol");
const namehash = require('eth-ens-namehash');

const { asciiToHex, sha3 } = web3.utils;

contract('Burnable ENS', ([admin, account1, account2]) => {
  let ens, resolver;

  before(async () => {
    ens = await ENSRegistry.new();
    resolver = await PublicResolver.new(ens.address);
    await ens.setSubnodeOwner(asciiToHex(0), sha3('eth'), admin);
  });

  it('should use the nametoken for ENS names', async () => {
    const expirationTime = 5;
    const extensionTime = 3;
    const token = await NameToken.new(
      ens.address,
      namehash.hash('myburner.eth'),
      'myburner.eth',
      expirationTime,
      extensionTime,
      { from: admin }
    );
    const subResolverAddr = await token.resolver();
    const subResolver = await Resolver.at(subResolverAddr);

    await ens.setSubnodeOwner(namehash.hash('eth'), sha3('myburner'), admin);
    await resolver.setAddr(namehash.hash('myburner.eth'), '60', token.address, { from: admin });
    await ens.setResolver(namehash.hash('myburner.eth'), resolver.address, { from: admin });
    await ens.setSubnodeOwner(namehash.hash('eth'), sha3('myburner'), token.address, { from: admin });

    await token.register('vitalik', { from: account1 });

    const vitalikHash = namehash.hash('vitalik.myburner.eth');

    assert.equal(await token.resolveAddress(vitalikHash), account1);
    assert.equal(await token.reverse(account1), vitalikHash);
    assert.equal(await token.name(account1), 'vitalik.myburner.eth');

    assert.equal(await ens.resolver(vitalikHash), subResolverAddr);
    assert.equal(await subResolver.addr(vitalikHash), account1);
  });

  it('should let the owner transfer ENS ownership', async () => {
    const token = await NameToken.new(
      ens.address,
      namehash.hash('transferable.eth'),
      'transferable.eth',
      '0',
      '0',
      { from: admin }
    );

    await ens.setSubnodeOwner(namehash.hash('eth'), sha3('transferable'), token.address, { from: admin });
    await token.transferENSOwnership(account1, { from: admin });
    assert.equal(await ens.owner(namehash.hash('transferable.eth')), account1);
  });
});
