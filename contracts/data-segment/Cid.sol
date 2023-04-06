// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

library Cid {
    bytes7 public constant CID_COMMP_HEADER = hex"0181e203922020";
    uint8 public constant CID_COMMP_HEADER_LENGTH = 7;
    uint8 public constant MERKLE_TREE_NODE_SIZE = 32;

    function cidToPieceCommitment(bytes memory _cb) public pure returns (bytes32) {
        require(_cb.length == MERKLE_TREE_NODE_SIZE + CID_COMMP_HEADER_LENGTH, "wrong length of CID");
        require(
            keccak256(abi.encodePacked(_cb[0], _cb[1], _cb[2], _cb[3], _cb[4], _cb[5], _cb[6])) == 
            keccak256(abi.encodePacked(CID_COMMP_HEADER)),
            "wrong content of CID header"
        );
        bytes32 res;
        assembly {
            res := mload(add(add(_cb, CID_COMMP_HEADER_LENGTH), MERKLE_TREE_NODE_SIZE))
        }
        return res;
    }

    function pieceCommitmentToCid(bytes32 _commp) public pure returns (bytes memory) {
        bytes memory cb = abi.encodePacked(CID_COMMP_HEADER, _commp);
        return cb;
    }
}
