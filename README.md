# NFT Tickets
- Step 1 - Create an event NFT (Tickets.mintEvent)
- Step 2 - Mint tickets to your event as needed (Tickets.mintTickets)
- Step 3 - Transfer tickets to the market contract for sales (Market.createDeal) Set your price and profit sharing as needed.
- Step 4 - If desired, have ticket holders validate their tickets before the event (Tickets.useTicket)

# NFT 3d Models
- Step 1 - Approve a minter as the contract owner (VerifiedMinter.addMintOpportunity). Set price, tokenURI, profit sharing as needed.
- Step 2 - Minter mints available NFT (VerifiedMinter.mint)
