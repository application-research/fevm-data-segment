const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const createKeccakHash = require('keccak');
const { expect } = require("chai");
const web3 = require('web3')
const crypto = require('crypto');
const { bufferToHex, toBuffer } = require('ethereumjs-util');
const {toBN, toHex, hexToBytes, padEnd} = require('web3-utils');

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
        const leaf = web3.utils.sha3('G');
        const proof = merkleTree.getHexProof(leaf);

        console.log("root : " + root);
        console.log("leaf : " + leaf);
        console.log("proof : " + proof);
        
        expect(await this.inclusion.verify(root, keccak256('g'), proof)).to.not.equal(true);
    });

    it("Compute Root", async function () {

        //  subtree: Node{0x1},
		// 	path:    []Node{{0x2}, {0x3}},
		// 	index:   0,
		// 	root: Node{
		// 		0xaa, 0x96, 0x27, 0x47, 0xb, 0x12, 0x9f, 0xab, 0xd, 0xb1, 0x26, 0xd, 0xa8, 0x0,
		// 		0x65, 0xa1, 0xbd, 0xd3, 0x1b, 0x4a, 0xcc, 0x4c, 0x79, 0x12, 0x1f, 0x2e, 0x1b, 0xa8,
		// 		0x48, 0x7d, 0x1f, 0x30},

        const proof = {
            index: 0,
            path: [
              "0x0200000000000000000000000000000000000000000000000000000000000000",
              "0x0300000000000000000000000000000000000000000000000000000000000000",
            ],
        };
          
        const subtree = "0x0100000000000000000000000000000000000000000000000000000000000000";
        const expectedRoot = "0xaa9627470b129fab0db1260da80065a1bdd31b4acc4c79121f2e1ba8487d1f30";  

        const computeRoot = await this.inclusion.computeRoot(proof, subtree);
        
        expect(computeRoot).to.equal(expectedRoot);
    });

});