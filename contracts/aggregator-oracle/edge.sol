// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "./aggregator.sol";
import "../data-segment/Proof.sol";

// EdgeAggregatorOracle that implements the AggregatorOracle interface
contract EdgeAggregatorOracle is AggregatorOracle, Proof {

    /* the transaction ID */
    uint256 private transactionId;

    constructor() {
        transactionId = 0;
    }

    /*
    * @dev Submit a new request to the oracle
    * @param _cid The CID of the data segment
    * @return The transaction ID
    */
    function submit(bytes memory _cid) public returns (uint256) {
        // Increment the transaction ID
        transactionId++;        
        // Emit the event
        emit SubmitAggregatorRequest(transactionId, _cid);
        return transactionId;
    }

    /*
    * @dev Callback function that is called by the aggregator
    * @param _id The transaction ID
    * @param _dealId The deal ID
    * @param _proof The inclusion proof
    * @param _verifierData The inclusion verifier data
    * @return The inclusion aux data
    */
    function complete(uint256 _id, uint64 _dealId, InclusionProof memory _proof, InclusionVerifierData memory _verifierData) public returns (InclusionAuxData memory) {
        require(_id <= transactionId, "Delta.complete: invalid transaction id");
        // Emit the event
        emit CompleteAggregatorRequest(_id, _dealId);
        // Perform validation logic
        // return this.computeExpectedAuxDataWithDeal(_dealId, _proof, _verifierData);
        return this.computeExpectedAuxData(_proof, _verifierData);
    }
}
