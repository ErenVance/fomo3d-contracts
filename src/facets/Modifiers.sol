// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibAppStorage, AppStorage} from "../storage/AppStorage.sol";
import {LibErrors} from "../libraries/LibErrors.sol";

/// @title Modifiers — 所有 facet 的基合约
/// @dev 提供 nonReentrant 和 whenNotPaused 修饰符
abstract contract Modifiers {
    // ReentrancyGuard 使用独立存储槽，避免与 AppStorage 冲突
    bytes32 private constant _REENTRANCY_GUARD_SLOT = keccak256("fomo3d.reentrancy.guard");

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    modifier nonReentrant() {
        bytes32 slot = _REENTRANCY_GUARD_SLOT;
        uint256 status;
        assembly {
            status := sload(slot)
        }
        require(status != _ENTERED, "ReentrancyGuard: reentrant call");
        assembly {
            sstore(slot, _ENTERED)
        }
        _;
        assembly {
            sstore(slot, _NOT_ENTERED)
        }
    }

    modifier whenNotPaused() {
        AppStorage storage s = LibAppStorage.appStorage();
        if (s.paused) revert LibErrors.Paused();
        _;
    }

    modifier whenPaused() {
        AppStorage storage s = LibAppStorage.appStorage();
        if (!s.paused) revert LibErrors.NotPaused();
        _;
    }

    modifier onlyEOA() {
        if (msg.sender != tx.origin) revert LibErrors.NotEOA();
        _;
    }
}
