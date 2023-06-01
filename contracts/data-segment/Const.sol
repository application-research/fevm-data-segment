// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// CID_COMMP_HEADER is the header of a CID for a piece commitment
bytes7 constant CID_COMMP_HEADER = hex"0181e203922020";
// CID_COMMP_HEADER_LENGTH is the length of the header of a CID for a piece commitment
uint8 constant CID_COMMP_HEADER_LENGTH = 7;

// Proofs
// Merkle tree node size
uint8 constant MERKLE_TREE_NODE_SIZE = 32;

// Truncator is used to truncate the Merkle tree node
bytes32 constant TRUNCATOR = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3f;

// num of bytes in an int
uint64 constant BYTES_IN_INT = 8;

// num of bytes in a checksum
uint64 constant CHECKSUM_SIZE = 16;

// num of bytes in a data segment entry
uint64 constant ENTRY_SIZE = uint64(MERKLE_TREE_NODE_SIZE) + 2 * BYTES_IN_INT + CHECKSUM_SIZE;

// num of bytes in a data segment entry
uint64 constant BYTES_IN_DATA_SEGMENT_ENTRY = 2 * MERKLE_TREE_NODE_SIZE;
