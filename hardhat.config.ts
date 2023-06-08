import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require('dotenv').config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');

const {PRIVATE_KEY, ALCHEMY_API_URL, ALCHEMY_MUMBAI_API_URL} = process.env

const config: HardhatUserConfig = {
  defaultNetwork: "polygon_main",
  solidity: "0.8.9",
  networks: {
    mumbai: {
      url: ALCHEMY_MUMBAI_API_URL,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    polygon_main: {
      url: ALCHEMY_API_URL,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    hardhat: {}
  }
};

export default config;
