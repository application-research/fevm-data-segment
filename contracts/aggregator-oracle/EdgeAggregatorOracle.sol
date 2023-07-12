// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "./IAggregatorOracle.sol";
import "../data-segment/Proof.sol";

import { MarketAPI } from "@zondax/filecoin-solidity/contracts/v0.8/MarketAPI.sol";
import { MarketTypes } from "@zondax/filecoin-solidity/contracts/v0.8/types/MarketTypes.sol";

// Delta that implements the AggregatorOracle interface
contract EdgeAggregatorOracle is IAggregatorOracle, Proof {

    // transactionId is the ID of the transaction
    uint256 private transactionId;
    // txIdToCid maps transaction ID to the CID
    mapping (uint256 => bytes) private txIdToCid;
    // cidToDealIds maps CID to deal IDs
    mapping (bytes => uint64[]) private cidToDealIds; 

    constructor() {
        transactionId = 0;
    }

    /* 
     * @dev submit submits a new request to the aggregator
     * @param _cid is the cid of the data segment
     * @return the transaction ID
     */
    function submit(bytes memory _cid) external returns (uint256) {
        // Increment the transaction ID
        transactionId++;    

        // Save _cid
        txIdToCid[transactionId] = _cid;

        // Emit the event
        emit SubmitAggregatorRequest(transactionId, _cid);
        return transactionId;
    }

    /**
     * @dev complete is a callback function that is called by the aggregator
     * @param _id is the transaction ID
     * @param _dealId is the deal ID
     * @param _proof is the inclusion proof
     * @param _verifierData is the verifier data
     * @return the aux data
     */
    function complete(uint256 _id, uint64 _dealId, InclusionProof memory _proof, InclusionVerifierData memory _verifierData) external returns (InclusionAuxData memory) {
        require(_id <= transactionId, "complete: invalid transaction id");
        // Emit the event
        emit CompleteAggregatorRequest(_id, _dealId);

        // save the _dealId if it is not already saved
        bytes memory cid = txIdToCid[_id];
        for (uint i = 0; i < cidToDealIds[cid].length; i++) {
            if (cidToDealIds[cid][i] == _dealId) {
                return this.computeExpectedAuxData(_proof, _verifierData);
            }
        }
        cidToDealIds[cid].push(_dealId);

        // Perform validation logic
        // return this.computeExpectedAuxDataWithDeal(_dealId, _proof, _verifierData);
        return this.computeExpectedAuxData(_proof, _verifierData);
    }

    /**
     * @dev getAllDeals returns all deals for a CID
     * @param _cid is the CID
     * @return the deal IDs
     */
    function getAllDeals(bytes memory _cid) external view returns (uint64[] memory) {
        return cidToDealIds[_cid];
    }
}
