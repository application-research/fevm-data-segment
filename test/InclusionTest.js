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

/*
async function deploy(name) {
    const Contract = await ethers.getContractFactory(name);
    return await Contract.deploy().then(f => f.deployed());
}
*/

describe("Inclusion Tests", function () {

    before(async function() {
        this.inclusion = await deploy('Proof');
    });

    describe("Validate Proof", function() {

        it("Should be valide proof", async function() {
            const subtree = { 
                data: "0x0100000000000000000000000000000000000000000000000000000000000000",
            };
            const proof = {
                index: 0,
                path: [
                    { data: "0x0200000000000000000000000000000000000000000000000000000000000000"},
                    { data: "0x0300000000000000000000000000000000000000000000000000000000000000"},
                ],
            };
            const root = { data: "0xaa9627470b129fab0db1260da80065a1bdd31b4acc4c79121f2e1ba8487d1f30", }

            expect(await this.inclusion.verify(proof, root, subtree)).to.equal(true)
        });

    });

    describe("Compute Node", function() {

        it("Should compute the correct Node", async function () {
            // Define the input data for the function
            const left = { data: "0x0100000000000000000000000000000000000000000000000000000000000000"};
            const right = { data: "0x0200000000000000000000000000000000000000000000000000000000000000"};
    
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
                        data: "0x0100000000000000000000000000000000000000000000000000000000000000",
                    }, 
                    proof: {
                        index: 0,
                        path: [
                            { data: "0x0200000000000000000000000000000000000000000000000000000000000000"},
                            { data: "0x0300000000000000000000000000000000000000000000000000000000000000"},
                        ],
                    },
                    expectedRoot: "0xaa9627470b129fab0db1260da80065a1bdd31b4acc4c79121f2e1ba8487d1f30",
                },
                {        
                    subtree: { 
                        data: "0x0100000000000000000000000000000000000000000000000000000000000000",
                    }, 
                    proof: {
                        index: 1,
                        path: [
                            { data: "0x0200000000000000000000000000000000000000000000000000000000000000"},
                            { data: "0x0300000000000000000000000000000000000000000000000000000000000000"},
                        ],
                    },
                    expectedRoot: "0x475a9798af48c5362833cd6451a8fa8a5f4f4c1ce61d3acbd4f5c7300fe10e06",
                },
                {        
                    subtree: { 
                        data: "0xff00000000000000000000000000000000000000000000000000000000000000",
                    }, 
                    proof: {
                        index: 1,
                        path: [
                            { data: "0x0200000000000000000000000000000000000000000000000000000000000000"},
                            { data: "0x0300000000000000000000000000000000000000000000000000000000000000"},
                        ],
                    },
                    expectedRoot: "0xfdb37aef9d22cecdc058c99ebf94a34ce165882b1e2d3a8156ae02222dde8a28",
                },
                {        
                    subtree: { 
                        data: "0x0100000000000000000000000000000000000000000000000000000000000000",
                    }, 
                    proof: {
                        index: 3,
                        path: [
                            { data: "0x0200000000000000000000000000000000000000000000000000000000000000"},
                            { data: "0x0300000000000000000000000000000000000000000000000000000000000000"},
                        ],
                    },
                    expectedRoot: "0xd4716caf3fa701ea26962e53047167bb25b038138fb651fbff0ed21d9b1c8822",
                },

                {        
                    subtree: { 
                        data: "0x0100000000000000000000000000000000000000000000000000000000000000",
                    }, 
                    proof: {
                        index: 4,
                        path: [
                            { data: "0x0200000000000000000000000000000000000000000000000000000000000000"},
                            { data: "0x0300000000000000000000000000000000000000000000000000000000000000"},
                        ],
                    },
                    err:     "index greater than width of the tree",
                },
                {        
                    subtree: { 
                        data: "0x0100000000000000000000000000000000000000000000000000000000000000",
                    }, 
                    proof: {
                        index: 8,
                        path: [
                            { data: "0x0200000000000000000000000000000000000000000000000000000000000000"},
                            { data: "0x0300000000000000000000000000000000000000000000000000000000000000"},
                            { data: "0x0400000000000000000000000000000000000000000000000000000000000000"},
                        ],
                    },
                    err:     "index greater than width of the tree",
                },
                {        
                    subtree: { 
                        data: "0x0100000000000000000000000000000000000000000000000000000000000000",
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
        it("Should compute the expected Aux Data", async function () {
            verifData = {
                // commPc: "0x0181e2039220200d0e0a0100030000000000000000000000000000000000000000000000000000"),
                commPc: "0x0181e2039220200d0e0a0100030000000000000000000000000000000000000000000000000000",
                sizePc: 0x20000000,
            }

            incProof = {
                proofSubtree: {
                    index: 0x5,
                    path: [
                        { data: "0x0d0e0a0100020000000000000000000000000000000000000000000000000000"},
                        { data: "0x0d0e0a0100040000000000000000000000000000000000000000000000000000"},
                        { data: "0xb6a5c5d0cbaabd7e63de256c819d84623fde6f53d616120508667b12659f7c3e"},
                        { data: "0x2df9cf74cb24e6349b809399b3a046640219dce8b97954eec43bf605dcc59b2d"},
                        { data: "0xd8610218425ab5e95b1ca6239d29a2e420d706a96f373e2f9c9a91d759d19b01"},
                        { data: "0xd628c4e101d5ca9aa4b341e4d0f028be8636fd7a0c3bf691cef16113b8d97932"},
                    ],
                },

                proofIndex: {
                    index: 0x1ffc0003,
                    path: [
                        { data: "0xca99a41370d2dd04f7d97b0fed8a9833031291a6f7c825d7245b428fef8b2734"},
                        { data: "0x2bc4f6cafd6a8366d032dfc7fceefd0ff2fb34dd2ea910da454773057333dd2a"},
                        { data: "0x578b81a6596624f326b1d31e2e3db91062545d2f819d605cc4afef3377151800"},
                        { data: "0x0e067c9486c9d41ff6cfeaf2d4b330d432e6aefa18eacbb5ce072ca197760215"},
                        { data: "0x1f7ac9595510e09ea41c460b176430bb322cd6fb412ec57cb17d989a4310372f"},
                        { data: "0xfc7e928296e516faade986b28f92d44a4f24b935485223376a799027bc18f833"},
                        { data: "0x08c47b38ee13bc43f41b915c0eed9911a26086b3ed62401bf9d58b8d19dff624"},
                        { data: "0xb2e47bfb11facd941f62af5c750f3ea5cc4df517d5c4f16db2b4d77baec1a32f"},
                        { data: "0xf9226160c8f927bfdcc418cdf203493146008eaefb7d02194d5e548189005108"},
                        { data: "0x2c1a964bb90b59ebfe0f6da29ad65ae3e417724a8f7c11745a40cac1e5e74011"},
                        { data: "0xfee378cef16404b199ede0b13e11b624ff9d784fbbed878d83297e795e024f02"},
                        { data: "0x8e9e2403fa884cf6237f60df25f83ee40dca9ed879eb6f6352d15084f5ad0d3f"},
                        { data: "0x752d9693fa167524395476e317a98580f00947afb7a30540d625a9291cc12a07"},
                        { data: "0x7022f60f7ef6adfa17117a52619e30cea82c68075adf1c667786ec506eef2d19"},
                        { data: "0xd99887b973573a96e11393645236c17b1f4c7034d723c7a99f709bb4da61162b"},
                        { data: "0xd0b530dbb0b4f25c5d2f2a28dfee808b53412a02931f18c499f5a254086b1326"},
                        { data: "0x84c0421ba0685a01bf795a2344064fe424bd52a9d24377b394ff4c4b4568e811"},
                        { data: "0x65f29e5d98d246c38b388cfc06db1f6b021303c5a289000bdce832a9c3ec421c"},
                        { data: "0xa2247508285850965b7e334b3127b0c042b1d046dc54402137627cd8799ce13a"},
                        { data: "0xdafdab6da9364453c26d33726b9fefe343be8f81649ec009aad3faff50617508"},
                        { data: "0xd941d5e0d6314a995c33ffbd4fbe69118d73d4e5fd2cd31f0f7c86ebdd14e706"},
                        { data: "0x514c435c3d04d349a5365fbd59ffc713629111785991c1a3c53af22079741a2f"},
                        { data: "0xad06853969d37d34ff08e09f56930a4ad19a89def60cbfee7e1d3381c1e71c37"},
                        { data: "0x39560e7b13a93b07a243fd2720ffa7cb3e1d2e505ab3629e79f46313512cda06"},
                        { data: "0xccc3c012f5b05e811a2bbfdd0f6833b84275b47bf229c0052a82484f3c1a5b3d"},
                        { data: "0x7df29b69773199e8f2b40b77919d048509eed768e2c7297b1f1437034fc3c62c"},
                        { data: "0x66ce05a3667552cf45c02bcc4e8392919bdeac35de2ff56271848e9f7b675107"},
                        { data: "0xd8610218425ab5e95b1ca6239d29a2e420d706a96f373e2f9c9a91d759d19b01"},
                        { data: "0xd0eef6d1bccabc5b5b9e3af2fea8ea9d184f08f43ac2071bdc635d44bbe35115"},
                    ],
                },
            }

            expectedAux = {
                commPa: "0x0181e2039220203f46bc645b07a3ea2c04f066f939ddf7e269dd77671f9e1e61a3a3797e665127",
                sizePa: 0x800000000
            }

            // console.log(incProof, verifData, expectedAux);

            const result = await this.inclusion.computeExpectedAuxData(incProof, verifData);

            console.log(result.commPa);
            // expect(result.commPa).to.equal(expectedAux.commPa);
        });

    });
});