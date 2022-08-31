# BASIN PROTOCOL
###### From Current, by Eucliss

[Twitter](https://twitter.com/Current_GameFi)

## Next Steps

- [x] Deploy to test net ([Rinkeby](https://rinkeby.etherscan.io/address/0xaf77dfb668c78cd79cc2fe3c7767c3e4fe5218aa#code))


### Welcome to Basin

Basin aims to be a decentralized distribution infrastructure project for blockchain assets. The goal of the project is to integrate with blockchain based games and apps to allow for trustless distribution of prizes and payouts.

#### Use Cases:

##### Static
- Ethereum Transfer Portal
    - Distribute packages to a set of users.
- Battlepass / Game item distribution
    - Setup a set of players and rewards to be distributed
    - Distribute rewards based on results of match off chain

## Engineering Details

> We're now using Foundry/Forge for testing, to run the test suite (https://book.getfoundry.sh/):

Requirements (I'm currently using):
```
➜  ~ npm --version
8.12.1
➜  ~ node --version
v18.4.0
➜  ~ npx --version
8.12.1

npm install @openzeppelin/contracts
```


## Quickstart

```sh
git clone git@github.com:eucliss/Basin.git
cd Basin
make
make test
```

## Testing

```
make test
```

or

```
forge test
```

Additional Make commands can be found in the Makefile.
We have built out commands for 
- Testing with gas estimates (test-gas)
- Slither security tooling (slither)
- Prettier formatting (prettier)
- Solhint linting (lint)
- Surya graphing (graph)

# Deploying to a network

Deploying to a network uses the [foundry scripting system](https://book.getfoundry.sh/tutorials/solidity-scripting.html), where you write your deploy scripts in solidity!

## Setup

We'll demo using the Rinkeby testnet. (Go here for [testnet rinkeby ETH](https://faucets.chain.link/).)

You'll need to add the following variables to a `.env` file:

-   `RINKEBY_RPC_URL`: A URL to connect to the blockchain. You can get one for free from [Alchemy](https://www.alchemy.com/). 
-   `PRIVATE_KEY`: A private key from your wallet. You can get a private key from a new [Metamask](https://metamask.io/) account
    -   Additionally, if you want to deploy to a testnet, you'll need test ETH and/or LINK. You can get them from [faucets.chain.link](https://faucets.chain.link/).
-   Optional `ETHERSCAN_API_KEY`: If you want to verify on etherscan

## Deploying

```
make deploy-rinkeby contract=<CONTRACT_NAME>
```

For example:

```
make deploy-rinkeby contract=PriceFeedConsumer
```

This will run the forge script, the script it's running is:

```
@forge script script/${contract}.s.sol:Deploy${contract} --rpc-url ${RINKEBY_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}  -vvvv
```

If you don't have an `ETHERSCAN_API_KEY`, you can also just run:

```
@forge script script/${contract}.s.sol:Deploy${contract} --rpc-url ${RINKEBY_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast 
```

These pull from the files in the `script` folder. 

### Working with a local network

Foundry comes with local network [anvil](https://book.getfoundry.sh/anvil/index.html) baked in, and allows us to deploy to our local network for quick testing locally. 

To start a local network run:

```
make anvil
```

This will spin up a local blockchain with a determined private key, so you can use the same private key each time. 

Then, you can deploy to it with:

```
make deploy-anvil contract=<CONTRACT_NAME>
```

Similar to `deploy-rinkeby`

### Working with other chains

To add a chain, you'd just need to make a new entry in the `Makefile`, and replace `<YOUR_CHAIN>` with whatever your chain's information is. 

```
deploy-<YOUR_CHAIN> :; @forge script script/${contract}.s.sol:Deploy${contract} --rpc-url ${<YOUR_CHAIN>_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv

```

# Security

This framework comes with slither parameters, a popular security framework from [Trail of Bits](https://www.trailofbits.com/). To use slither, you'll first need to [install python](https://www.python.org/downloads/) and [install slither](https://github.com/crytic/slither#how-to-install).

Then, you can run:

```
make slither
```

And get your slither output. 