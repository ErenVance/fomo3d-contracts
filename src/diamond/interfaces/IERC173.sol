// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title ERC-173 合约所有权标准
interface IERC173 {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() external view returns (address owner_);

    function transferOwnership(address _newOwner) external;
}
