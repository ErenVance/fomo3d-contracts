// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibExit} from "../libraries/LibExit.sol";
import {IFomo3DEvents} from "../interfaces/IFomo3DEvents.sol";
import {Modifiers} from "./Modifiers.sol";

contract ExitFacet is Modifiers, IFomo3DEvents {
    /// @notice 活跃轮次中退出，领取分红（扣 dev fee）
    function exitGame() external nonReentrant whenNotPaused onlyEOA {
        LibExit.exitGame(msg.sender);
    }

    /// @notice 轮次结束后结算未退出的 shares（带惩罚）+ 领取大奖
    /// @dev 不受 pause 限制，用户在暂停期间仍可结算和领奖
    function settleUnexited() external nonReentrant onlyEOA {
        LibExit.settleUnexited(msg.sender);
    }
}
