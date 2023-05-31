const axios = require('axios');
const { ethers } = require('hardhat');

async function main() {

  // Get args
  const rpcEndpoint = process.argv[2]; // http://127.0.0.1:1234/rpc/v1
  const apiEndpoint = process.argv[3];
  const contractAddress = process.argv[4];

  // Create a new ethers provider
  const provider = new ethers.providers.JsonRpcProvider(rpcEndpoint);

  // Compile the contract
  const contractName = 'EdgeURContract';
  
  const contractFactory = await ethers.getContractFactory(contractName);
  const contract = await contractFactory.attach(contractAddress)

  console.log("Listening for events on contract at address:", contractAddress);
  const contractABI = contract.interface.abi;

  // Specify the event name you want to listen to
  const eventName = 'SubmitAggregatorRequest(uint256,bytes)';

  // Specify the HTTP API endpoint and the POST request payload

  // Create an event filter
  const eventFilter = {
    address: contractAddress,
    topics: [ethers.utils.id(eventName)]
  };

  // Create an event listener
  const listener = async (log) => {
    // Parse the event data from the log
    const event = ethers.utils.defaultAbiCoder.decode(
      ['string'],
      log.data
    );

    const uri = event[0];
    const regex = /^(.*?:\/\/)/;
    const match = uri.match(regex);

    if (!(match && match.length > 0)) {
        console.error("Can't parse URI:", uri)
        return;
    }
        
    const prefix = match[0]; // Extract the prefix URI scheme

    if (prefix != "ipfs://") {
        console.error("We only accept ipfs:// uris at the moment", uri)
        return;
    }

    const cid = uri.slice(prefix.length); // Extract the remaining part of the URI
    
    const postData = {
        cid: cid,
        miners: ['t017840'],
    };

    console.log("Sending payload to: ", apiEndpoint, postData);

    // Make the HTTP API POST request with the event data
    try {
      const response = await axios.post(apiEndpoint, postData);
      console.log('API response:', response.data);
    } catch (error) {
      console.error('API request failed:', error.message);
    }
  };

  // Subscribe to the event
  provider.on(eventFilter, listener);

  // Unsubscribe from the event when the process is terminated
  process.on('SIGINT', async () => {
    try {
      provider.off(eventFilter, listener);
      console.log('Unsubscribed from the event.');
      process.exit(0);
    } catch (error) {
      console.error('Error unsubscribing from the event:', error);
      process.exit(1);
    }
  });
}

main().catch((error) => {
  console.error('An error occurred:', error);
  process.exit(1);
});
