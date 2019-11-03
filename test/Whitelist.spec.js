const Whitelist = artifacts.require('Whitelist');

contract('Whitelist', ([admin, account1, account2, contract]) => {
  it('should let the creator whitelist people', async () => {
    const whitelist = await Whitelist.new({ from: admin });

    assert.isFalse(await whitelist.isWhitelisted(contract, account1));
    await whitelist.setWhitelisted(contract, account1, true, { from: admin });
    assert.isTrue(await whitelist.isWhitelisted(contract, account1));

    await whitelist.setWhitelisted(contract, account1, false, { from: admin });
    assert.isFalse(await whitelist.isWhitelisted(contract, account1));
  });

  it('should let the creator give admin privlages to others');
  it('shouldn\'t let non-admins set whitelists');
  it('should let a contract set it\'s own whitelist');
  it('should allow whitelisting all');
});
