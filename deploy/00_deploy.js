require("hardhat-deploy")
require("hardhat-deploy-ethers")

const { networkConfig } = require("../helper-hardhat-config")


const private_key = network.config.accounts[0]
const wallet = new ethers.Wallet(private_key, ethers.provider)

module.exports = async ({ deployments }) => {
    console.log("Wallet Ethereum Address:", wallet.address)
    const chainId = network.config.chainId

    //deploy Cid
    const Cid = await ethers.getContractFactory('Cid', wallet);
    console.log('Deploying Cid...');
    const cid = await Cid.deploy();
    await cid.deployed()
    console.log('Cid deployed to:', cid.address);

    //deploy Proof
    const Proof = await ethers.getContractFactory('Proof', {
        libraries: {
            Cid: cid.address,
        },
    });
    console.log('Deploying Proof...');
    const proof = await Proof.deploy();
    await proof.deployed()
    console.log('Proof deployed to:', proof.address);

    //deploy Delta Aggregator
    const Aggregator = await ethers.getContractFactory('DeltaAggregatorOracle', {
        libraries: {
            Cid: cid.address,
        },
    });
    console.log('Deploying DeltaAggregatorOracle...');
    const aggregator = await Aggregator.deploy();
    await aggregator.deployed()
    console.log('DeltaAggregatorOracle deployed to:', aggregator.address);
}