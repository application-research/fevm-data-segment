// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "./Const.sol";
import {Cid} from "./Cid.sol";
import {ProofData, InclusionProof, InclusionVerifierData, InclusionAuxData, SegmentDesc, Fr32} from "./ProofTypes.sol";
import {MarketAPI} from "@zondax/filecoin-solidity/contracts/v0.8/MarketAPI.sol";
import {MarketTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/MarketTypes.sol";

/**
 * @title Proof
 * @dev Proof is a library for verifying inclusion proofs.
 */
contract Proof {
    using Cid for bytes;
    using Cid for bytes32;

    /**
     * @dev computeExpectedAuxData computes the expected auxiliary data given an inclusion proof and the data provided by the verifier
     * @param _ip is the inclusion proof
     * @param _verifierData is the verifier data
     * @return the expected aux data
     */
    function computeExpectedAuxData(
        InclusionProof memory ip,
        InclusionVerifierData memory verifierData
    ) public pure returns (InclusionAuxData memory) {
        require(
            isPow2(uint64(verifierData.sizePc)),
            "Size of piece provided by verifier is not power of two"
        );

        // Compute the root of the subtree containing all the nodes (leafs) of the data segment
        // The root of the subtree is the piece commitment of the data segment (commPc)
        bytes32 commPc = verifierData.commPc.cidToPieceCommitment();
        bytes32 assumedCommPa = computeRoot(ip.proofSubtree, commPc);

        // check that the aggregator's data commitments dont overflow
        (bool ok, uint64 assumedSizePa) = checkedMultiply(
            uint64(1) << uint64(ip.proofSubtree.path.length),
            uint64(verifierData.sizePc)
        );
        require(ok, "assumedSizePa overflow");

        // check that the aggregator's data commitments match
        uint64 dataOffset = ip.proofSubtree.index * uint64(verifierData.sizePc);
        SegmentDesc memory en = makeDataSegmentIndexEntry(
            Fr32(commPc),
            dataOffset,
            uint64(verifierData.sizePc)
        );
        bytes32 enNode = truncatedHash(serialize(en));
        bytes32 assumedCommPa2 = computeRoot(ip.proofIndex, enNode);
        require(
            assumedCommPa == assumedCommPa2,
            "aggregator's data commitments don't match"
        );

        // check that the aggregator's data size matches
        (bool ok2, uint64 assumedSizePa2) = checkedMultiply(
            uint64(1) << uint64(ip.proofIndex.path.length),
            BYTES_IN_DATA_SEGMENT_ENTRY
        );
        require(ok2, "assumedSizePau64 overflow");
        require(assumedSizePa == assumedSizePa2, "aggregator's data size doesn't match");

        validateIndexEntry(ip, assumedSizePa2);
        return InclusionAuxData(assumedCommPa.pieceCommitmentToCid(), assumedSizePa);
    }

    /**
     * @dev computeExpectedAuxDataWithDeal computes the expected auxiliary data given an inclusion proof and the data provided by the verifier
     * and validates that the deal is activated and not terminated.
     * @param _dealId is the deal ID
     * @param _ip is the inclusion proof
     * @param _verifierData is the verifier data
     * @return the expected aux data
     */
    function computeExpectedAuxDataWithDeal(
        uint64 dealId,
        InclusionProof memory ip,
        InclusionVerifierData memory verifierData
    ) public returns (InclusionAuxData memory) {
        InclusionAuxData memory inclusionAuxData = computeExpectedAuxData(ip, verifierData);
        validateInclusionAuxData(dealId, inclusionAuxData);
        return inclusionAuxData;
    }

    /**
     * @dev validateInclusionAuxData validates that the deal is activated and not terminated.
     * @param _dealId is the deal ID
     * @param _inclusionAuxData is the inclusion auxiliary data
     */
    function validateInclusionAuxData(
        uint64 dealId,
        InclusionAuxData memory inclusionAuxData
    ) internal {
        // check that the deal is not terminated
        MarketTypes.GetDealActivationReturn memory dealActivation = MarketAPI.getDealActivation(
            dealId
        );
        require(dealActivation.terminated <= 0, "Deal is terminated");
        require(dealActivation.activated > 0, "Deal is not activated");

        MarketTypes.GetDealDataCommitmentReturn memory dealDataCommitment = MarketAPI
            .getDealDataCommitment(dealId);
        require(
            keccak256(dealDataCommitment.data) == keccak256(inclusionAuxData.commPa),
            "Deal commD doesn't match"
        );
        require(dealDataCommitment.size == inclusionAuxData.sizePa, "Deal size doesn't match");
    }

    /**
     * @dev validateIndexEntry validates that the index entry is in the correct position in the index.
     * @param _ip is the inclusion proof
     * @param _assumedSizePa2 is the assumed size of the aggregator's data
     */
    function validateIndexEntry(InclusionProof memory ip, uint64 assumedSizePa2) internal pure {
        uint64 idxStart = indexAreaStart(assumedSizePa2);
        (bool ok3, uint64 indexOffset) = checkedMultiply(
            ip.proofIndex.index,
            BYTES_IN_DATA_SEGMENT_ENTRY
        );
        require(ok3, "indexOffset overflow");
        require(indexOffset >= idxStart, "index entry at wrong position");
    }

    /**
     * @dev computeRoot computes the root of a Merkle tree given a leaf and a Merkle proof.
     * @param _d is the proof data
     * @param _subtree is the subtree
     * @return the root of the Merkle tree
     */
    function computeRoot(
        ProofData memory d,
        bytes32 subtree
    ) public pure returns (bytes32) {
        require(d.path.length < 64, "merkleproofs with depths greater than 63 are not supported");
        require(d.index >> d.path.length == 0, "index greater than width of the tree");

        bytes32 carry = subtree;
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

    /**
     * @dev computeNode computes the parent node of two child nodes
     * @param _left is the left child
     * @param _right is the right child
     * @return the parent node
     */
    function computeNode(bytes32 left, bytes32 right) public pure returns (bytes32) {
        bytes32 digest = sha256(abi.encodePacked(left, right));
        return truncate(digest);
    }

    /**
     * @dev indexAreaStart returns the offset of the start of the index area in the deal.
     * @param _sizePa is the size of the aggregator's data
     * @return the offset of the start of the index area in the deal
     */
    function indexAreaStart(uint64 sizePa) internal pure returns (uint64) {
        return uint64(sizePa) - uint64(maxIndexEntriesInDeal(sizePa)) * uint64(ENTRY_SIZE);
    }

    /**
     * @dev maxIndexEntriesInDeal returns the maximum number of index entries that can be stored in a deal of the given size.
     * @param _dealSize is the size of the deal
     * @return the maximum number of index entries that can be stored in a deal of the given size
     */
    function maxIndexEntriesInDeal(uint256 dealSize) internal pure returns (uint) {
        uint res = (uint(1) << uint256(log2Ceil(uint64(dealSize / 2048 / ENTRY_SIZE)))); //& ((1 << 256) - 1);
        if (res < 4) {
            return 4;
        }
        return res;
    }

    /**
     * @dev isPow2 returns true if the given value is a power of 2.
     * @param _value is the value
     * @return true if the given value is a power of 2
     */
    function isPow2(uint64 value) internal pure returns (bool) {
        if (value == 0) {
            return true;
        }
        return (value & (value - 1)) == 0;
    }

    /**
     * @dev checkedMultiply multiplies two uint64 values and returns the result and a boolean indicating whether the multiplication
     * overflowed.
     * @param _a is the first value
     * @param _b is the second value
     * @return the result and a boolean indicating whether the multiplication overflowed
     */
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

    /**
     * @dev truncate truncates a node to 254 bits.
     * @param _n is the node
     * @return the truncated node
     */
    function truncate(bytes32 n) internal pure returns (bytes32) {
        // Set the two lowest-order bits of the last byte to 0
        return n & TRUNCATOR;
    }

    /**
     * @dev verify verifies that the given leaf is present in the merkle tree with the given root.
     * @param _proof is the proof data
     * @param _root is the root of the Merkle tree
     * @param _leaf is the leaf
     * @return true if the given leaf is present in the merkle tree with the given root
     */
    function verify(
        ProofData memory proof,
        bytes32 root,
        bytes32 leaf
    ) public pure returns (bool) {
        return computeRoot(proof, leaf) == root;
    }

    /**
     * @dev processProof computes the root of the merkle tree given the leaf and the inclusion proof.
     * @param _proof is the proof data
     * @param _leaf is the leaf
     * @return the root of the merkle tree
     */
    function processProof(
        ProofData memory proof,
        bytes32 leaf
    ) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.path.length; i++) {
            computedHash = hashNode(computedHash, proof.path[i]);
        }
        return computedHash;
    }

    /**
     * @dev hashNode hashes the given node with the given left child.
     * @param _left is the left child
     * @param _right is the right child
     * @return the hash of the given node with the given left child
     */
    function hashNode(bytes32 left, bytes32 right) public pure returns (bytes32) {
        bytes32 truncatedData = sha256(abi.encodePacked(left, right));
        truncatedData &= TRUNCATOR;
        return truncatedData;
    }

    /**
     * @dev truncatedHash computes the truncated hash of the given data.
     * @param _data is the data
     * @return the truncated hash of the given data
     */
    function truncatedHash(bytes memory data) public pure returns (bytes32) {
        bytes32 truncatedData = sha256(abi.encodePacked(data));
        truncatedData &= TRUNCATOR;
        return truncatedData;
    }

    /**
     * @dev makeDataSegmentIndexEntry creates a new data segment index entry.
     * @param _commP is the piece commitment
     * @param _offset is the offset
     * @param _size is the size
     * @return the new data segment index entry
     */
    function makeDataSegmentIndexEntry(
        Fr32 memory commP,
        uint64 offset,
        uint64 size
    ) internal pure returns (SegmentDesc memory) {
        SegmentDesc memory en;
        en.commDs = bytes32(commP.value);
        en.offset = offset;
        en.size = size;
        en.checksum = computeChecksum(en);
        return en;
    }

    /**
     * @dev computeChecksum computes the checksum of the given segment description.
     * @param _sd is the segment description
     * @return the checksum of the given segment description
     */
    function computeChecksum(SegmentDesc memory _sd) public pure returns (bytes16) {
        bytes memory serialized = serialize(_sd);
        bytes32 digest = sha256(serialized);
        digest &= hex"ffffffffffffffffffffffffffffff3f";
        return bytes16(digest);
    }

    /**
     * @dev serialize serializes the given segment description.
     * @param _sd is the segment description
     * @return the serialized segment description
     */
    function serialize(SegmentDesc memory sd) public pure returns (bytes memory) {
        bytes memory result = new bytes(ENTRY_SIZE);

        // Pad commDs
        bytes32 commDs = sd.commDs;
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

    /**
     * @dev leadingZeros64 returns the number of leading zeros in the given uint64.
     * @param _x is the uint64
     * @return the number of leading zeros in the given uint64
     */
    function leadingZeros64(uint64 x) internal pure returns (uint256) {
        return 64 - len64(x);
    }

    /**
     * @dev len64 returns the number of bits in the given uint64.
     * @param _x is the uint64
     * @return the number of bits in the given uint64
     */
    function len64(uint64 x) internal pure returns (uint256) {
        uint256 count = 0;
        while (x > 0) {
            x = x >> 1;
            count++;
        }
        return count;
    }

    /**
     * @dev log2Ceil returns the ceiling of the base-2 logarithm of the given value.
     * @param _value is the value
     * @return the ceiling of the base-2 logarithm of the given value
     */
    function log2Ceil(uint64 value) internal pure returns (int) {
        if (value <= 1) {
            return 0;
        }
        return log2Floor(value - 1) + 1;
    }

    /**
     * @dev log2Floor returns the floor of the base-2 logarithm of the given value.
     * @param _value is the value
     * @return the floor of the base-2 logarithm of the given value
     */
    function log2Floor(uint64 value) internal pure returns (int) {
        if (value == 0) {
            return 0;
        }
        uint zeros = leadingZeros64(value);
        return int(64 - zeros - 1);
    }
}
