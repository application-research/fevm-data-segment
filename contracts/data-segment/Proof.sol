// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import {Cid} from "./Cid.sol";

contract Proof {
    using Cid for bytes;
    using Cid for bytes32;

    uint8 public constant MERKLE_TREE_NODE_SIZE = 32;
    bytes32 private constant TRUNCATOR = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3f;
    uint64 public constant BYTES_IN_INT = 8;
    uint64 public constant CHECKSUM_SIZE = 16;
    uint64 public constant ENTRY_SIZE = uint64(MERKLE_TREE_NODE_SIZE) + 2*BYTES_IN_INT + CHECKSUM_SIZE;
    uint8 private constant bytesInDataSegmentIndexEntry = 2 * MERKLE_TREE_NODE_SIZE;

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

    // computeRoot computes the root of a Merkle tree given a leaf and a Merkle proof.
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

    // computeNode computes the parent node of two child nodes
    function computeNode(Node memory left, Node memory right) public pure returns (Node memory) {
        bytes32 digest = sha256(abi.encodePacked(left.data, right.data));
        return truncate(Node(digest));
    }

    // computeExpectedAuxData computes the expected auxiliary data given an inclusion proof and the data provided by the verifier.
    function computeExpectedAuxData(InclusionProof memory ip, InclusionVerifierData memory verifierData) public pure returns (InclusionAuxData memory) {    
        require(isPow2(uint64(verifierData.sizePc)), "Size of piece provided by verifier is not power of two");

        bytes32 commPc = verifierData.commPc.cidToPieceCommitment();
        Node memory nodeCommPc = Node(commPc);
        Node memory assumedCommPa = computeRoot(ip.proofSubtree, nodeCommPc);

        (bool ok, uint64 assumedSizePa) = checkedMultiply(uint64(1)<<uint64(ip.proofSubtree.path.length), uint64(verifierData.sizePc));
        require(ok, "assumedSizePa overflow");

        uint64 dataOffset = ip.proofSubtree.index * uint64(verifierData.sizePc);
        SegmentDesc memory en = makeDataSegmentIndexEntry(Fr32(nodeCommPc.data), dataOffset, uint64(verifierData.sizePc));
        Node memory enNode = Node(truncatedHash(serialize(en)));
        Node memory assumedCommPa2 = computeRoot(ip.proofIndex, enNode);
        require(assumedCommPa.data == assumedCommPa2.data, "aggregator's data commitments don't match");

        (bool ok2, uint64 assumedSizePa2) = checkedMultiply(uint64(1)<<uint64(ip.proofIndex.path.length), uint64(bytesInDataSegmentIndexEntry));
        require(ok2, "assumedSizePau64 overflow");
        require(assumedSizePa == assumedSizePa2, "aggregator's data size doesn't match");

        validateIndexEntry(ip, assumedSizePa2);

        return InclusionAuxData(assumedCommPa.data.pieceCommitmentToCid(), assumedSizePa);
    }

    // validateIndexEntry validates that the index entry is in the correct position in the index.
    function validateIndexEntry(InclusionProof memory ip, uint64 assumedSizePa2) internal pure {
        uint64 idxStart = indexAreaStart(assumedSizePa2);
        (bool ok3, uint64 indexOffset) = checkedMultiply(ip.proofIndex.index, uint64(bytesInDataSegmentIndexEntry));
        require(ok3, "indexOffset overflow");
        require(indexOffset >= idxStart, "index entry at wrong position");
    }

    // indexAreaStart returns the offset of the start of the index area in the deal.
    function indexAreaStart(uint64 sizePa) internal pure returns (uint64) {
        return uint64(sizePa) - uint64(maxIndexEntriesInDeal(sizePa))*uint64(ENTRY_SIZE);
    }

    // maxIndexEntriesInDeal returns the maximum number of index entries that can be stored in a deal of the given size.
    function maxIndexEntriesInDeal(uint256 dealSize) internal pure returns (uint) {
        uint res = (uint(1) << uint256(log2Ceil(uint64(dealSize / 2048 / ENTRY_SIZE)))); //& ((1 << 256) - 1);
        if (res < 4) {
            return 4;
        }
        return res;
    }

    // isPow2 returns true if the given value is a power of 2.
    function isPow2(uint64 value) internal pure returns (bool) {
        if (value == 0) {
            return true;
        }
        return (value & (value - 1)) == 0;
    }

    // checkedMultiply multiplies two uint64 values and returns the result and a boolean indicating whether the multiplication
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

    // truncate truncates a node to 254 bits.
    function truncate(Node memory n) internal pure returns (Node memory) {
        bytes32 truncatedData = n.data;
        // Set the two lowest-order bits of the last byte to 0
        truncatedData &= TRUNCATOR;
        Node memory result = Node(truncatedData);
        return result;
    }

    // verify verifies that the given leaf is present in the merkle tree with the given root.
    function verify(ProofData memory proof, Node memory root, Node memory leaf) public pure returns (bool) {
        return computeRoot(proof, leaf).data == root.data;
    }

    // processProof computes the root of the merkle tree given the leaf and the inclusion proof.
    function processProof(ProofData memory proof, Node memory leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf.data;
        for (uint256 i = 0; i < proof.path.length; i++) {
            computedHash = hashNode(computedHash, proof.path[i]);
        }
        return computedHash;
    }

    // hashNode hashes the given node with the given left child.
    function hashNode(bytes32 left, Node memory right) public pure returns (bytes32) {
        bytes32 truncatedData = sha256(abi.encodePacked(left, right.data));
        truncatedData &= TRUNCATOR;
        return truncatedData;
    }

    // truncatedHash computes the truncated hash of the given data.
    function truncatedHash(bytes memory data) public pure returns (bytes32) {
        bytes32 truncatedData = sha256(abi.encodePacked(data));
        truncatedData &= TRUNCATOR;
        return truncatedData;
    }

    // SegmentDesc is a description of a data segment.
    struct SegmentDesc {
        Node commDs;
        uint64 offset;
        uint64 size;
        bytes16 checksum;
    }

    struct Fr32 {
        bytes32 value;
    }

    // makeDataSegmentIndexEntry creates a new data segment index entry.
    function makeDataSegmentIndexEntry(Fr32 memory commP, uint64 offset, uint64 size) internal pure returns (SegmentDesc memory) {
        SegmentDesc memory en;
        en.commDs = Node(commP.value);
        en.offset = offset;
        en.size = size;
        en.checksum = computeChecksum(en);
        return en;
    }

    // computeChecksum computes the checksum of the given segment description.
    function computeChecksum(SegmentDesc memory _sd) public pure returns (bytes16) {
        bytes memory serialized = serialize(_sd);
        bytes32 digest = sha256(serialized);
        digest &= hex"ffffffffffffffffffffffffffffff3f";
        return bytes16(digest);
    }

    // serialize serializes the given segment description.
    function serialize(SegmentDesc memory sd) public pure returns (bytes memory) {
        bytes memory result = new bytes(ENTRY_SIZE);

        // Pad commDs
        bytes32 commDs = sd.commDs.data;
        assembly {
            mstore(add(result, 32), commDs)
        }

        // Pad offset (little-endian)
        for (uint i = 0; i < 8; i++) {
            result[MERKLE_TREE_NODE_SIZE + i] = bytes1(uint8(sd.offset >> (i * 8)));
        }

        // Pad size (little-endian)
        for (uint i = 0; i < 8; i++) {
            result[MERKLE_TREE_NODE_SIZE + 8 + i] = bytes1(uint8(sd.size >> (i * 8)));
        }

        // Pad checksum
        for (uint i = 0; i < 16; i++) {
            result[MERKLE_TREE_NODE_SIZE + 16 + i] = sd.checksum[i];
        }

        return result;
    }

    // leadingZeros64 returns the number of leading zeros in the given uint64.
    function leadingZeros64(uint64 x) internal pure returns (uint256) {
        return 64 - len64(x);
    }

    // len64 returns the number of bits in the given uint64.
    function len64(uint64 x) internal pure returns (uint256) {
        uint256 count = 0;
        while (x > 0) {
            x = x >> 1;
            count++;
        }
        return count;
    }

    // log2Ceil returns the ceiling of the base-2 logarithm of the given value.
    function log2Ceil(uint64 value) internal pure returns (int) {
        if (value <= 1) {
            return 0;
        }
        return log2Floor(value - 1) + 1;
    }

    // log2Floor returns the floor of the base-2 logarithm of the given value.
    function log2Floor(uint64 value) internal pure returns (int) {
        if (value == 0) {
            return 0;
        }
        uint zeros = leadingZeros64(value);
        return int(64 - zeros - 1);
    }

}