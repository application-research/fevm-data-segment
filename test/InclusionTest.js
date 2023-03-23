const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { expect } = require("chai");

async function deploy(name) {
    const Contract = await ethers.getContractFactory(name);
    return await Contract.deploy().then(f => f.deployed());
}

function createMerkleTree() {      
    const elements = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefhijklmnopqrstuvwxyz0123456789+/='.split('');
    return new MerkleTree(elements, keccak256, { hashLeaves: true, sortPairs: true });
}

describe("Inclusion Tests", function () {

    before(async function() {
        this.inclusion = await deploy('Inclusion');
    });

    it("leaf 'G' is part of root", async function () {
        const merkleTree = createMerkleTree()
        const root = merkleTree.getHexRoot();
        const leaf = keccak256('G');
        const proof = merkleTree.getHexProof(leaf);

        console.log("root : " + root);
        console.log("leaf : " + leaf);
        console.log("proof : " + proof);

        expect(await this.inclusion.verify(root, leaf, proof)).to.equal(true);
    });

    it("leaf 'g' is not part of root", async function () {
        const merkleTree = createMerkleTree()
        const root = merkleTree.getHexRoot();
        const leaf = keccak256('G');
        const proof = merkleTree.getHexProof(leaf);

        console.log("root : " + root);
        console.log("leaf : " + leaf);
        console.log("proof : " + proof);

        expect(await this.inclusion.verify(root, keccak256("g"), proof)).to.equal(false);
    });


});