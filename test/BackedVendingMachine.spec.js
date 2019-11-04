const { deploySingletons } = require('./lib');
const BackedVendingMachine = artifacts.require('BackedVendingMachine');
const VendableToken = artifacts.require('VendableToken');
const Whitelist = artifacts.require('Whitelist');
const { expectRevert } = require('@openzeppelin/test-helpers');

const ONE_ETH = web3.utils.toWei('1', 'ether');
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

contract('BackedVendingMachine', ([admin, account1]) => {
  before(deploySingletons);

  it('should mint and burn tokens for ether', async () => {
    const vendingMachine = await BackedVendingMachine.new(
      'Test', 'TST', web3.utils.toWei('10', 'ether'), '0', ZERO_ADDRESS, { from: admin });
    const token = await VendableToken.at(await vendingMachine.token());

    const tx = { from: account1, value: ONE_ETH, to: vendingMachine.address };
    const gasLimit = await web3.eth.estimateGas(tx);
    const { logs } = await web3.eth.sendTransaction({ ...tx, gasLimit });
    assert.equal(logs.length, 2);
    assert.equal(logs[0].topics[0], web3.utils.keccak256('Minted(address,address,uint256,bytes,bytes)'));
    assert.equal(logs[1].topics[0], web3.utils.keccak256('Transfer(address,address,uint256)'));

    assert.equal(await token.balanceOf(account1), ONE_ETH);

    const { logs: logs2 } = await token.transfer(vendingMachine.address, ONE_ETH, { from: account1 });
    assert.equal(logs2.length, 4);
    assert.equal(logs2[2].event, 'Burned');
  });

  it('should distribute tokens equally');

  it('should not burn tokens from users that aren\'t whitelisted', async () => {
    const whitelist = await Whitelist.new({ from: admin });
    const vendingMachine = await BackedVendingMachine.new(
      'Test', 'TST', web3.utils.toWei('10', 'ether'), '0', whitelist.address, { from: admin });
    const token = await VendableToken.at(await vendingMachine.token());

    const tx = { from: account1, value: ONE_ETH, to: vendingMachine.address };
    const gasLimit = await web3.eth.estimateGas(tx);
    await web3.eth.sendTransaction({ ...tx, gasLimit });

    await expectRevert(
      token.transfer(vendingMachine.address, ONE_ETH, { from: account1 }),
      'Account must be whitelisted',
    );

    await whitelist.setWhitelisted(vendingMachine.address, account1, true, { from: admin });
    
    const { logs: logs2 } = await token.transfer(vendingMachine.address, ONE_ETH, { from: account1 });
    assert.equal(logs2.length, 4);
  });

  it('should let users buy tokens through a forwarding address');
});
