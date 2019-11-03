const { deploySingletons, increaseTime } = require('./lib');
const TestVendingMachine = artifacts.require('TestVendingMachine');
const VendableToken = artifacts.require('VendableToken');

const HALF_ETH = web3.utils.toWei('0.5', 'ether');
const ONE_ETH = web3.utils.toWei('1', 'ether');

contract('VendingMachine', ([account1, account2, account3]) => {
  before(deploySingletons);

  it('should deposit and withdraw eth for relay', async () => {
    const vendingMachine = await TestVendingMachine.new('0', {
      value: web3.utils.toWei('0.5', 'ether'),
      from: account1,
    });

    const token = await VendableToken.at(await vendingMachine.token());

    assert.equal(await vendingMachine.relayDeposits(account1), HALF_ETH);
    assert.equal(await token.getRecipientBalance(), HALF_ETH);
    
    await vendingMachine.depositRelayFunds({ value: HALF_ETH, from: account2 });
    assert.equal(await vendingMachine.relayDeposits(account2), HALF_ETH);
    assert.equal(await token.getRecipientBalance(), ONE_ETH);

    await vendingMachine.withdrawRelayFunds({ from: account1 });

    assert.equal(await vendingMachine.relayDeposits(account1), '0');
    assert.equal(await token.getRecipientBalance(), web3.utils.toWei('0.5', 'ether'));
  });

  it('should deposit through the forwarding address', async () => {
    const vendingMachine = await TestVendingMachine.new('0');

    const token = await VendableToken.at(await vendingMachine.token());

    await web3.eth.sendTransaction({
      to: await vendingMachine.relayFundingAddress(),
      value: HALF_ETH,
      from: account1,
      gasLimit: 400000,
    });

    assert.equal(await token.getRecipientBalance(), HALF_ETH);
  });

  it('should recover tokens after the timeout expires', async () => {
    const vendingMachine = await TestVendingMachine.new('1000');
    const token = await VendableToken.at(await vendingMachine.token());

    token.transfer(account2, '100');

    assert.isFalse(await vendingMachine.canRecover(account2));
    const [lastActivity, time] = await Promise.all([token.lastActivity(account2), vendingMachine.time()]);
    assert.equal(lastActivity.toString(), time.toString());

    await increaseTime('1000');

    assert.isTrue(await vendingMachine.canRecover(account2));
    await vendingMachine.recover(account2, account3, '100');
  });
});
