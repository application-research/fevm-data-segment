// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../data-segment/Proof.sol";

/**
 * @title IAggregatorOracle
 * @dev IAggregatorOracle is an interface for an oracle that is used by the aggregator
 */
interface IAggregatorOracle {

    // Submit Aggregator Request Event
    event SubmitAggregatorRequest(uint256 indexed _id, bytes _cid);

    // Complete Aggregator Request Event
    event CompleteAggregatorRequest(uint256 indexed _id, uint64 indexed _dealId);

    /**
     * @dev submit submits a new request to the oracle
     * @param _cid is the cid of the data segment
     * @return id the transaction ID
     */
    function submit(bytes memory _cid) external returns (uint256 id);

    /**
     * @dev complete is a callback function that is called by the aggregator
     * @param _id is the transaction ID
     * @param _dealId is the deal ID
     * @param _proof is the inclusion proof
     * @param _verifierData is the verifier data
     * @return the aux data
     */
    function complete(uint256 _id, uint64 _dealId, InclusionProof memory _proof, InclusionVerifierData memory _verifierData) external returns (InclusionAuxData memory);

    /**
     * @dev getAllDeals returns all deals for a given cid
     * @param _cid is the cid of the data segment
     * @return the deal IDs
     */
    function getAllDeals(bytes memory _cid) external returns (uint64[] memory);
}