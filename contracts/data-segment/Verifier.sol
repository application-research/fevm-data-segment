// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

library Verifier {
    struct InclusionAuxData {
        bytes cid;
        uint64 sizePa;
    }
    struct InclusionVerifierData {
        bytes cid;
        uint64 sizePa;
    }
    struct SegmentDescIdx {
        bytes32 commDs;
        uint64 offset;
        uint64 size;
        bytes16 checksum;
    }
    struct ProofData {
        bytes16[] path;
        uint64 index;
    }

    function CIDToPieceCommitmentV1(bytes memory cid)
        public
        view
        returns (bytes memory)
    {}

    function PieceCommitmentV1ToCID(bytes memory pc)
        public
        view
        returns (bytes memory)
    {}

    function ComputeExpectedAuxData(InclusionVerifierData memory data)
        public
        view
        returns (InclusionAuxData memory)
    {}

    function ComputeRoot(ProofData memory data, bytes16 node)
        external
        pure
        returns (bytes16)
    {}

    function SerializeFr32(SegmentDescIdx memory sdi)
        public
        view
        returns (bytes memory)
    {}

    function serializeFr32Entry(SegmentDescIdx memory entry)
        public
        view
        returns (bytes memory)
    {}

    function computeChecksum(SegmentDescIdx memory sdi)
        public
        view
        returns (bytes16)
    {}

    function computeNode(bytes16 left, bytes16 right)
        public
        view
        returns (bytes16)
    {}
}