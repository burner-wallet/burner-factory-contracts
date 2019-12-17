const ENSRegistry = artifacts.require("@ensdomains/ens/ENSRegistry.sol");
const PublicResolver = artifacts.require("@ensdomains/resolver/PublicResolver.sol");
const ReverseRegistrar = artifacts.require("@ensdomains/ens/ReverseRegistrar.sol");
const namehash = require('eth-ens-namehash');

module.exports = async function(deployer, network, [owner]) {
  if (network === 'development') {
      const rootNode = web3.utils.asciiToHex(0);
      await deployer.deploy(ENSRegistry);
      await deployer.deploy(PublicResolver, ENSRegistry.address);
      await deployer.deploy(ReverseRegistrar, ENSRegistry.address, PublicResolver.address);

      const ens = await ENSRegistry.deployed();
      const resolver = await PublicResolver.deployed();
      const reverseResolver = await ReverseRegistrar.deployed();

      await ens.setSubnodeOwner(rootNode, web3.utils.sha3('eth'), owner);
      await ens.setSubnodeOwner(rootNode, web3.utils.sha3('reverse'), owner);
      await ens.setSubnodeOwner(namehash.hash('reverse'), web3.utils.sha3('addr'), reverseResolver.address);
  }
};
