// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "./aggregator.sol";
import "../data-segment/Proof.sol";

// Delta that implements the AggregatorOracle interface
contract DeltaAggregatorOracle is AggregatorOracle, Proof {

    uint256 private transactionId;

    constructor() {
        transactionId = 0;
    }

    function submit(bytes memory _cid) public returns (uint256) {
        // Increment the transaction ID
        transactionId++;        
        // Emit the event
        emit SubmitAggregatorRequest(transactionId, _cid);
        return transactionId;
    }

    function complete(uint256 _id, uint64 _dealId, InclusionProof memory _proof, InclusionVerifierData memory _verifierData) public returns (InclusionAuxData memory) {
        require(_id <= transactionId, "Delta.complete: invalid transaction id");
        // Emit the event
        emit CompleteAggregatorRequest(_id, _dealId);
        // Perform validation logic
        // return this.computeExpectedAuxDataWithDeal(_dealId, _proof, _verifierData);
        return this.computeExpectedAuxData(_proof, _verifierData);
    }
}
