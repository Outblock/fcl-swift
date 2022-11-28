# FCL Swift

## Overview 

This reference documents all the methods available in the SDK, and explains in detail how these methods work.
SDKs are open source, and you can use them according to the licence.

#### Feature list:
- [x] Sign in/up with Wallet provider
- [x] Configure app
- [x] Query cadence script with arguments
- [x] Send transaction with non-custodial mode (Blocto)
- [x] Send transaction with custodial wallet
- [x] Support all access api endpoint such as `GetAccount` and `GetLastestBlock`
- [x] Sign user message
- [x] Verify user signature
- [x] Account Proof
- [x] Verify account proof

#### Todo list:
- [ ] Support custom `authz` func 

## Getting Started

### Installing

This is a Swift Package, and can be installed via Xcode with the URL of this repository:

```swift
.package(name: "FCL", url: "https://github.com/outblock/fcl-swift.git", from: "0.0.5")
```

## Config

Values only need to be set once. We recommend doing this once and as early in the life cycle as possible. To set a configuration value, the `put` method on the `config` instance needs to be called, the `put` method returns the `config` instance so they can be chained.

```swift
let accountProof = FCL.Metadata.AccountProofConfig(appIdentifier: "xxxx", nonce: "xxxx")
let walletConnect = FCL.Metadata.WalletConnectConfig(urlScheme: "xxxx", projectID: "xxxx")
let metadata = FCL.Metadata(appName: "xxx",
                            appDescription: "xxx",
                            appIcon: URL(string: "xxxx")!,
                            location: URL(string: "xxx")!,
                            accountProof: accountProof,
                            walletConnectConfig: walletConnect)

fcl.config(metadata: metadata,
           env: env,
           provider: provider)

```

### Common Configuration Keys

| Name                            | Example                                              | Description                                                                                                                                                                                    |
| ------------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `accessNode.api` **(required)** | `https://access-testnet.onflow.org`                  | API URL for the Flow Blockchain Access Node you want to be communicating with. See all available access node endpoints [here](https://docs.onflow.org/access-api/#flow-access-node-endpoints). |
| `env`                           | `testnet`                                            | Used in conjunction with stored interactions. Possible values: `local`, `canarynet`, `testnet`, `mainnet`                                                                                      |
| `discovery.wallet` **(required)** | `https://fcl-discovery.onflow.org/testnet/authn`     | Points FCL at the Wallet or Wallet Discovery mechanism.                                                                                                                                        |
| `app.detail.title`              | `Cryptokitties`                                      | Your applications title, can be requested by wallets and other services.                                                                                                                       |
| `app.detail.icon`               | `https://fcl-discovery.onflow.org/images/blocto.png` | Url for your applications icon, can be requested by wallets and other services.                                                                                                                |
| `location` **(required)**       | `https://foo.com`     | Your application's site URL, can be requested by wallets and other services.                                                                                                                |
| `challenge.handshake`           | **DEPRECATED**                                       | Use `discovery.wallet` instead.                                                                                                                                                               |

### Address replacement in scripts and transactions

Configuration keys that start with `0x` will be used to find-and-replace their values in Cadence scripts and transactions input to FCL. Typically this is used to represent account addresses. Account addresses for the same contract will be different depending on the Flow network you're interacting with (eg. Testnet, Mainnet).
This allows you to write your script or transaction once and not have to update code when you point your application at a different Flow network.

```swift

fcl.config
    .put(key: "0xFungibleToken", value: "0xf233dcee88fe0abe")
    .put(key: "0xFUSD", value: "0x3c5959b568896393")


fcl.query {
    cadence {
        """
        import FungibleToken from 0xFungibleToken
        import FUSD from 0xFUSD

        pub fun main(account: Address): UFix64 {
          let receiverRef = getAccount(account).getCapability(/public/fusdBalance)!
            .borrow<&FUSD.Vault{FungibleToken.Balance}>()

          return receiverRef!.balance
        }
        """
    }

    arguments {
        [.address(Flow.Address(hex: address))]
    }
}
```

# Wallet Interactions

These methods allows dapps to interact with FCL compatible wallets in order to authenticate the user and authorize transactions on their behalf.

### Methods

## `authenticate`

Calling this method will authenticate the current user via any wallet that supports FCL. Once called, FCL will initiate communication with the configured `authn` endpoint which lets the user select a wallet to authenticate with. Once the wallet provider has authenticated the user, FCL will set the values on the [current user](#currentuserobject) object for future use and authorization.


#### Usage

```swift
let accountProof = FCL.Metadata.AccountProofConfig(appIdentifier: "xxxx", nonce: "xxxx")
let walletConnect = FCL.Metadata.WalletConnectConfig(urlScheme: "xxxx", projectID: "xxxx")
let metadata = FCL.Metadata(appName: "xxx",
                            appDescription: "xxx",
                            appIcon: URL(string: "xxxx")!,
                            location: URL(string: "xxx")!,
                            accountProof: accountProof,
                            walletConnectConfig: walletConnect)
let provider: FCL.Provider = .lilico
fcl.config(metadata: metadata,
           env: env,
           provider: provider)

fcl.authenticate()
```

## `authz`

A **convenience method** that produces the needed authorization details for the current user to submit transactions to Flow. It defines a signing function that connects to a user's wallet provider to produce signatures to submit transactions.


#### Usage

**Note:** The default values for `proposer`, `payer`, and `authorizations` are already `fcl.authz` so there is no need to include these parameters, it is shown only for example purposes. See more on [signing roles](https://docs.onflow.org/concepts/accounts-and-keys/#signing-a-transaction).

```swift

try await fcl.mutate(cadence: 
                    """
                       transaction(test: String, testInt: Int) {
                           prepare(signer: AuthAccount) {
                                log(signer.address)
                                log(test)
                                log(testInt)
                           }
                       }
                    """,
                    args: [.string("Test2"), .int(1)])
```

---

# On-chain Interactions

> 📣 **These methods can be used in browsers and NodeJS.**

These methods allows dapps to interact directly with the Flow blockchain via a set of functions that currently use the [Access Node API](https://docs.onflow.org/access-api/).

### Methods

---

### Query and Mutate Flow with Cadence

If you want to run arbitrary Cadence scripts on the blockchain, these methods offer a convenient way to do so **without having to build, send, and decode interactions**.

## `query`

Allows you to submit scripts to query the blockchain.

#### Options

_Pass in the following as a single object with the following keys.All keys are optional unless otherwise stated._

| Key       | Type                                  | Description                                                                                                                                                                                                            |
| --------- | ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cadence` | string **(required)**                 | A valid cadence script.                                                                                                                                                                                                |
| `arguments`    | [ArgumentFunction](#argumentfunction) | Any arguments to the script if needed should be supplied via a function that returns an array of arguments.                                                                                                            |
| `gasLimit`   | number                                | Compute (Gas) limit for query. Read the [documentation about computation cost](https://docs.onflow.org/flow-go-sdk/building-transactions/#gas-limit) for information about how computation cost is calculated on Flow. |

#### Returns

| Type | Description                            |
| ---- | -------------------------------------- |
| Flow.ScriptResponse  | A model representation of the response. |

#### Usage

```swift
fcl.query {
    cadence {
        """
        pub fun main(a: Int, b: Int, addr: Address): Int {
            log(addr)
            return a + b
        }
        """
    }

    arguments {
        [.int(7), .int(6), .address(Flow.Address(hex: "0x01"))]
    }
}
```

## `mutate`

Allows you to submit transactions to the blockchain to potentially mutate the state.

⚠️When being used in the browser, `fcl.mutate` uses the built-in `fcl.authz` function to produce the authorization (signatures) for the current user. When calling this method from Node.js, you will need to supply your own custom authorization function.

#### Options

_Pass in the following as a single object with the following keys. All keys are optional unless otherwise stated._

| Key        | Type                                            | Description                                                                                                                                                                                                            |
| ---------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cadence`  | string **(required)**                           | A valid cadence transaction.                                                                                                                                                                                           |
| `arguments`     | [ArgumentFunction](#argumentfunction)           | Any arguments to the script if needed should be supplied via a function that returns an array of arguments.                                                                                                            |
| `gasLimit`    | number                                          | Compute (Gas) limit for query. Read the [documentation about computation cost](https://docs.onflow.org/flow-go-sdk/building-transactions/#gas-limit) for information about how computation cost is calculated on Flow.                                                                               |

#### Returns

| Type   | Description         |
| ------ | ------------------- |
| string | The transaction ID. |

#### Usage

```swift

try await fcl.mutate(cadence: 
                    """
                       transaction(test: String, testInt: Int) {
                           prepare(signer: AuthAccount) {
                                log(signer.address)
                                log(test)
                                log(testInt)
                           }
                       }
                    """,
                    args: [.string("Test2"), .int(1)])

```

## `getBlock`

A builder function that returns the interaction to get the latest block.

📣 Use with `fcl.atBlockId()` and `fcl.atBlockHeight()` when building the interaction to get information for older blocks.

⚠️Consider using the pre-built interaction [`fcl.latestBlock(isSealed)`](#latestblock) if you do not need to pair with any other builders.

#### Arguments

| Name       | Type    | Default | Description                                                                    |
| ---------- | ------- | ------- | ------------------------------------------------------------------------------ |
| `sealed` | boolean | true   | If the latest block should be sealed or not. See [block states](#interaction). |

#### Returns after decoding

| Type                          | Description                                           |
| ----------------------------- | ----------------------------------------------------- |
| [BlockObject](#blockobject) | The latest block if not used with any other builders. |

#### Usage

```swift
fcl.getLastestBlock()
```

## TODO: Add more example 
