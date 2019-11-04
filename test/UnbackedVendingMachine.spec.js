const { deploySingletons } = require('./lib');
const UnbackedVendingMachine = artifacts.require('UnbackedVendingMachine');
const VendableToken = artifacts.require('VendableToken');
const Whitelist = artifacts.require('Whitelist');
const { expectRevert } = require('@openzeppelin/test-helpers');

const ONE_ETH = web3.utils.toWei('1', 'ether');

contract('UnbackedVendingMachine', ([admin, account1]) => {
  before(deploySingletons);

  it('should let an administrator mint tokens', async () => {
    const whitelist = await Whitelist.new({ from: admin });
    const vendingMachine = await UnbackedVendingMachine.new(
      'Test', 'TST', web3.utils.toWei('10', 'ether'), '0', whitelist.address, { from: admin });
    const token = await VendableToken.at(await vendingMachine.token());

    await whitelist.setWhitelisted(vendingMachine.address, account1, true, { from: admin });

    await vendingMachine.distribute([account1], [ONE_ETH], { from: account1 });

    assert.equal(await token.balanceOf(account1), ONE_ETH);
  });

  it('should not let users mint tokens', async () => {
    const whitelist = await Whitelist.new({ from: admin });
    const vendingMachine = await UnbackedVendingMachine.new(
      'Test', 'TST', web3.utils.toWei('10', 'ether'), '0', whitelist.address, { from: admin });

    await expectRevert(
      vendingMachine.distribute([account1], [ONE_ETH], { from: account1 }),
      'Account must be whitelisted',
    );
  });
});
