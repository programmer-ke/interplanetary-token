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

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
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
