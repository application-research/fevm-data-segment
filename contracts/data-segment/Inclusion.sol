// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract MerkleTree {
    uint256 constant NodeSize = 32;

    struct Node {
        bytes32 data;
    }

    struct TreeData {
        Node[][] nodes;
        uint64 leafs;
    }

    TreeData public tree;
    
    constructor(uint64 _leafs) {
        tree = newBareTree(_leafs);
    }

    function newBareTree(uint64 _leafs) internal pure returns (TreeData memory) {
        uint256 adjustedLeafs = 1 << Log2Ceil(_leafs);
        TreeData memory tree;
        tree.nodes = new Node[][](1 + Log2Ceil(uint64(adjustedLeafs)));
        tree.leafs = _leafs;
        for (uint256 i = 0; i <= Log2Ceil(uint64(adjustedLeafs)); i++) {
            tree.nodes[i] = new Node[](1 << i);
        }
        return tree;
    }

/*
    function hashList(bytes[][] memory leafData) internal pure returns (Node[] memory) {
        Node[] memory nodes = new Node[](leafData.length);
        for (uint256 i = 0; i < leafData.length; i++) {
            nodes[i] = Node(sha256(abi.encode(leafData[i])));
        }
        return nodes;
    }
*/
    function computeNode(Node memory _left, Node memory _right) internal pure returns (Node memory) {
        bytes memory data = abi.encodePacked(_left.data, _right.data);
        return Node(sha256(data));
    }

    function getSiblingIdx(uint64 _idx) internal pure returns (uint64) {
        if (_idx % 2 == 0) {
            return _idx + 1;
        } else {
            return _idx - 1;
        }
    }

    // Proof data is a list of nodes that are on the path from the leaf to the root
    struct ProofData {
        Node[] path;
        uint64 index;
    }

    function computeRoot(ProofData memory _proof, Node memory subtree) public pure returns (Node memory) {
        require(_proof.path.length <= 63, "merkleproofs with depths greater than 63 are not supported");
        require(_proof.index < (1 << _proof.path.length), "index greater than width of the tree");

        Node memory carry = subtree;
        uint64 index = _proof.index;
        uint64 right = 0;

        for (uint256 i = 0; i < _proof.path.length; i++) {
            Node memory p = _proof.path[i];
            (right, index) = (index & 1, index >> 1);
            if (right == 1) {
                carry = computeNode(p, carry);
            } else {
                carry = computeNode(carry, p);
            }
        }

        return carry;
    }
    
    function DeserializeTree(bytes memory tree) internal pure returns (TreeData memory) {
        require(tree.length >= 8, "error in tree encoding, does not contain level 0");
        uint64 lvlSize = uint64(uint8(tree[0])) |
            (uint64(uint8(tree[1])) << 8) |
            (uint64(uint8(tree[2])) << 16) |
            (uint64(uint8(tree[3])) << 24) |
            (uint64(uint8(tree[4])) << 32) |
            (uint64(uint8(tree[5])) << 40) |
            (uint64(uint8(tree[6])) << 48) |
            (uint64(uint8(tree[7])) << 56);
        TreeData memory decoded = newBareTree(lvlSize);
        lvlSize = uint64(1 << Log2Ceil(lvlSize));
        uint256 ctr = 8;
        for (uint256 i = decoded.nodes.length - 1; i >= 0; i--) {
            require(tree.length >= ctr + NodeSize * uint256(lvlSize), "error in tree encoding, does not contain level i");
            Node[] memory currentLvl = new Node[](lvlSize);
            for (uint256 j = 0; j < lvlSize; j++) {
                Node memory node;
                assembly {
                    node := mload(add(add(tree, 32), ctr))
                }
                currentLvl[j] = node;
                ctr += NodeSize;
            }
            decoded.nodes[i] = currentLvl;
            lvlSize = lvlSize >> 1;
        }
        return decoded;
    }

    // padLeafs pads the leaf nodes to a power of 2, if necessary
    function padLeafs(Node[] memory leafs) private pure returns (Node[] memory) {
        uint256 n = leafs.length;
        uint256 paddedSize = 1;
        while (paddedSize < n) {
            paddedSize *= 2;
        }
        Node[] memory paddedLeafs = new Node[](paddedSize);
        for (uint256 i = 0; i < n; i++) {
            paddedLeafs[i] = leafs[i];
        }
        return paddedLeafs;
    }

    // Depth returns the amount of levels in the tree, including the root level and leafs.
    // I.e. a tree with 3 leafs will have one leaf level, a middle level and a root, and hence Depth 3.
    function depth() public view returns (uint256) {
        return tree.nodes.length;
    }

    // LeafCount returns the amount of non-zero padded leafs in the tree
    function leafCount() public view returns (uint64) {
        return tree.leafs;
    }

    // Root returns a pointer to the root node
    function root() public view returns (Node memory) {
        return tree.nodes[0][0];
    }

    // Leafs return a slice consisting of all the leaf nodes, i.e. leaf data that has been hashed into a Node structure
    function leafs() public view returns (Node[] memory) {
        return tree.nodes[tree.nodes.length - 1];
    }

    // Node returns the node at given lvl and idx
    function node(uint256 lvl, uint256 idx) public view returns (bytes32) {
        return tree.nodes[lvl][idx].data;
    }

    // ValidateFromLeafs validates the structure of this Merkle tree, given the raw data elements the tree was constructed from
    function validateFromLeafs(bytes[] memory leafs) public returns (bool) {
        TreeData memory comp = GrowTree(leafs);
        return compare(comp);
    }

    // Validate returns true of this tree has been constructed correctly from the leafs (hashed data)
    function validate() public returns (bool) {
        TreeData memory comp = GrowTreeHashedLeafs(tree.nodes[tree.nodes.length - 1]);
        return compare(comp);
    }

    // ConstructProof constructs a proof that a node at level lvl and index idx within that level, is contained in the tree.
    // The root is in level 0 and the left-most node in a given level is indexed 0.
    function constructProof(uint256 lvl, uint64 idx) public view returns (ProofData memory) {
        require(lvl > 0 && lvl < tree.nodes.length, "Invalid level");
        require(idx < tree.nodes[lvl].length, "Invalid index");

        // The proof consists of appropriate siblings up to and including layer 1
        Node[] memory proof = new Node[](lvl);
        uint64 currentIdx = idx;

        // Compute the node we wish to prove membership of to the root
        for (uint256 currentLvl = lvl; currentLvl >= 1; currentLvl--) {
            // For error handling check that no index impossibly large is requested
            require(tree.nodes[currentLvl].length > currentIdx, "Invalid index");
            // Only try to store the sibling node when it exists,
            // if the tree is not complete this might not always be the case
            if (tree.nodes[currentLvl].length > getSiblingIdx(currentIdx)) {
                proof[currentLvl-1] = computeNode(tree.nodes[currentLvl][currentIdx], tree.nodes[currentLvl][getSiblingIdx(currentIdx)]);
            }
            // Set next index to be the parent
            currentIdx = currentIdx / 2;
        }

        return ProofData(proof, idx);
    }
/*
    function Serialize() external view returns (bytes memory) {
        bytes memory buf = new bytes(8);
        buf.writeUint64(uint64(leafCount()));

        for (uint256 i = depth() - 1; int256(i) >= 0; i--) {
            bytes memory layer = new bytes(NodeSize * tree.nodes[i].length);
            uint256 offset = 0;

            for (uint256 j = 0; j < tree.nodes[i].length; j++) {
                for (uint256 k = 0; k < NodeSize; k++) {
                    layer[offset + k] = tree.nodes[i][j][k];
                }
                offset += NodeSize;
            }

            buf = abi.encodePacked(buf, layer);
        }

        return buf;
    }
*/
    // GrowTree constructs a Merkle from a list of leafData, the data of a given leaf is represented as a byte slice
    // The construction rounds the amount of leafs up to the nearest two-power with zeroed nodes to ensure
    // that the tree is perfect and hence all internal node's have well-defined children.
    function GrowTree(bytes[] memory leafData) public view returns (TreeData memory) {
        require(leafData.length > 0, "empty input");
        Node[] memory leafLevel = hashList(leafData);
        TreeData memory tree = GrowTreeHashedLeafs(leafLevel);
        return tree;
    }

    // GrowTreeHashedLeafs constructs a tree from leafs nodes, i.e. leaf data that has been hashed to construct a Node
    function GrowTreeHashedLeafs(Node[] memory leafs) internal view returns (TreeData memory) {
        TreeData memory tree = newBareTree(uint64(leafs.length));
        tree.leafs = uint64(leafs.length);
        // Set the padded leaf nodes
        tree.nodes[depth()-1] = padLeafs(leafs);
        Node[] memory parentNodes = tree.nodes[tree.nodes.length-1];
        // Construct the Merkle tree bottom-up, starting from the leafs
        // Note the -1 due to 0-indexing the root level
        for (uint256 level = tree.nodes.length-2; level >= 0; level--) {
            Node[] memory currentLevel = new Node[](uint256(Ceil(parentNodes.length, 2)));
            // Traverse the level left to right
            for (uint256 i = 0; i+1 < parentNodes.length; i = i + 2) {
                currentLevel[i/2] = computeNode(parentNodes[i], parentNodes[i+1]);
            }
            tree.nodes[level] = currentLevel;
            parentNodes = currentLevel;
        }
        return tree;
    }


    // utilties
    function LeadingZeros64(uint64 x) internal pure returns (uint256) {
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

    function Log2Ceil(uint64 value) internal pure returns (uint256) {
        if (value <= 1) {
            return 0;
        }
        return Log2Floor(value - 1) + 1;
    }

    function Log2Floor(uint64 value) internal pure returns (uint256) {
        if (value == 0) {
            return 0;
        }
        uint256 zeros = LeadingZeros64(value);
        return uint256(64 - zeros - 1);
    }

    function hashList(bytes[] memory input) internal pure returns (Node[] memory) {
        Node[] memory digests = new Node[](input.length);
        for (uint256 i = 0; i < input.length; i++) {
            digests[i] = TruncatedHash(input[i]);
        }
        return digests;
    }
    
    function TruncatedHash(bytes memory data) internal pure returns (Node memory) {
        bytes32 digest = sha256(data);
        Node memory node = Node(digest);
        return truncate(node);
    }
    
    /*
    function truncate2(Node memory node) internal pure returns (Node memory) {
        // Truncate to 32 bytes by casting to bytes32
        node.value = bytes32(node.value);
        return node;
    }
    */

    function truncate(Node memory n) public pure returns (Node memory) {
        // Clear the two most significant bits of the last byte
        n.data &= bytes32(0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        return n;
    }

    function trun(bytes32 n) public pure returns (bytes32) {
        bytes32 mask = 0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        return n & mask;
    }
    
    function Ceil(uint x, uint y) internal pure returns (int) {
        if (x == 0) {
            return 0;
        }
        return int(1 + ((x - 1) / y));
    }

    function compare(TreeData memory tree2) internal view returns (bool) {
        if (tree.nodes.length != tree2.nodes.length || tree.leafs != tree2.leafs) {
            return false;
        }

        for (uint i = 0; i < tree.nodes.length; i++) {
            if (tree.nodes[i].length != tree2.nodes[i].length) {
                return false;
            }

            for (uint j = 0; j < tree.nodes[i].length; j++) {
                if (tree.nodes[i][j].data != tree2.nodes[i][j].data) {
                    return false;
                }
            }
        }

        return true;
    }

    function compareTrees(TreeData memory tree1, Node[][] memory tree2Nodes) internal pure returns (bool) {
        if (tree1.nodes.length != tree2Nodes.length) {
            return false;
        }

        for (uint i = 0; i < tree1.nodes.length; i++) {
            if (tree1.nodes[i].length != tree2Nodes[i].length) {
                return false;
            }

            for (uint j = 0; j < tree1.nodes[i].length; j++) {
                if (tree1.nodes[i][j].data != tree2Nodes[i][j].data) {
                    return false;
                }
            }
        }

        return true;
    }


}