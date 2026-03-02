// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibAppStorage, AppStorage} from "../storage/AppStorage.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibConstants} from "./LibConstants.sol";
import {IFomo3DEvents} from "../interfaces/IFomo3DEvents.sol";

/// @title LibAdmin — 管理配置逻辑库
/// @dev AdminFacet 的所有业务逻辑（验证 + 存储 + 事件）
library LibAdmin {
    /// @notice 设置销毁代币地址
    /// @dev 管理员须确保 token 没有 fee-on-transfer 机制。
    ///      如果 token 有转账税，purchase 中实际到账金额会小于 tokenAmount，导致 shares 超发。
    function setToken(address token) internal {
        if (token == address(0)) revert LibErrors.ZeroAddress();
        AppStorage storage s = LibAppStorage.appStorage();
        s.burnToken = token;
        emit IFomo3DEvents.TokenSet(token);
    }

    function setDevAddress(address dev) internal {
        if (dev == address(0)) revert LibErrors.ZeroAddress();
        AppStorage storage s = LibAppStorage.appStorage();
        s.devAddress = dev;
        emit IFomo3DEvents.ConfigUpdated("devAddress");
    }

    /// @notice 设置 dev fee 费率
    /// @dev 变更立即生效，影响后续所有 exitGame/settleUnexited 的扣费。
    ///      已分配但未领取的大奖（pendingWithdrawals）会按新费率扣费——
    ///      这是设计意图：devFee 是用户领取时支付的服务费，按当前费率计算。
    function setDevFee(uint16 bps) internal {
        if (bps > 1000) revert LibErrors.InvalidConfig(); // 最大 10%
        AppStorage storage s = LibAppStorage.appStorage();
        s.devFeeBps = bps;
        emit IFomo3DEvents.ConfigUpdated("devFeeBps");
    }

    function setTimerConfig(uint64 initial, uint64 extension, uint64 max) internal {
        if (initial == 0 || extension == 0 || max == 0) revert LibErrors.InvalidConfig();
        AppStorage storage s = LibAppStorage.appStorage();
        s.initialCountdown = initial;
        s.countdownExtension = extension;
        s.maxCountdown = max;
        emit IFomo3DEvents.ConfigUpdated("timerConfig");
    }

    function setPoolConfig(
        uint16 injectionBps,
        uint16 pendingBps,
        uint16 dividendBps,
        uint16 grandPrizeBps
    ) internal {
        if (injectionBps + pendingBps != LibConstants.BASIS_POINTS) revert LibErrors.InvalidConfig();
        if (dividendBps + grandPrizeBps != LibConstants.BASIS_POINTS) revert LibErrors.InvalidConfig();
        AppStorage storage s = LibAppStorage.appStorage();
        s.injectionPoolBps = injectionBps;
        s.pendingPoolBps = pendingBps;
        s.dividendBps = dividendBps;
        s.grandPrizeBps = grandPrizeBps;
        emit IFomo3DEvents.ConfigUpdated("poolConfig");
    }

    function setGrandPrizeSplit(uint16 top1Bps, uint16 othersBps) internal {
        // top1 + 9 * others = 10000
        if (top1Bps + 9 * uint256(othersBps) != LibConstants.BASIS_POINTS) revert LibErrors.InvalidConfig();
        AppStorage storage s = LibAppStorage.appStorage();
        s.grandTop1Bps = top1Bps;
        s.grandOthersBps = othersBps;
        emit IFomo3DEvents.ConfigUpdated("grandPrizeSplit");
    }

    function setSharePrice(uint256 price) internal {
        if (price == 0) revert LibErrors.InvalidConfig();
        AppStorage storage s = LibAppStorage.appStorage();
        s.sharePrice = price;
        emit IFomo3DEvents.ConfigUpdated("sharePrice");
    }

    function setUnexitedPenalty(uint16 bps) internal {
        if (bps > LibConstants.BASIS_POINTS) revert LibErrors.InvalidConfig();
        AppStorage storage s = LibAppStorage.appStorage();
        s.unexitedPenaltyBps = bps;
        emit IFomo3DEvents.ConfigUpdated("unexitedPenaltyBps");
    }

    function setPaused(bool _paused, address caller) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.paused = _paused;
        if (_paused) {
            emit IFomo3DEvents.Paused(caller);
        } else {
            emit IFomo3DEvents.Unpaused(caller);
        }
    }

}
