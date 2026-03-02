// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibLifecycle} from "../libraries/LibLifecycle.sol";
import {IFomo3DEvents} from "../interfaces/IFomo3DEvents.sol";
import {Modifiers} from "./Modifiers.sol";

contract LifecycleFacet is Modifiers, IFomo3DEvents {
    /// @notice 倒计时结束后发放大奖并开启下一轮（任何人都可调用）
    /// @dev 不受 pause 限制：轮次生命周期事件不应被暂停阻止，否则大奖分配会被冻结
    function endRoundAndDistribute() external nonReentrant {
        LibLifecycle.endRoundAndDistribute();
    }
}
