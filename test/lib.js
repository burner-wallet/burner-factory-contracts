module.exports.increaseTime = async function(amount) {
  const call = (method, ...params) => new Promise((resolve, reject) =>
    web3.currentProvider.send(
      { method, params, jsonrpc: '2.0', id: new Date().getSeconds() },
      (err, resp) => err ? reject(err) : resolve(resp)));

  await call('evm_increaseTime', amount);
  await call('evm_mine');
};
