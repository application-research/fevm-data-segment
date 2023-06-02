const FormData = require('form-data');
const axios = require('axios');
const { ethers } = require('hardhat');

require('dotenv').config();


async function main() {

  // Get args
  const rpcEndpoint = process.env.rpcEndpoint;
  const apiEndpoint = process.env.apiEndpoint + "/content/add";
  const contractAddress = process.env.contractAddress;
  const cidContractAddress = process.env.contractAddress;
  const API_KEY = process.env.API_KEY;

  // Create a new ethers provider
  const provider = new ethers.providers.JsonRpcProvider(rpcEndpoint);

  // Compile the contract
  const contractName = 'EdgeAggregatorOracle';
  const Cid = await ethers.getContractFactory("Cid");
  // const contractFactory = await ethers.getContractFactory(contractName);
  const contractFactory = await ethers.getContractFactory(contractName, {
    libraries: {
      Cid: cidContractAddress,
    },
  });
  
  const contract = await contractFactory.attach(contractAddress)

  console.log("Listening for events on contract at address:", contractAddress);
  const contractABI = contract.interface.abi;

  // Specify the event name you want to listen to
  const eventName = 'StoreURIEvent(string)';

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
    let data;

    // Fetch the data from the supplied URI
    try {
      console.log(`Fetching data from: ${uri}`)
      response = await axios.get(uri, {
        responseType: 'stream',
      });
      data = response.data;
      console.log(`Success, fetched ${response.headers["content-length"]} bytes`)
    } catch (error) {
      console.error('Data fetch failed:', error.response);
      return null;
    };
    
    const formData = new FormData();
    formData.append('data', data);

    const postHeaders = {
      headers: {
          Authorization: `Bearer ${API_KEY}`,
          ...formData.getHeaders()
      }
    }

    console.log("Sending payload to: ", apiEndpoint);

    // Make the HTTP API POST request with the event data
    try {
      const response = await axios.post(apiEndpoint, formData, postHeaders);
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
  console.error('An error occurrd:', error);
  process.exit(1);
});