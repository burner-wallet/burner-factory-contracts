const { deploySingletons } = require('./lib');
const VendableToken = artifacts.require('VendableToken');

contract('VendableToken', ([account1, account2]) => {
  before(deploySingletons);

  it('should mint tokens', async () => {
    const token = await VendableToken.new('Test', 'TST', '1000000', [], { from: account1 });
    await token.mint(account2, '100', '0x');

    assert.equal(await token.balanceOf(account2), '100');
  });
});
