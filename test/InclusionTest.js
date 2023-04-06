const { expect } = require("chai");

async function deploy(name) {
    const Cid = await ethers.getContractFactory("Cid");
    const cid = await Cid.deploy();

    const Contract = await ethers.getContractFactory(name, {
        libraries: {
            Cid: cid.address,
        },
    });
    return await Contract.deploy().then(f => f.deployed());
}

describe("Inclusion Tests", function () {

    before(async function() {
        this.inclusion = await deploy('Proof');
    });

    describe("Validate Proof", function() {

        it("Should be valide proof", async function() {
            const subtree = { 
                data: Buffer.from("0100000000000000000000000000000000000000000000000000000000000000", "hex") 
            };
            const proof = {
                index: 0,
                path: [
                    { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") },
                    { data: Buffer.from("0300000000000000000000000000000000000000000000000000000000000000", "hex") },
                ],
            };
            const root = { data: Buffer.from("aa9627470b129fab0db1260da80065a1bdd31b4acc4c79121f2e1ba8487d1f30", "hex") }

            expect(await this.inclusion.verify(proof, root, subtree)).to.equal(true)
        });

    });

    describe("Compute Node", function() {

        it("Should compute the correct Node", async function () {
            // Define the input data for the function
            const left = { data: Buffer.from("0100000000000000000000000000000000000000000000000000000000000000", "hex") };
            const right = { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") };
    
            const result = await this.inclusion.computeNode(left, right);
            const expectedMerge = "0xff55c97976a840b4ced964ed49e3794594ba3f675238b5fd25d282b60f70a114";  
            expect(result.data).to.equal(expectedMerge);
        });

    });

    describe("Compute Root", function() {

        it("Should compute the correct Merkle roots", async function () {
            const tt = [
                {        
                    subtree: { 
                        data: Buffer.from("0100000000000000000000000000000000000000000000000000000000000000", "hex") 
                    }, 
                    proof: {
                        index: 0,
                        path: [
                            { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") },
                            { data: Buffer.from("0300000000000000000000000000000000000000000000000000000000000000", "hex") },
                        ],
                    },
                    expectedRoot: "0xaa9627470b129fab0db1260da80065a1bdd31b4acc4c79121f2e1ba8487d1f30",
                },
                {        
                    subtree: { 
                        data: Buffer.from("0100000000000000000000000000000000000000000000000000000000000000", "hex") 
                    }, 
                    proof: {
                        index: 1,
                        path: [
                            { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") },
                            { data: Buffer.from("0300000000000000000000000000000000000000000000000000000000000000", "hex") },
                        ],
                    },
                    expectedRoot: "0x475a9798af48c5362833cd6451a8fa8a5f4f4c1ce61d3acbd4f5c7300fe10e06",
                },
                {        
                    subtree: { 
                        data: Buffer.from("ff00000000000000000000000000000000000000000000000000000000000000", "hex") 
                    }, 
                    proof: {
                        index: 1,
                        path: [
                            { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") },
                            { data: Buffer.from("0300000000000000000000000000000000000000000000000000000000000000", "hex") },
                        ],
                    },
                    expectedRoot: "0xfdb37aef9d22cecdc058c99ebf94a34ce165882b1e2d3a8156ae02222dde8a28",
                },
                {        
                    subtree: { 
                        data: Buffer.from("0100000000000000000000000000000000000000000000000000000000000000", "hex") 
                    }, 
                    proof: {
                        index: 3,
                        path: [
                            { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") },
                            { data: Buffer.from("0300000000000000000000000000000000000000000000000000000000000000", "hex") },
                        ],
                    },
                    expectedRoot: "0xd4716caf3fa701ea26962e53047167bb25b038138fb651fbff0ed21d9b1c8822",
                },

                {        
                    subtree: { 
                        data: Buffer.from("0100000000000000000000000000000000000000000000000000000000000000", "hex") 
                    }, 
                    proof: {
                        index: 4,
                        path: [
                            { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") },
                            { data: Buffer.from("0300000000000000000000000000000000000000000000000000000000000000", "hex") },
                        ],
                    },
                    err:     "index greater than width of the tree",
                },
                {        
                    subtree: { 
                        data: Buffer.from("0100000000000000000000000000000000000000000000000000000000000000", "hex") 
                    }, 
                    proof: {
                        index: 8,
                        path: [
                            { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") },
                            { data: Buffer.from("0300000000000000000000000000000000000000000000000000000000000000", "hex") },
                            { data: Buffer.from("0400000000000000000000000000000000000000000000000000000000000000", "hex") },
                        ],
                    },
                    err:     "index greater than width of the tree",
                },
                {        
                    subtree: { 
                        data: Buffer.from("0100000000000000000000000000000000000000000000000000000000000000", "hex") 
                    }, 
                    proof: {
                        index: 8,
                        path: [
                            {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)},
                            {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)},
                            {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)},
                            {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)}, {data: Buffer.alloc(32)},  
                            // 64 nodes in the path
                        ],
                    },
                    err:     "merkleproofs with depths greater than 63 are not supported",
                },
            ]

            for (let i = 0; i < tt.length; i++) {
                const testCase = tt[i];
                if (testCase.err) {
                    await expect(this.inclusion.computeRoot(testCase.proof, testCase.subtree)).to.be.revertedWith(testCase.err);
                } else {
                    const result = await this.inclusion.computeRoot(testCase.proof, testCase.subtree);
                    expect(result.data).to.equal(testCase.expectedRoot);
                }
            }
        });
    });

    describe("Compute Expected Aux Data", function() {

        it("Calculate Assumed Size", async function() {

            // struct InclusionVerifierData {
            //     // Piece Commitment to client's data
            //     // cid.Cid CommPc;
            //     Node commPc; // tmp object type for testing
            //     // SizePc is size of client's data
            //     uint64 SizePc;
            // }
            // const verifyData = {
            //     commPc: { data: Buffer.from("0181e2039220200d0e0a01000300000000000000000000000000000000000000", "hex")},
            //     sizePc: 0x20000000,
            // }
            // const proof = {
            //     proofSubtree: {
            //         index: 0,
            //         path: [
            //             { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") },
            //             { data: Buffer.from("0300000000000000000000000000000000000000000000000000000000000000", "hex") },
            //         ]
            //     },
            //     proofIndex: {
            //         index: 0,
            //         path: [
            //             { data: Buffer.from("0200000000000000000000000000000000000000000000000000000000000000", "hex") },
            //             { data: Buffer.from("0300000000000000000000000000000000000000000000000000000000000000", "hex") },
            //         ]
            //     }
                
            // };

            // const result = await this.inclusion.computeExpectedAuxData(proof, verifyData);
            // console.log(result)
        });
    });
});