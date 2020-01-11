const NameToken = artifacts.require('NameToken');
const Resolver = artifacts.require('Resolver');

const ENSRegistry = artifacts.require("@ensdomains/ens/ENSRegistry.sol");
const PublicResolver = artifacts.require("@ensdomains/resolver/PublicResolver.sol");
const namehash = require('eth-ens-namehash');

const { asciiToHex, sha3 } = web3.utils;

contract('Burnable ENS', ([admin, account1, account2]) => {
  it('should use the nametoken for ENS names', async () => {
    const ens = await ENSRegistry.new();
    const resolver = await PublicResolver.new(ens.address);
    await ens.setSubnodeOwner(asciiToHex(0), sha3('eth'), admin);

    const subdomainHash = namehash.hash('myburner.eth');

    const expirationTime = 5;
    const extensionTime = 3;
    const token = await NameToken.new(ens.address, subdomainHash, expirationTime, extensionTime, { from: admin });
    const subResolverAddr = await token.resolver();
    const subResolver = await Resolver.at(subResolverAddr);

    await ens.setSubnodeOwner(namehash.hash('eth'), sha3('myburner'), admin);
    await resolver.setAddr(subdomainHash, '60', token.address, { from: admin });
    await ens.setResolver(subdomainHash, resolver.address, { from: admin });
    await ens.setSubnodeOwner(namehash.hash('eth'), sha3('myburner'), token.address, { from: admin });

    await token.register(sha3('vitalik'), { from: account1 });

    assert.equal(await ens.resolver(namehash.hash('vitalik.myburner.eth')), subResolverAddr);
    assert.equal(await subResolver.addr(namehash.hash('vitalik.myburner.eth')), account1);
  });
});
