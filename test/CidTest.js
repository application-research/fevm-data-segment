const { expect } = require("chai");

async function deploy(name) {
    const Contract = await ethers.getContractFactory(name);
    return await Contract.deploy().then(f => f.deployed());
}

describe("Cid Tests", function () {

    before(async function() {
        this.cid = await deploy('Cid');
    });

    describe("Validate Cid", function() {

        it("Should be valid cid from 0", async function() {
            commP = "0x0000000000000000000000000000000000000000000000000000000000000000";//Buffer.from("0000000000000000000000000000000000000000000000000000000000000000", "hex");
            const result = await this.cid.pieceCommitmentToCid(commP);
            const expectedCid = "0x0181e2039220200000000000000000000000000000000000000000000000000000000000000000";  
            expect(result).to.equal(expectedCid);
        });

        // await expect(this.inclusion.computeRoot(testCase.proof, testCase.subtree)).to.be.revertedWith(testCase.err);

        it("Should be valid commP to 0", async function() {
            cid = "0x0181e2039220200000000000000000000000000000000000000000000000000000000000000000";
            const result = await this.cid.cidToPieceCommitment(cid);
            const expectedCommP = "0x0000000000000000000000000000000000000000000000000000000000000000";  
            expect(result).to.equal(expectedCommP);
        });
        
        // 0x3f46bc645b07a3ea2c04f066f939ddf7e269dd77671f9e1e61a3a3797e665127
        it("Should be valid cid", async function() {
            commP = "0x3f46bc645b07a3ea2c04f066f939ddf7e269dd77671f9e1e61a3a3797e665127";
            const result = await this.cid.pieceCommitmentToCid(commP);
            const expectedCid = "0x0181e2039220203f46bc645b07a3ea2c04f066f939ddf7e269dd77671f9e1e61a3a3797e665127";  
            expect(result).to.equal(expectedCid);
        });

        // 0x0181e2039220203f46bc645b07a3ea2c04f066f939ddf7e269dd77671f9e1e61a3a3797e665127
        it("Should be valid commP", async function() {
            cid = "0x0181e2039220203f46bc645b07a3ea2c04f066f939ddf7e269dd77671f9e1e61a3a3797e665127";
            const result = await this.cid.cidToPieceCommitment(cid);
            const expectedCommP = "0x3f46bc645b07a3ea2c04f066f939ddf7e269dd77671f9e1e61a3a3797e665127";  
            expect(result).to.equal(expectedCommP);
        });

        it("Should be invalid length CID", async function() {
            cid = "0x0181e2039220203f46bc645b07a3ea2c04f066f939ddf7e269dd77671f9e1e61a3a3797e66512701";
            await expect(this.cid.cidToPieceCommitment(cid)).to.be.revertedWith("wrong length of CID");
        });

        it("Should be invalid length CID", async function() {
            cid = "0xdeadbeef2020203f46bc645b07a3ea2c04f066f939ddf7e269dd77671f9e1e61a3a3797e665127";
            await expect(this.cid.cidToPieceCommitment(cid)).to.be.revertedWith("wrong content of CID header");
        });
        

    });

});