task(
    "store-data",
    "Stores data on an Edge-UR Node, and Filecoin"
  )
    .addParam("contract", "The address of the deal client solidity")
    .addParam("uri", "The uri of the data to store")
    .setAction(async (taskArgs) => {
        //store taskargs as useable variables
        //convert piece CID string to hex bytes
        const contractAddr = taskArgs.contract
        const uri = taskArgs.uri

        const networkId = network.name
        console.log("Making deal proposal on network", networkId)

        //create a new wallet instance
        const wallet = new ethers.Wallet(network.config.accounts[0], ethers.provider)
        
        //create a EdgeURContract contract factory
        const EdgeURContract = await ethers.getContractFactory("EdgeURContract", wallet)
        //create a EdgeURContract contract instance 
        //this is what you will call to interact with the deployed contract
        const edgeURContract = await EdgeURContract.attach(contractAddr)
        
        //send a transaction to call makeDealProposal() method
        transaction = await edgeURContract.StoreURI(uri)
        transactionReceipt = await transaction.wait()

        //listen for DealProposalCreate event
        //const event = transactionReceipt.events[0].topics[1]
        console.log("Complete! Event Emitted. ProposalId is:", transactionReceipt)
    })
