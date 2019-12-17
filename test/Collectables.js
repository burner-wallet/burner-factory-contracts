const Collectables = artifacts.require('Collectables');
const { GSNProvider } = require('@openzeppelin/gsn-provider');
const { startRelay } = require('./lib');

contract('Collectables', function([admin, user1]) {
  let relayProcess;
  before(async () => {
    relayProcess = await startRelay(admin);
  });

  after(() => relayProcess.kill());

  afterEach(() => Collectables.setProvider(web3.currentProvider));

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

  it("should pay gas costs using GSN", async () => {
    const contract = await Collectables.new("Test Token", "TEST", "https://test.com/", {
      from: admin,
      value: web3.utils.toWei('0.1', 'ether'),
    });
    await contract.mint(admin, '100');

    const gsnAccount = web3.eth.accounts.create();

    const gsnProvider = new GSNProvider(web3.currentProvider, { signKey: gsnAccount.privateKey });
    Collectables.setProvider(gsnProvider);

    await contract.clone(gsnAccount.address, '1', {
      gas: 1000000,
      from: gsnAccount.address,
    });

    assert.equal(await contract.getClonedTokenByAddress(gsnAccount.address, '1'), '2');
  });
});
