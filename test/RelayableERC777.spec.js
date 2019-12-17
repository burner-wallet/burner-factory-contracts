const TestRelayableERC777 = artifacts.require('TestRelayableERC777');
const { GSNProvider } = require("@openzeppelin/gsn-provider");
const { startRelay } = require('./lib');

contract('RelayableERC777', ([account1]) => {
  let relayProcess;
  before(async () => {
    relayProcess = await startRelay(account1);
  });

  after(() => relayProcess.kill());

  afterEach(() => TestRelayableERC777.setProvider(web3.currentProvider));

  it('Should relay a token transfer', async () => {
    const token = await TestRelayableERC777.new();
    await token.depositForRelay({ value: web3.utils.toWei('0.5', 'ether'), from: account1 });

    const gsnAccount = web3.eth.accounts.create();

    await token.transfer(gsnAccount.address, '1000');

    const gsnProvider = new GSNProvider(web3.currentProvider, { signKey: gsnAccount.privateKey });
    TestRelayableERC777.setProvider(gsnProvider);

    await token.transfer('0x0000000000000000000000000000000000000001', '100', {
      gas: 1000000,
      from: gsnAccount.address,
    });

    assert.equal(await token.balanceOf(gsnAccount.address), '900');
  });
});
