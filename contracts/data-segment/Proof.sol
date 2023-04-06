// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import { Cid } from "./Cid.sol";

contract Proof {
    using Cid for bytes;
    using Cid for bytes32;

    struct Node {
        bytes32 data;
    }

    struct ProofData {
        uint64 index;
        Node[] path;
    }

    // InclusionPoof is produced by the aggregator (or possibly by the SP)
    struct InclusionProof  {
        // ProofSubtree is proof of inclusion of the client's data segment in the data aggregator's Merkle tree (includes position information)
        // I.e. a proof that the root node of the subtree containing all the nodes (leafs) of a data segment is contained in CommDA
        ProofData proofSubtree;
        // ProofIndex is a proof that an entry for the user's data is contained in the index of the aggregator's deal.
        // I.e. a proof that the data segment index constructed from the root of the user's data segment subtree is contained in the index of the deal tree.
        ProofData proofIndex;
    }

    // InclusionVerifierData is the information required for verification of the proof and is sourced
    // from the client.
    struct InclusionVerifierData {
        // Piece Commitment to client's data
        bytes commPc;
        // SizePc is size of client's data
        uint64 sizePc;
    }

    // InclusionAuxData is required for verification of the proof and needs to be cross-checked with the chain state
    struct InclusionAuxData  {
        // Piece Commitment to aggregator's deal
        bytes commPa;
        // SizePa is padded size of aggregator's deal
        uint64 sizePa;
    }

    function computeRoot(ProofData memory d, Node memory subtree) public pure returns (Node memory) {
        require(d.path.length < 64, "merkleproofs with depths greater than 63 are not supported");
        require(d.index >> d.path.length == 0, "index greater than width of the tree");
        
        Node memory carry = subtree;
        uint64 index = d.index;
        uint64 right = 0;

        for (uint64 i = 0; i < d.path.length; i++) {
            (right, index) = (index & 1, index >> 1);
            if (right == 1) {
                carry = computeNode(d.path[i], carry);
            } else {
                carry = computeNode(carry, d.path[i]);
            }
        }

        return carry;
    }

    function computeNode(Node memory left, Node memory right) public pure returns (Node memory) {
        bytes32 digest = sha256(abi.encodePacked(left.data, right.data));
        return truncate(Node(digest));
    }

    function truncate(Node memory n) internal pure returns (Node memory) {
        bytes32 truncatedData = n.data;
        // Set the two lowest-order bits of the last byte to 0
        truncatedData &= 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3f;
        Node memory result = Node(truncatedData);
        return result;
    }

    // proofs
    function verify(ProofData memory proof, Node memory root, Node memory leaf) public pure returns (bool) {
        return computeRoot(proof, leaf).data == root.data;
    }

    function processProof(ProofData memory proof, Node memory leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf.data;
        for (uint256 i = 0; i < proof.path.length; i++) {
            computedHash = hashNode(computedHash, proof.path[i]);
        }
        return computedHash;
    }

    function hashNode(bytes32 left, Node memory right) public pure returns (bytes32) {
        bytes32 truncatedData = sha256(abi.encodePacked(left, right.data));
        truncatedData &= 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3f;
        return truncatedData;
    }

    function computeExpectedAuxData(InclusionProof memory inclusionProof, InclusionVerifierData memory veriferData) public pure returns (InclusionAuxData memory) {
        // Verification flow:
        //	1. Decode Client's Piece commitment
        //	2. Compute assumed aggregator's commitment based on the subtree inclusion proof
        //	3. Compute size of aggregator's deal and offset of Client's deal within the Aggreggator's deal.
        //	4. Create the DataSegmentIndexEntry based on Client's data and offset from 3
        //	5. Compute second assumed aggregator's commitment based on the data segment index entry inclusion proof.
        //  6. Check if DataSegmentIndexEntry falls into the correct area.
        //	7. Compute second assumed aggregator's deal size.
        //	8. Compare deal sizes and commitments from steps 2+3 against steps 5+6. Fail if not equal.
        //	9. Return the computed values of aggregator's Commitment and Size as AuxData.

        bytes32 commPc = Cid.cidToPieceCommitment(veriferData.commPc);

        Node memory assumedCommPa = computeRoot(inclusionProof.proofSubtree, Node(commPc));

        uint64 assumedSizePa = uint64((1 << inclusionProof.proofSubtree.path.length) * veriferData.sizePc);

        uint64 dataOffset = inclusionProof.proofIndex.index * uint64(veriferData.sizePc);

        // TODO 

        bytes memory cidPa = Cid.pieceCommitmentToCid(assumedCommPa.data);


        return InclusionAuxData(cidPa, assumedSizePa);
    }
    

}