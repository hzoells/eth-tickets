import { ethers } from "hardhat";

interface ContractInfo {
  name: string
  address: string
}

const contracts = ['Market', 'Tickets', 'VerifiedMinter']

async function main() {
  const infoItems: ContractInfo[] = []
  contracts.forEach(async contractName => {
    const factory = await ethers.getContractFactory("Lock")
    const contract = await factory.deploy();
    await contract.deployed()

    infoItems.push({
      name: contractName,
      address: contract.address,
    })
  })

  infoItems.forEach(({name, address}) => {
    console.log(`${name} deployed to ${address}`)
  })
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
