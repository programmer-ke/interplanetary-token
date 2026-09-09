# Bridging

## Prerequisites

- Rebase Token and Rebase Token Pool are deployed on both source and
  destination chains, and registered on Chainlink's registry.
- Both source and destination token pools are configured with the peer
  configuration (remote chain selector, pool and token, rate limits)
- Vault is deployed on source chain (allows the user to deposit ETH
  and mint tokens).
- Both Vault and Rebase Token Pool have burn and mint permissions on
  Rebase Token.
- The user has minted rebase tokens by depositing ETH into the vault.

## Process

- User allows the source Chainlink router to spend LINK (for fees) and
  rebase tokens on their behalf
- User initiates bridging by calling the Chainlink router's `ccipSend`
  method
- The router transfers the rebase token amount selected to the source
  token pool
- The router calls pool's `lockOrBurn` method
- The pool burns the token amount destroying them in the source chain and 
  encodes the user's interest rate into the destination data
  - Before burning, any accrued interest will be minted.
- CCIP relays the message to the destination chain. The message includes:
  - the receiving address
  - the amount of rebase token to mint (corresponding to the amount burnt)
  - the encoded interest rate
- In the destination chain, the destination router calls the destination pool's
  `releaseOrMint` method.
- The pool then mints to the receipient address the amount of rebase token to
  mint and updates the recipient's interest rate to the one sent with the
  message.
  
## End State

- The recipient in the destination chain holds rebase tokens and
  continues to earn interest at a rate matching the source chain. This
  allows a user to bridge their tokens across chains while retaining
  their interest rate.
