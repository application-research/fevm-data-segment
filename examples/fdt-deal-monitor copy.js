const FormData = require('form-data');
const axios = require('axios');
const { ethers } = require('hardhat');
const CIDTool = require('cid-tool');
const db = require('diskdb');
const { start } = require('repl');

const fs = require('fs');
const express = require("express");
const multer  = require('multer');
const os = require('os');
const upload = multer({ dest: os.tmpdir() });

const app = express();
const port = process.env.PORT || 3000;

require('dotenv').config();

// Get args
const rpcEndpoint = process.env.rpcEndpoint;
const apiEndpoint = process.env.apiEndpoint + "/content/add";
const contractAddress = process.env.contractAddress;
const cidContractAddress = process.env.contractAddress;
const API_KEY = process.env.API_KEY;

app.listen(port, async () => {
  console.log(`App listening on port ${port}`);

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
  
  this.contract = await contractFactory.attach(contractAddress)

  // start a simple db
  this.db = db.connect('./transaction-db', ['transactions']);

});

// curl --form 'file=@"/Users/jay/Downloads/banana.jpeg"' localhost:3000/upload
app.post('/upload', upload.single('file'), async (req, res) => {
  const title = req.body.title;
  const file = req.file;

  console.log(title);
  console.log(file);

  const formData = new FormData();
  //formData.append('uploadPicture', req.file.buffer, { contentType: req.file.mimetype, filename: req.file.originalname });
  formData.append('data', fs.createReadStream(req.file.path))


  // formData.append('data', data);

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

    // cid = "0x0181e2039220203f46bc645b07a3ea2c04f066f939ddf7e269dd77671f9e1e61a3a3797e665127";

    responseContents = response.data.contents[0]
    cid = "0x" + ipfsCidToHex(responseContents.cid)
    console.log(cid);
    let submitResponse = await this.contract.submit(cid);
    console.log(submitResponse);

    // save transaction id to db
    this.db.transactions.save({id: responseContents.ID});

    const url = 'https://hackfs.edge.estuary.tech/open/status/content/' + responseContents.ID;
    const res = await waitForNonZeroDealId(url);
    console.log('Non-zero deal_id:', res);

    // call completion callback
    executecompletionCallback(res);

    // remove transaction id to db
    this.db.transactions.remove({id: responseContents.ID});

  } catch (error) {
    console.error('API request failed:', error.message);
    res.send('API request failed:', error.message);
    res.sendStatus(500);
  }

  res.sendStatus(200);
});

function ipfsCidToHex(ipfsCid) {
  rval = CIDTool.format(ipfsCid, { base: 'base16' })
  return rval.substr(1, rval.length - 1);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForNonZeroDealId(url) {
  let dealId = 0;

  while (dealId === 0) {
    try {
      const response = await axios.get(url);
      const payload = response.data;
      
      if (payload.data.deal_info.deal_id != 0 ) {
        return payload;
      }
      console.log('deal has not been negotiated yet, waiting to request again in 5 minutes');
      await sleep(300000); // Sleep for 5 minutes (300,000 milliseconds)
    } catch (error) {
      console.error('Error occurred:', error);
    }
  }

  return dealId;
}



async function executecompletionCallback(input, aggregator) {
  verifData = {
    commPc: "0x" + ipfsCidToHex(input.data.sub_piece_info.comm_pc),
    sizePc: input.data.sub_piece_info.size_pc,
  }
  incProof = {
      proofSubtree: {
          index: input.data.sub_piece_info.inclusion_proof.proofSubtree.index,
          path: input.data.sub_piece_info.inclusion_proof.proofSubtree.path
      },

      proofIndex:{
          index: input.data.sub_piece_info.inclusion_proof.proofIndex.index,
          path: input.data.sub_piece_info.inclusion_proof.proofIndex.path
      },
  }
  resp = await aggregator.complete(1, 1234, incProof, verifData);
  console.log(resp);
}

/*
async function main() {

  db.connect('./transaction-db', ['transactions']);

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
  //const eventName = 'SubmitAggregatorRequest(uint256,bytes)';

  // Specify the HTTP API endpoint and the POST request payload

  // Create an event filter
  const eventFilter = {
    address: contractAddress,
    topics: [ethers.utils.id(eventName)]
  };

  const eventName = 'SubmitAggregatorRequest';
  contract.on(eventName, (_id, _cid) => {
    // Handle the event data here
    console.log('Event occurred:');
    console.log('_id:', _id.toString());
    console.log('_cid:', ethers.utils.parseBytes32String(_cid));
  });


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
      console.log(`Success, fetched ${response.headers["content-length"]} bytes`);
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

      // save transaction id to db
      db.transactions.save({id: response.contents.ID});

      const url = 'https://hackfs.edge.estuary.tech/open/status/content/' + response.contents.ID;
      const res = await waitForNonZeroDealId(url);
      console.log('Non-zero deal_id:', res);

      // call completion callback
      executecompletionCallback(res);

      // remove transaction id to db
      db.transactions.remove({id: response.contents.ID});

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

*/