require("hardhat");

module.exports = async function main() {
    // This is just a convenience check
    if (network.name === "hardhat") {
        console.warn(
        "You are trying to deploy a contract to the Hardhat Network, which " +
            "gets automatically created and destroyed every time."
        );
    }

    // ethers is available in the global scope
    const [deployer] = await ethers.getSigners();
    console.log(
        "Deploying the contracts with the account:",
        await deployer.getAddress()
    );

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const accounts = await ethers.getSigners();
    //console.log(accounts[0])

    //console.log("Wallet Ethereum Address:", wallet.address)
    const chainId = network.config.chainId

    //deploy Cid
    const Cid = await ethers.getContractFactory('Cid', accounts[0]);
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
    const Aggregator = await ethers.getContractFactory('EdgeAggregatorOracle', {
        libraries: {
            Cid: cid.address,
        },
    });
    console.log('Deploying EdgeAggregatorOracle...');
    const aggregator = await Aggregator.deploy();
    await aggregator.deployed()
    console.log('EdgeAggregatorOracle deployed to:', aggregator.address);
}
