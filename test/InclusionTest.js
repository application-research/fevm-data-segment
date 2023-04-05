const { expect } = require("chai");

async function deploy(name) {
    const Contract = await ethers.getContractFactory(name);
    return await Contract.deploy().then(f => f.deployed());
}

describe("Inclusion Tests", function () {

    before(async function() {
        this.inclusion = await deploy('Proof');
    });

    it("Should compute the correct Node", async function () {
        // Define the input data for the function
        const left = { data: Buffer.from("0100000000000000000000000000000000000000000000000000000000000000", "hex") };
        const right = { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") };

        const result = await this.inclusion.computeNode(left, right);
        const expectedMerge = "0xff55c97976a840b4ced964ed49e3794594ba3f675238b5fd25d282b60f70a194";  
        expect(result.data).to.equal(expectedMerge);
      });

      
    it("Should compute the correct Merkle root", async function () {
        // Define the input data for the function
        const proof = {
          index: 0,
          path: [
            { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") },
            { data: Buffer.from("0300000000000000000000000000000000000000000000000000000000000000", "hex") },
          ],
        };
        const subtree = { data: Buffer.from("0100000000000000000000000000000000000000000000000000000000000000", "hex") };
        const result = await this.inclusion.computeRoot(proof, subtree);
        const expectedRoot = "0xaa9627470b129fab0db1260da80065a1bdd31b4acc4c79121f2e1ba8487d1f30";  
        expect(result.data).to.equal(expectedRoot);
    });
});