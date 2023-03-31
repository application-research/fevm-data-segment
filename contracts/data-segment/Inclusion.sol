// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Inclusion {

    function verify(bytes32 root, bytes32 leaf, bytes32[] memory proof) public pure returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }

    function computeRoot(bytes32 leaf, bytes32[] memory proof, uint256 height) public pure returns (bytes32) {
        require(proof.length == height, "Invalid proof length");

        bytes32 currentHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 siblingHash = proof[i];

            if ((height >> i) & 1 == 1) {
                currentHash = keccak256(abi.encodePacked(siblingHash, currentHash));
            } else {
                currentHash = keccak256(abi.encodePacked(currentHash, siblingHash));
            }
        }

        return currentHash;
    }

}