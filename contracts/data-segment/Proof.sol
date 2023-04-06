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

    function computeExpectedAuxData(InclusionProof memory ip, InclusionVerifierData memory veriferData) public pure returns (InclusionAuxData memory) {
        bytes32 commPc = veriferData.commPc.cidToPieceCommitment();
        Node memory nodeCommPc = Node(commPc);
        Node memory assumedCommPa = computeRoot(ip.proofSubtree, nodeCommPc);

        (uint64 assumedSizePa, bool ok) = checkedMultiply(uint64(1)<<uint64(ip.proofSubtree.path.length), uint64(veriferData.sizePc));
        require(ok, "assumedSizePa overflow");

        uint64 dataOffset = ip.proofSubtree.index * uint64(veriferData.sizePc);

        // TODO: Question: Do we need to cast nodeCommPc to Fr32 which would simply cast it back to Node?
        SegmentDesc memory en = makeDataSegmentIndexEntry(Fr32(nodeCommPc.data), dataOffset, uint64(veriferData.sizePc));

        InclusionAuxData memory auxData = InclusionAuxData(assumedCommPa.data.pieceCommitmentToCid(), assumedSizePa);
        return auxData;
    }

    function checkedMultiply(uint64 a, uint64 b) public pure returns (uint64, bool) {
        uint256 hi;
        uint64 lo = uint64(mulmod(a, b, uint256(1) << 64));
        assembly {
            hi := gt(lo, a)
        }
        return (lo, hi == 0);
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

    struct SegmentDesc {
        Node commDs;
        uint64 offset;
        uint64 size;
        bytes32 checksum;
    }

    struct Fr32 {
        bytes32 value;
    }

    uint private constant ChecksumSize = 16;

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

}