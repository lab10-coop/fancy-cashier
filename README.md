## About

Implements a virtual cashier which knows some special tricks.  

When being set up, a _payment token_, a _discount token_ and a _payment policy_ are set (can later be changed by the contract owner).  

When receiving a payment, the contract checks if the payer owns some discount tokens.  
If so and if the payer has given permission to the contract to withdraw discount tokens (via the ERC20 allowance mechanism), discount tokens are withdrawn and some of the original amount is refunded.  
This all happens in the context of the payment transaction, made possible by the ERC677 hook (which [bridged ERC20 tokens on ARTIS](https://github.com/lab10-coop/artis-bridge-contracts/blob/ARTIS/contracts/ERC677BridgeToken.sol) implement by default).  
Also, if the payment token is an instance of a [BasicStreamingToken](https://github.com/lab10-coop/streaming-token-contracts/blob/master/contracts/BasicStreamingToken.sol), the contract configures itself as _MultiReceiver_ with it.  

The _payment policy_ defines constraints (e.g. a minimum payment price) and the discount model.  
It is implemented in a dedicated contract and can be changed by the contract owner at any time - as long as the new policy fits the interface `IPaymentPolicy`.  

For more details, see `contracts/FancyCashier.sol`, 

## Deployments

### [ARTIS tau1](https://github.com/lab10-coop/tau1): lab10 drinks test

Cashier deployed at [0x44E4591881Ee8326D687EDcf7a698d13dA2a76d3](https://explorer.tau1.artis.network/address/0x44E4591881Ee8326D687EDcf7a698d13dA2a76d3/transactions).  
Initial config:
* Payment Token: [SFAU](https://explorer.tau1.artis.network/address/0xf6ef10e21166cf2e33db070affe262f90365e8d4/transactions) (can be fetched on Rinkeby [via this faucet](https://erc20faucet.com/) and then moved to tau1 [via this bridge](http://fau-bridge.tau1.artis.network/)).
* Discount Token: [lab10 token test](https://explorer.tau1.artis.network/address/0xcda2762a1676eb3d47c3f7cb541abe1c445b9347/transactions)
* Payment Policy: [0xdb45D532971d93a648fB08496ce531C3c4Ec73aB](https://explorer.tau1.artis.network/address/0xdb45D532971d93a648fB08496ce531C3c4Ec73aB/transactions) - instance of `Lab10DrinksPaymentPolicy`

Deployment log:
```
truffle(tau1_rpc)> l10Policy = await Lab10DrinksPaymentPolicy.new()
truffle(tau1_rpc)> fc = await FancyCashier.new("0xF6eF10E21166cf2e33DB070AFfe262F90365e8D4", "0xcda2762a1676eb3d47c3f7cb541abe1c445b9347", l10Policy.address)
```

In order to generate a single file containing all code required by the contract (useful e.g. for uploading to a Block Explorer), run:   
```
npm run flatten
```

## Detection

Wallet apps can detect if an account/contract is an instance of FancyCashier by doing an ERC165 query for interface id `0x85a14f6d`.  
Example for how to do that with web3.js: 
```
  public async supportsInterface(address, interfaceID) {
    if (await web3.eth.getCode(address) === '0x') {
      return false; // not a contract
    }
    const contract = new web3.eth.Contract(ERC165Abi, address);
    try {
      return (await contract.methods.supportsInterface(interfaceID).call()) === true;
    } catch (e) {
      return false;
    }
  }

  const isAFancyCashier = await supportsInterface(address, '0x85a14f6d');
```
