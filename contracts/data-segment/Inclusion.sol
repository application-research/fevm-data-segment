// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Inclusion {

    function verify(bytes32 root, bytes32 leaf, bytes32[] memory proof) public pure returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }

    struct ProofData {
        uint256 index;
        bytes32[] path;
    }

    function computeRoot(ProofData memory d, bytes32 subtree) public pure returns (bytes32) {
        require(d.path.length < 64, "merkleproofs with depths greater than 63 are not supported");
        require(d.index >> d.path.length == 0, "index greater than width of the tree");
        
        bytes32 carry = subtree;
        uint256 index = d.index;
        uint256 right = 0;

        for (uint256 i = 0; i < d.path.length; i++) {
            (right, index) = (index & 1, index >> 1);
            if (right == 1) {
                carry = keccak256(abi.encodePacked(d.path[i], carry));
            } else {
                carry = keccak256(abi.encodePacked(carry, d.path[i]));
            }
        }

        return carry;
    }

}