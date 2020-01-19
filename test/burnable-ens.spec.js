const NameToken = artifacts.require('NameToken');
const BurnableResolver = artifacts.require('BurnableResolver');

const ENSRegistry = artifacts.require("@ensdomains/ens/ENSRegistry.sol");
const PublicResolver = artifacts.require("@ensdomains/resolver/PublicResolver.sol");
const ReverseRegistrar = artifacts.require("@ensdomains/ens/ReverseRegistrar.sol");
const namehash = require('eth-ens-namehash');

const { asciiToHex, sha3 } = web3.utils;

const ZERO_ADDR = '0x' + web3.utils.padRight('0', 40);
const ZERO_NODE = '0x' + web3.utils.padRight('0', 64);

contract('Burnable ENS', ([admin, account1, account2]) => {
  let ens, resolver, reverse;

  before(async () => {
    ens = await ENSRegistry.new();
    resolver = await PublicResolver.new(ens.address);
    reverse = await ReverseRegistrar.new(ens.address, resolver.address);
    await ens.setSubnodeOwner(asciiToHex(0), sha3('eth'), admin);
    await ens.setSubnodeOwner(asciiToHex(0), sha3('reverse'), admin);
    await ens.setSubnodeOwner(namehash.hash('reverse'), sha3('addr'), reverse.address);
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
    const subResolver = await BurnableResolver.at(subResolverAddr);

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

  it('should handle reverse resolution', async () => {
    const token = await NameToken.new(
      ens.address,
      namehash.hash('myburner.eth'),
      'myburner.eth',
      '0',
      '0',
      { from: admin }
    );
    const subResolverAddr = await token.resolver();
    const subResolver = await BurnableResolver.at(subResolverAddr);

    await ens.setSubnodeOwner(namehash.hash('eth'), sha3('myburner'), admin);
    await resolver.setAddr(namehash.hash('myburner.eth'), '60', token.address, { from: admin });
    await ens.setResolver(namehash.hash('myburner.eth'), resolver.address, { from: admin });
    await ens.setSubnodeOwner(namehash.hash('eth'), sha3('myburner'), token.address, { from: admin });

    await token.register('vitalik', { from: account1 });
    await reverse.claimWithResolver(account1, subResolverAddr, { from: account1 });

    // Check reverse
    const reverseNode = namehash.hash(`${account1.substr(2)}.addr.reverse`.toLowerCase());
    assert.equal(await ens.resolver(reverseNode), subResolverAddr);
    assert.equal(await subResolver.name(reverseNode), 'vitalik.myburner.eth');
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

  it('should let a user burn their domain', async () => {
    const token = await NameToken.new(
      ens.address,
      namehash.hash('myburner.eth'),
      'myburner.eth',
      '0',
      '0',
      { from: admin }
    );
    const subResolverAddr = await token.resolver();
    const subResolver = await BurnableResolver.at(subResolverAddr);

    await ens.setSubnodeOwner(namehash.hash('eth'), sha3('myburner'), admin);
    await resolver.setAddr(namehash.hash('myburner.eth'), '60', token.address, { from: admin });
    await ens.setResolver(namehash.hash('myburner.eth'), resolver.address, { from: admin });
    await ens.setSubnodeOwner(namehash.hash('eth'), sha3('myburner'), token.address, { from: admin });

    await token.register('vitalik', { from: account1 });
    await token.burn('1', { from: account1 });

    const vitalikHash = namehash.hash('vitalik.myburner.eth');

    assert.equal(await token.resolveAddress(vitalikHash), ZERO_ADDR);
    assert.equal(await token.reverse(account1), ZERO_NODE);
    assert.equal(await token.name(account1), '');

    assert.equal(await ens.resolver(vitalikHash), subResolverAddr);
    assert.equal(await subResolver.addr(vitalikHash), ZERO_ADDR);
  });
});
