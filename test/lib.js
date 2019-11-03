const { deployRelayHub } = require('@openzeppelin/gsn-helpers');
const { singletons } = require('@openzeppelin/test-helpers');

module.exports.increaseTime = async function(amount) {
  const call = (method, ...params) => new Promise((resolve, reject) =>
    web3.currentProvider.send(
      { method, params, jsonrpc: '2.0', id: new Date().getSeconds() },
      (err, resp) => err ? reject(err) : resolve(resp)));

  await call('evm_increaseTime', amount);
  await call('evm_mine');
};

module.exports.deploySingletons = async function deploySingletons() {
  const [account] = await web3.eth.getAccounts();
  await Promise.all([
    singletons.ERC1820Registry(account),
    deployRelayHub(web3, { from: account }),
  ]);
}
