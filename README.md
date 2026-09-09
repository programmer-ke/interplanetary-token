# Interplanetary Token

Users deposit assets into the vault and receive a share of Rebase
tokens representing their share of funds within the vault.

## Rebase Token Mechanics

- Interest is accrued linearly with time
- Balance is calculated dynamically, i.e. each balance check include
  _would be_ interest on the fly without state changes in the
  contract.
- Actual minting of accrued interest is done during interactions:
  - Depositing more assets
  - Redeeming underlying assets
  - Transfering tokens to another address
  - Bridging tokens to another chain

### Interest Rate Model

- Designed to incentivize early adopters
- Global interest rate is set and can only decrease with time
- Each deposit made by a user locks in the interest rate for that
  deposit as a snapshot of the global interest rate at the time of
  deposit.

### Bridging

See [how bridging works](how_bridging_works.md)

## Development

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

Deploy token and token pool.

```shell
$ forge script script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${RPC_URL} --account ${ACCOUNT} --broadcast
```

Deploy vault.

```shell
$ forge script ./script/Deployer.s.sol:VaultDeployer --rpc-url ${RPC_URL} --account ${ACCOUNT} --broadcast --sig "run(address)" ${REBASE_TOKEN_ADDRESS}
```

Configure pool to allow bridging

```shell
$ forge script ./script/ConfigurePool.s.sol:ConfigurePool --rpc-url ${RPC_URL} --account ${ACCOUNT} --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${LOCAL_POOL_ADDRESS} ${REMOTE_CHAIN_SELECTOR} ${REMOTE_POOL_ADDRESS} ${REMOTE_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
