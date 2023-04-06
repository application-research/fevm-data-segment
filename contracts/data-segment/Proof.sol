// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import {Cid} from "./Cid.sol";

contract Proof {
    using Cid for bytes;
    using Cid for bytes32;

    bytes32 private constant TRUNCATOR = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3f;

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
        // cid.Cid CommPc;
        bytes commPc;
        // SizePc is size of client's data
        uint64 sizePc;
    }

    // InclusionAuxData is required for verification of the proof and needs to be cross-checked with the chain state
    struct InclusionAuxData  {
        // Piece Commitment to aggregator's deal
        // cid.Cid CommPa;
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

    function dummy(bytes memory inp)public pure returns (bytes32) {
        return inp.cidToPieceCommitment();
    }
    
    function computeExpectedAuxData(InclusionProof memory ip, InclusionVerifierData memory veriferData) public pure returns (InclusionAuxData memory) {    
        bytes32 commPc = veriferData.commPc.cidToPieceCommitment();
        Node memory nodeCommPc = Node(commPc);
        Node memory assumedCommPa = computeRoot(ip.proofSubtree, nodeCommPc);

        (bool ok, uint64 assumedSizePa) = checkedMultiply(uint64(1)<<uint64(ip.proofSubtree.path.length), uint64(veriferData.sizePc));
        require(ok, "assumedSizePa overflow");

        InclusionAuxData memory auxData = InclusionAuxData(assumedCommPa.data.pieceCommitmentToCid(), assumedSizePa);
        return auxData;
    }

    function checkedMultiply(uint64 a, uint64 b) internal pure returns (bool, uint64) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint64 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function truncate(Node memory n) internal pure returns (Node memory) {
        bytes32 truncatedData = n.data;
        // Set the two lowest-order bits of the last byte to 0
        truncatedData &= TRUNCATOR;
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
        truncatedData &= TRUNCATOR;
        return truncatedData;
    }

    function truncatedHash(bytes32 data) public pure returns (bytes32) {
        bytes32 truncatedData = sha256(abi.encodePacked(data));
        truncatedData &= TRUNCATOR;
        return truncatedData;
    }

}