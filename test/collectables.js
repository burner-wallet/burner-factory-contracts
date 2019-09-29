const Collectables = artifacts.require('Collectables');

contract('Collectables', function([admin, user1]) {
  it("should construct contract", async () => {
    const contract = await Collectables.new("Test Token", "TEST", "");
    assert.equal(await contract.name(), "Test Token");
    assert.equal(await contract.symbol(), "TEST");
  });

  it("should mint a token", async () => {
    const contract = await Collectables.new("Test Token", "TEST", "https://test.com/");
    await contract.mint(admin, '100');
    const uri = await contract.tokenURI('1');
    assert.equal(uri, `https://test.com/${contract.address.toLowerCase()}/1`);

    const token = await contract.getCollectablesById('1');
    assert.equal(token.numClonesAllowed, '100');
    assert.equal(token.numClonesInWild, '0');
    assert.equal(token.clonedFromId, '1');
  });

  it("should let a user clone a token", async () => {
    const contract = await Collectables.new("Test Token", "TEST", "https://test.com/");
    await contract.mint(admin, '100');

    await contract.clone(user1, '1', { from: user1 });

    const uri = await contract.tokenURI('2');
    assert.equal(uri, `https://test.com/${contract.address.toLowerCase()}/2`);

    const token = await contract.getCollectablesById('2');
    assert.equal(token.numClonesAllowed, '0');
    assert.equal(token.numClonesInWild, '0');
    assert.equal(token.clonedFromId, '1');

    const original = await contract.getCollectablesById('1');
    assert.equal(original.numClonesInWild, '1');
  });

  it("shouldn't let a user clone a token twice", async () => {
    const contract = await Collectables.new("Test Token", "TEST", "https://test.com/");
    await contract.mint(admin, '100');

    await contract.clone(user1, '1', { from: user1 });

    assert.equal(await contract.getClonedTokenByAddress(user1, '1'), '2');

    await contract.clone(user1, '1').then(() => { throw new Error() }, () => null);
  });
});
