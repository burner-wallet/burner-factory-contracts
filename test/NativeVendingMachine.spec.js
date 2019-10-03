const NativeVendingMachine = artifacts.require('NativeVendingMachine');

contract('NativeVendingMachine', ([admin, distributor]) => {
  it('should distribute eth through a contract call', async () => {
    const { address: user1 } = web3.eth.accounts.create();
    const { address: user2 } = web3.eth.accounts.create();
    const { address: user3 } = web3.eth.accounts.create();

    const machine = await NativeVendingMachine.new();
    await machine.distribute([user1, user2, user3], { value: '9001' });
    
    assert.equal(await web3.eth.getBalance(user1), '3000');
    assert.equal(await web3.eth.getBalance(user2), '3000');
    assert.equal(await web3.eth.getBalance(user3), '3000');
  });

  it('should distribute eth to accounts with forwarding address', async () => {
    const { address: user1 } = web3.eth.accounts.create();
    const { address: user2 } = web3.eth.accounts.create();
    const { address: user3 } = web3.eth.accounts.create();

    const machine = await NativeVendingMachine.new();
    const { logs } = await machine.createForwardingAddress([user1, user2, user3]);
    assert.equal(logs.length, 1);
    assert.equal(logs[0].event, 'NewForwardingAddress');
    
    const { forwardingAddress } = logs[0].args;

    const { logs: logs2 } = await web3.eth.sendTransaction({
      from: distributor,
      to: forwardingAddress,
      value: '9001',
      gasLimit: 400000,
    });

    assert.equal(await web3.eth.getBalance(user1), '3000');
    assert.equal(await web3.eth.getBalance(user2), '3000');
    assert.equal(await web3.eth.getBalance(user3), '3000');
  });

  it('should hold funds sent with insufficent gas, to be distributed later', async () => {
    const { address: user1 } = web3.eth.accounts.create();
    const { address: user2 } = web3.eth.accounts.create();
    const { address: user3 } = web3.eth.accounts.create();

    const machine = await NativeVendingMachine.new();
    const { logs } = await machine.createForwardingAddress([user1, user2, user3]);
    assert.equal(logs.length, 1);
    assert.equal(logs[0].event, 'NewForwardingAddress');

    const { forwardingAddress } = logs[0].args;

    const { logs: logs2 } = await web3.eth.sendTransaction({
      from: distributor,
      to: forwardingAddress,
      value: '9001',
      gasLimit: 30000,
    });

    assert.equal(logs2.length);
    assert.equal(logs2[0].topics[0], web3.utils.keccak256('ForwardPending()'));

    assert.equal(await web3.eth.getBalance(user1), '0');
    assert.equal(await web3.eth.getBalance(user2), '0');
    assert.equal(await web3.eth.getBalance(user3), '0');

    const { logs: logs3 } = await web3.eth.sendTransaction({
      from: admin,
      to: forwardingAddress,
      gasLimit: 400000,
    });

    assert.equal(await web3.eth.getBalance(user1), '3000');
    assert.equal(await web3.eth.getBalance(user2), '3000');
    assert.equal(await web3.eth.getBalance(user3), '3000');
  });
});
