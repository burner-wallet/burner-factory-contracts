const { deployRelayHub } = require('@openzeppelin/gsn-helpers');
const { singletons } = require('@openzeppelin/test-helpers');
const TestVendingMachine = artifacts.require('TestVendingMachine');
const VendableToken = artifacts.require('VendableToken');

const HALF_ETH = web3.utils.toWei('0.5', 'ether');
const ONE_ETH = web3.utils.toWei('1', 'ether');

contract('VendingMachine', ([account1, account2]) => {
  before(async () => {
    await Promise.all([
      singletons.ERC1820Registry(account1),
      deployRelayHub(web3, { from: account1 }),
    ]);
  });

  it('should deposit and withdraw eth for relay', async () => {
    const vendingMachine = await TestVendingMachine.new({
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
    const vendingMachine = await TestVendingMachine.new();

    const token = await VendableToken.at(await vendingMachine.token());

    await web3.eth.sendTransaction({
      to: await vendingMachine.relayFundingAddress(),
      value: HALF_ETH,
      from: account1,
      gasLimit: 400000,
    });

    assert.equal(await token.getRecipientBalance(), HALF_ETH);
  });
});
