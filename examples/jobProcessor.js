// jobProcessor.js
const { ethers } = require('hardhat');
const level = require('level')
const db = level('db')
var Jobs = require('level-jobs');
const FormData = require('form-data');
const axios = require('axios');
const CIDTool = require('cid-tool');
const fs = require('fs');

// state
const state = new Map();

// Get args
const rpcEndpoint = process.env.rpcEndpoint;
const addApiEndpoint = process.env.apiEndpoint + "/api/v1/content/add";
const statusApiEndpoint = process.env.apiEndpoint + "/open/status/content/";
const contractAddress = process.env.contractAddress;
const cidContractAddress = process.env.contractAddress;
const API_KEY = process.env.API_KEY;

var contract;

async function init() {
    // Create a new ethers provider
    const provider = new ethers.providers.JsonRpcProvider(rpcEndpoint);

    // Compile the contract
    const contractName = 'EdgeAggregatorOracle';
    const Cid = await ethers.getContractFactory("Cid");
    const contractFactory = await ethers.getContractFactory(contractName, {
    libraries: {
        Cid: cidContractAddress,
    },
    });

    contract = await contractFactory.attach(contractAddress)
}

async function worker(id, payload, done) {
  await queue.del(id);
  console.log('Processing job', id, payload);
  state.set(id, payload);

  if (!contract) { 
    await init();
  }

  const formData = new FormData();
  formData.append('data', fs.createReadStream(payload.path))
  const postHeaders = {
    headers: {
        Authorization: `Bearer ${API_KEY}`,
        ...formData.getHeaders()
    }
  }

  console.log("Sending payload to: ", addApiEndpoint);

  // Make the HTTP API POST request with the event data
  try {
    const response = await axios.post(addApiEndpoint, formData, postHeaders);
    console.log('API response:', response.data);
    responseContents = response.data.contents[0]
    cid = "0x" + ipfsCidToHex(responseContents.cid)
    console.log(cid);
    let submitResponse = await contract.submit(cid);
    console.log(submitResponse);

    const url = statusApiEndpoint + responseContents.ID;
    const res = await waitForNonZeroDealId(url);
    //const res = await waitForNonZeroDealId('https://hackfs-coeus.estuary.tech/edge/open/status/content/1000');
    console.log('Non-zero deal_id:', res);

    // call completion callback
    executecompletionCallback(res);
    done();
  } catch (error) {
    console.error('API request failed:', error.message);
    throw error;
  } finally {
    // Remove the job from the queue
    await queue.del(id);
  } 
} 

var queue = Jobs(db, worker);
var stream = queue.runningStream();
stream.on('data', function(d) {
  var jobId = d.key;
  var work = d.value;
  console.log('pending job id: %s, work: %j', jobId, work);
});

// Submit a job to the database
async function submitJob(file) {  
    var jobId = await queue.push(file);
    return jobId;
}

// Retrieve the status of a job from the database
async function getJobStatus(jobId) {
  /*
  var stream = queue.pendingStream();
  stream.on('data', function(d) {
    var jobId = d.key;
    var work = d.value;
    console.log('pending job id: %s, work: %j', jobId, work);
  });
  */


  const job = await queue.runningStream();
  console.log(job);
  jjj = job.get(jobId);

  //const job = queue.get(jobId);
  //  const jobs = Jobs(db);
  //  const job = await jobs.get(jobId);
  return job ? job.status : null;
}

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
      console.log(`${response.data.data.content_info.cid} - deal has not been negotiated yet, waiting to request again in 5 minutes`);
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
  resp = await contract.complete(1, 1234, incProof, verifData);
  console.log(resp);
}

module.exports = {
    submitJob,
    getJobStatus,
    init,
};
