// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibDiamond} from "../diamond/libraries/LibDiamond.sol";
import {IERC173} from "../diamond/interfaces/IERC173.sol";

/// @title OwnershipFacet — Ownable2Step 所有权管理
/// @dev 两步转移：transferOwnership 设置 pendingOwner，acceptOwnership 完成转移。
///      转给 address(0) 直接放弃权限（无需二步确认）。
contract OwnershipFacet is IERC173 {
    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        if (_newOwner == address(0)) {
            // 放弃权限：直接生效
            LibDiamond.setContractOwner(address(0));
        } else {
            // 两步转移：设置 pendingOwner
            LibDiamond.setPendingOwner(_newOwner);
        }
    }

    function acceptOwnership() external {
        LibDiamond.acceptPendingOwner();
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    function pendingOwner() external view returns (address) {
        return LibDiamond.pendingOwner();
    }
}
