// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

/*
 * A Merkle proof is a list of hashes that allows a user to prove that a particular piece of data
 * exists in a Merkle tree. The Merkle tree is constructed from the data segments of a deal.
 * The Merkle proof is used to prove that the data segment of a deal is included in the data segment of a client.
 * The Merkle proof is used to prove that the data segment of a client is included in the data segment of a deal.
 */
struct ProofData {
    uint64 index;
    bytes32[] path;
}

// InclusionPoof is produced by the aggregator (or possibly by the SP)
/*
 * An inclusion proof is a list of hashes that allows a user to prove that a particular piece of data
 * exists in a Merkle tree. The Merkle tree is constructed from the data segments of a deal.
 * The inclusion proof is used to prove that the data segment of a deal is included in the data segment of a client.
 * The inclusion proof is used to prove that the data segment of a client is included in the data segment of a deal.
 */
struct InclusionProof {
    // ProofSubtree is proof of inclusion of the client's data segment in the data aggregator's Merkle tree (includes position information)
    // I.e. a proof that the root node of the subtree containing all the nodes (leafs) of a data segment is contained in CommDA
    ProofData proofSubtree;
    // ProofIndex is a proof that an entry for the user's data is contained in the index of the aggregator's deal.
    // I.e. a proof that the data segment index constructed from the root of the user's data segment subtree is contained in the index of the deal tree.
    ProofData proofIndex;
}

/*
 * InclusionVerifierData is the information required for verification of the proof and is sourced
 * from the client.
 */
struct InclusionVerifierData {
    /* commPc is the piece commitment CID to the client's data */
    bytes commPc;
    /* sizePc is the size of the client's data */
    uint64 sizePc;
}

/*
 * InclusionAuxData is the information required for verification of the proof and is sourced
 * from the chain state.
 */
struct InclusionAuxData {
    /* commPa is the piece commitment CID to the aggregator's deal */
    bytes commPa;
    /* sizePa is the size of the aggregator's deal */
    uint64 sizePa;
}

/* SegmentDesc is a description of a data segment. */
struct SegmentDesc {
    // commDs is the piece commitment CID to the data segment
    bytes32 commDs;
    // offset is the offset of the data segment in the data
    uint64 offset;
    // size is the size of the data segment
    uint64 size;
    // checksum is the checksum of the data segment
    bytes16 checksum;
}

/* DataSegment is a data segment. */
struct Fr32 {
    // value is the value of the data segment
    bytes32 value;
}
