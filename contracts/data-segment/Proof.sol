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
        InclusionProof memory _ip,
        InclusionVerifierData memory _verifierData
    ) public pure returns (InclusionAuxData memory) {
        require(
            isPow2(uint64(_verifierData.sizePc)),
            "Size of piece provided by verifier is not power of two"
        );

        // Compute the root of the subtree containing all the nodes (leafs) of the data segment
        // The root of the subtree is the piece commitment of the data segment (commPc)
        bytes32 commPc = _verifierData.commPc.cidToPieceCommitment();
        bytes32 assumedCommPa = computeRoot(_ip.proofSubtree, commPc);

        // check that the aggregator's data commitments dont overflow
        (bool ok, uint64 assumedSizePa) = checkedMultiply(
            uint64(1) << uint64(_ip.proofSubtree.path.length),
            uint64(_verifierData.sizePc)
        );
        require(ok, "assumedSizePa overflow");

        // check that the aggregator's data commitments match
        uint64 dataOffset = _ip.proofSubtree.index * uint64(_verifierData.sizePc);
        SegmentDesc memory en = makeDataSegmentIndexEntry(
            Fr32(commPc),
            dataOffset,
            uint64(_verifierData.sizePc)
        );
        bytes32 enNode = truncatedHash(serialize(en));
        bytes32 assumedCommPa2 = computeRoot(_ip.proofIndex, enNode);
        require(
            assumedCommPa == assumedCommPa2,
            "aggregator's data commitments don't match"
        );

        // check that the aggregator's data size matches
        (bool ok2, uint64 assumedSizePa2) = checkedMultiply(
            uint64(1) << uint64(_ip.proofIndex.path.length),
            BYTES_IN_DATA_SEGMENT_ENTRY
        );
        require(ok2, "assumedSizePau64 overflow");
        require(assumedSizePa == assumedSizePa2, "aggregator's data size doesn't match");

        validateIndexEntry(_ip, assumedSizePa2);
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
    // function computeExpectedAuxDataWithDeal(
    //     uint64 _dealId,
    //     InclusionProof memory _ip,
    //     InclusionVerifierData memory _verifierData
    // ) public returns (InclusionAuxData memory) {
    //     InclusionAuxData memory inclusionAuxData = computeExpectedAuxData(_ip, _verifierData);
    //     validateInclusionAuxData(_dealId, inclusionAuxData);
    //     return inclusionAuxData;
    // }

    /**
     * @dev validateInclusionAuxData validates that the deal is activated and not terminated.
     * @param _dealId is the deal ID
     * @param _inclusionAuxData is the inclusion auxiliary data
     */
    // function validateInclusionAuxData(uint64 _dealId, InclusionAuxData memory _inclusionAuxData) internal {
    //     // check that the deal is not terminated
    //     MarketTypes.GetDealActivationReturn memory dealActivation = MarketAPI.getDealActivation(_dealId);
    //     require(dealActivation.terminated <= 0, "Deal is terminated");
    //     require(dealActivation.activated > 0, "Deal is not activated");

    //     MarketTypes.GetDealDataCommitmentReturn memory dealDataCommitment = MarketAPI.getDealDataCommitment(_dealId);
    //     require(keccak256(dealDataCommitment.data) == keccak256(_inclusionAuxData.commPa), "Deal commD doesn't match");
    //     require(dealDataCommitment.size == _inclusionAuxData.sizePa, "Deal size doesn't match");
    // }

    /**
     * @dev validateIndexEntry validates that the index entry is in the correct position in the index.
     * @param _ip is the inclusion proof
     * @param _assumedSizePa is the assumed size of the aggregator's data
     */
    function validateIndexEntry(InclusionProof memory _ip, uint64 _assumedSizePa) internal pure {
        uint64 idxStart = indexAreaStart(_assumedSizePa);
        (bool ok3, uint64 indexOffset) = checkedMultiply(
            _ip.proofIndex.index,
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
        ProofData memory _d,
        bytes32 _subtree
    ) public pure returns (bytes32) {
        require(_d.path.length < 64, "merkleproofs with depths greater than 63 are not supported");
        require(_d.index >> _d.path.length == 0, "index greater than width of the tree");

        bytes32 carry = _subtree;
        uint64 index = _d.index;
        uint64 right = 0;

        for (uint64 i = 0; i < _d.path.length; i++) {
            (right, index) = (index & 1, index >> 1);
            if (right == 1) {
                carry = computeNode(_d.path[i], carry);
            } else {
                carry = computeNode(carry, _d.path[i]);
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
    function computeNode(bytes32 _left, bytes32 _right) public pure returns (bytes32) {
        bytes32 digest = sha256(abi.encodePacked(_left, _right));
        return truncate(digest);
    }

    /**
     * @dev indexAreaStart returns the offset of the start of the index area in the deal.
     * @param _sizePa is the size of the aggregator's data
     * @return the offset of the start of the index area in the deal
     */
    function indexAreaStart(uint64 _sizePa) internal pure returns (uint64) {
        return uint64(_sizePa) - uint64(maxIndexEntriesInDeal(_sizePa)) * uint64(ENTRY_SIZE);
    }

    /**
     * @dev maxIndexEntriesInDeal returns the maximum number of index entries that can be stored in a deal of the given size.
     * @param _dealSize is the size of the deal
     * @return the maximum number of index entries that can be stored in a deal of the given size
     */
    function maxIndexEntriesInDeal(uint256 _dealSize) internal pure returns (uint) {
        uint res = (uint(1) << uint256(log2Ceil(uint64(_dealSize / 2048 / ENTRY_SIZE)))); //& ((1 << 256) - 1);
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
    function isPow2(uint64 _value) internal pure returns (bool) {
        if (_value == 0) {
            return true;
        }
        return (_value & (_value - 1)) == 0;
    }

    /**
     * @dev checkedMultiply multiplies two uint64 values and returns the result and a boolean indicating whether the multiplication
     * overflowed.
     * @param _a is the first value
     * @param _b is the second value
     * @return the result and a boolean indicating whether the multiplication overflowed
     */
    function checkedMultiply(uint64 _a, uint64 _b) internal pure returns (bool, uint64) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (_a == 0) return (true, 0);
            uint64 c = _a * _b;
            if (c / _a != _b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev truncate truncates a node to 254 bits.
     * @param _n is the node
     * @return the truncated node
     */
    function truncate(bytes32 _n) internal pure returns (bytes32) {
        // Set the two lowest-order bits of the last byte to 0
        return _n & TRUNCATOR;
    }

    /**
     * @dev verify verifies that the given leaf is present in the merkle tree with the given root.
     * @param _proof is the proof data
     * @param _root is the root of the Merkle tree
     * @param _leaf is the leaf
     * @return true if the given leaf is present in the merkle tree with the given root
     */
    function verify(
        ProofData memory _proof,
        bytes32 _root,
        bytes32 _leaf
    ) public pure returns (bool) {
        return computeRoot(_proof, _leaf) == _root;
    }

    /**
     * @dev processProof computes the root of the merkle tree given the leaf and the inclusion proof.
     * @param _proof is the proof data
     * @param _leaf is the leaf
     * @return the root of the merkle tree
     */
    function processProof(
        ProofData memory _proof,
        bytes32 _leaf
    ) internal pure returns (bytes32) {
        bytes32 computedHash = _leaf;
        for (uint256 i = 0; i < _proof.path.length; i++) {
            computedHash = hashNode(computedHash, _proof.path[i]);
        }
        return computedHash;
    }

    /**
     * @dev hashNode hashes the given node with the given left child.
     * @param _left is the left child
     * @param _right is the right child
     * @return the hash of the given node with the given left child
     */
    function hashNode(bytes32 _left, bytes32 _right) public pure returns (bytes32) {
        bytes32 truncatedData = sha256(abi.encodePacked(_left, _right));
        truncatedData &= TRUNCATOR;
        return truncatedData;
    }

    /**
     * @dev truncatedHash computes the truncated hash of the given data.
     * @param _data is the data
     * @return the truncated hash of the given data
     */
    function truncatedHash(bytes memory _data) public pure returns (bytes32) {
        bytes32 truncatedData = sha256(abi.encodePacked(_data));
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
        Fr32 memory _commP,
        uint64 _offset,
        uint64 _size
    ) internal pure returns (SegmentDesc memory) {
        SegmentDesc memory en;
        en.commDs = bytes32(_commP.value);
        en.offset = _offset;
        en.size = _size;
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
    function serialize(SegmentDesc memory _sd) public pure returns (bytes memory) {
        bytes memory result = new bytes(ENTRY_SIZE);

        // Pad commDs
        bytes32 commDs = _sd.commDs;
        assembly {
            mstore(add(result, 32), commDs)
        }

        // Pad offset (little-endian)
        for (uint i = 0; i < 8; i++) {
            result[MERKLE_TREE_NODE_SIZE + i] = bytes1(uint8(_sd.offset >> (i * 8)));
        }

        // Pad size (little-endian)
        for (uint i = 0; i < 8; i++) {
            result[MERKLE_TREE_NODE_SIZE + 8 + i] = bytes1(uint8(_sd.size >> (i * 8)));
        }

        // Pad checksum
        for (uint i = 0; i < 16; i++) {
            result[MERKLE_TREE_NODE_SIZE + 16 + i] = _sd.checksum[i];
        }

        return result;
    }

    /**
     * @dev leadingZeros64 returns the number of leading zeros in the given uint64.
     * @param _x is the uint64
     * @return the number of leading zeros in the given uint64
     */
    function leadingZeros64(uint64 _x) internal pure returns (uint256) {
        return 64 - len64(_x);
    }

    /**
     * @dev len64 returns the number of bits in the given uint64.
     * @param _x is the uint64
     * @return the number of bits in the given uint64
     */
    function len64(uint64 _x) internal pure returns (uint256) {
        uint256 count = 0;
        while (_x > 0) {
            _x = _x >> 1;
            count++;
        }
        return count;
    }

    /**
     * @dev log2Ceil returns the ceiling of the base-2 logarithm of the given value.
     * @param _value is the value
     * @return the ceiling of the base-2 logarithm of the given value
     */
    function log2Ceil(uint64 _value) internal pure returns (int) {
        if (_value <= 1) {
            return 0;
        }
        return log2Floor(_value - 1) + 1;
    }

    /**
     * @dev log2Floor returns the floor of the base-2 logarithm of the given value.
     * @param _value is the value
     * @return the floor of the base-2 logarithm of the given value
     */
    function log2Floor(uint64 _value) internal pure returns (int) {
        if (_value == 0) {
            return 0;
        }
        uint zeros = leadingZeros64(_value);
        return int(64 - zeros - 1);
    }
}
