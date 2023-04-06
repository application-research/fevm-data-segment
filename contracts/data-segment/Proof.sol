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
    
    function computeExpectedAuxData(InclusionProof memory ip, InclusionVerifierData memory verifierData) public pure returns (InclusionAuxData memory) {    
        require(isPow2(uint64(verifierData.sizePc)), "Size of piece provided by verifier is not power of two");

        bytes32 commPc = verifierData.commPc.cidToPieceCommitment();
        Node memory nodeCommPc = Node(commPc);
        Node memory assumedCommPa = computeRoot(ip.proofSubtree, nodeCommPc);

        (bool ok, uint64 assumedSizePa) = checkedMultiply(uint64(1)<<uint64(ip.proofSubtree.path.length), uint64(verifierData.sizePc));
        require(ok, "assumedSizePa overflow");


        uint64 dataOffset = ip.proofSubtree.index * uint64(verifierData.sizePc);

        // TODO: Question: Do we need to cast nodeCommPc to Fr32 which would simply cast it back to Node?
        SegmentDesc memory en = makeDataSegmentIndexEntry(Fr32(nodeCommPc.data), dataOffset, uint64(verifierData.sizePc));
        Node memory enNode = Node(truncatedHash(serializeFr32(en)));
        Node memory assumedCommPa2 = computeRoot(ip.proofSubtree, enNode);
        // require(assumedCommPa.data == assumedCommPa2.data, "aggregator's data commitments don't match");

        uint8 bytesInDataSegmentIndexEntry = 2 * MERKLE_TREE_NODE_SIZE;
        (bool ok2, uint64 assumedSizePa2) = checkedMultiply(uint64(1)<<uint64(ip.proofSubtree.path.length), uint64(bytesInDataSegmentIndexEntry));
        require(ok2, "assumedSizePau64 overflow");
        //require(assumedSizePa == assumedSizePa2, "aggregator's data size doesn't match");

        
        /*
        uint64 idxStart = indexAreaStart(assumedSizePa2);
        (bool ok3, uint64 indexOffset) = checkedMultiply(ip.proofIndex.index, uint64(bytesInDataSegmentIndexEntry));
        require(ok3, "indexOffset overflow");
        require(indexOffset >= idxStart, "index entry at wrong position");
        */

        InclusionAuxData memory auxData = InclusionAuxData(assumedCommPa.data.pieceCommitmentToCid(), assumedSizePa);
        return auxData;
    }

    uint256 public constant BytesInInt = 8;

    uint256 public constant ChecksumSize = 16;

    uint256 public constant EntrySize = uint256(MERKLE_TREE_NODE_SIZE) + 2*BytesInInt + ChecksumSize;
    
    function indexAreaStart(uint64 sizePa) internal pure returns (uint64) {
        return uint64(sizePa) - uint64(maxIndexEntriesInDeal(sizePa))*uint64(EntrySize);
    }

    function maxIndexEntriesInDeal(uint256 dealSize) internal pure returns (uint256) {
        uint256 res = (uint256(1) << (log2Ceil(uint64(dealSize / 2048 / EntrySize)))) & ((1 << 256) - 1);
        if (res < 4) {
            return 4;
        }
        return res;
    }

    function isPow2(uint64 value) public pure returns (bool) {
        if (value == 0) {
            return true;
        }
        return (value & (value - 1)) == 0;
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

    function truncatedHash(bytes memory data) public pure returns (bytes32) {
        bytes32 truncatedData = sha256(abi.encodePacked(data));
        truncatedData &= TRUNCATOR;
        return truncatedData;
    }


    /////


    struct SegmentDesc {
        Node commDs;
        uint64 offset;
        uint64 size;
        bytes32 checksum;
    }

    struct Fr32 {
        bytes32 value;
    }

    function makeDataSegmentIndexEntry(Fr32 memory commP, uint64 offset, uint64 size) internal pure returns (SegmentDesc memory) {
        SegmentDesc memory en;
        en.commDs = Node(commP.value);
        en.offset = offset;
        en.size = size;
        en.checksum = computeChecksum(en);
        return en;
    }

    function computeChecksum(SegmentDesc memory sd) private pure returns (bytes32) {
        sd.checksum = bytes16(0);

        bytes memory toHash = new bytes(0); //sd.serializeFr32();
        bytes32 digest = sha256(toHash);
        bytes16 res;
        assembly {
            mstore(add(res, 32), digest)
        }
        // Truncate to 126 bits
        res &= bytes16(hex"ffffffffffffffffffffffffffffff3f");
        return res;
    }

    uint256 constant private ENTRY_SIZE = 64;

    function serializeFr32(SegmentDesc memory sd) internal pure returns (bytes memory) {
        bytes memory res = new bytes(ENTRY_SIZE);
        serializeFr32Into(sd, res);
        return res;
    }

    function serializeFr32Into(SegmentDesc memory sd, bytes memory slice) internal pure {
        require(slice.length >= ENTRY_SIZE, "Invalid slice length");

        bytes32 commDs = sd.commDs.data;
        uint64 offset = sd.offset;
        uint64 size = sd.size;
        bytes32 checksum = sd.checksum;

        assembly {
            mstore(add(slice, 32), commDs)
            mstore(add(slice, add(MERKLE_TREE_NODE_SIZE, 32)), offset)
            mstore(add(slice, add(MERKLE_TREE_NODE_SIZE, 40)), size)
            mstore(add(slice, add(MERKLE_TREE_NODE_SIZE, 56)), checksum)
        }
    }

    //////// utilities
    function leadingZeros64(uint64 x) internal pure returns (uint256) {
        uint256 leadingZeros = 64;
        uint256 shiftAmount = 32;

        // Check the upper 32 bits
        if (x >> 32 == 0) {
            leadingZeros -= shiftAmount;
            x <<= shiftAmount;
        }

        // Check the upper 16 bits
        if (x >> 48 == 0) {
            leadingZeros -= 16;
            x <<= 16;
        }

        // Check the upper 8 bits
        if (x >> 56 == 0) {
            leadingZeros -= 8;
            x <<= 8;
        }

        // Check the upper 4 bits
        if (x >> 60 == 0) {
            leadingZeros -= 4;
            x <<= 4;
        }

        // Check the upper 2 bits
        if (x >> 62 == 0) {
            leadingZeros -= 2;
            x <<= 2;
        }

        // Check the upper bit
        if (x >> 63 == 0) {
            leadingZeros -= 1;
        }

        return leadingZeros;
    }

    function log2Ceil(uint64 value) internal pure returns (uint256) {
        if (value <= 1) {
            return 0;
        }
        return log2Floor(value - 1) + 1;
    }

    function log2Floor(uint64 value) internal pure returns (uint256) {
        if (value == 0) {
            return 0;
        }
        uint256 zeros = leadingZeros64(value);
        return uint256(64 - zeros - 1);
    }

}