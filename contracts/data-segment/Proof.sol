// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract Proof {

    struct Node {
        bytes32 data;
    }

    struct ProofData {
        uint256 index;
        Node[] path;
    }

    function computeRoot(ProofData memory d, Node memory subtree) public pure returns (Node memory) {
        require(d.path.length < 64, "merkleproofs with depths greater than 63 are not supported");
        require(d.index >> d.path.length == 0, "index greater than width of the tree");
        
        Node memory carry = subtree;
        uint256 index = d.index;
        uint256 right = 0;

        for (uint256 i = 0; i < d.path.length; i++) {
            (right, index) = (index & 1, index >> 1);
            if (right == 1) {
                carry = computeNode(d.path[i], carry);
            } else {
                carry = computeNode(carry, d.path[i]);
            }
        }

        return carry;
    }

    function computeNode(Node memory left, Node memory right) internal pure returns (Node memory) {
        bytes32 digest = sha256(abi.encodePacked(left.data, right.data));
        Node memory result = Node(digest);
        return truncate(result);
    }

    function truncate(Node memory n) internal pure returns (Node memory) {
        bytes32 mask = 0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        bytes32 newData = n.data & mask;
        return Node(newData);
    }
}