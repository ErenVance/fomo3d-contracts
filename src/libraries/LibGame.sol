// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibAppStorage, AppStorage, RoundInfo, PlayerInfo, RoundStatus} from "../storage/AppStorage.sol";
import {LibConstants} from "./LibConstants.sol";
import {LibErrors} from "./LibErrors.sol";

/// @title LibGame — Fomo3D 核心算法库
/// @dev EPS 分红、倒计时、BNB 检测、lastBuyers 队列
library LibGame {
    // ============ EPS 分红算法 ============

    /// @notice 计算新的 EPS 和余数（pull-based 分红累加器）
    /// @param totalShares 当前总 shares
    /// @param addedRewards 新增分红 BNB（wei）
    /// @param currentEps 当前 EPS
    /// @param currentRem 当前余数
    /// @return newEps 更新后的 EPS
    /// @return newRem 更新后的余数
    function applyEpsDistribution(uint256 totalShares, uint256 addedRewards, uint256 currentEps, uint256 currentRem)
        internal
        pure
        returns (uint256 newEps, uint256 newRem)
    {
        if (totalShares == 0) {
            return (currentEps, currentRem);
        }
        uint256 delta = addedRewards * LibConstants.EPS_PRECISION + currentRem;
        uint256 perShare = delta / totalShares;
        newEps = currentEps + perShare;
        newRem = delta - perShare * totalShares;
    }

    /// @notice 结算玩家的待领取分红
    /// @dev 将 EPS 差值 × shares 累加到 accumulatedEarnings，更新玩家 EPS 快照
    function settlePlayerEarnings(PlayerInfo storage player, RoundInfo storage round) internal {
        if (player.shares == 0) return;
        uint256 epsDelta = round.earningsPerShare - player.earningsPerShare;
        if (epsDelta > 0) {
            player.accumulatedEarnings += (epsDelta * player.shares) / LibConstants.EPS_PRECISION;
        }
        player.earningsPerShare = round.earningsPerShare;
    }

    /// @notice 计算玩家的待领取分红（view，不修改状态）
    function pendingEarnings(PlayerInfo storage player, RoundInfo storage round) internal view returns (uint256) {
        uint256 epsDelta = round.earningsPerShare - player.earningsPerShare;
        return player.accumulatedEarnings + (epsDelta * player.shares) / LibConstants.EPS_PRECISION;
    }

    // ============ 倒计时 ============

    /// @notice 计算购买后的新截止时间
    /// @param endTime 当前截止时间
    /// @param currentTime 当前时间
    /// @param extension 延长秒数
    /// @param maxDuration 最大倒计时上限
    /// @return 新的截止时间
    function computeExtendedEndTime(uint64 endTime, uint64 currentTime, uint64 extension, uint64 maxDuration)
        internal
        pure
        returns (uint64)
    {
        // 如果已过期（理论上不应发生，购买前已检查）
        if (currentTime > endTime) {
            return currentTime + extension;
        }
        // 如果剩余时间已超过上限，不再延长
        if (endTime - currentTime > maxDuration) {
            return endTime;
        }
        uint64 extendedTime = endTime + extension;
        uint64 maxEndTime = currentTime + maxDuration;
        return extendedTime < maxEndTime ? extendedTime : maxEndTime;
    }

    // ============ BNB 检测与分配 ============

    /// @notice 检测新注入的 BNB 并分配到各池子
    /// @dev 通过 address(this).balance - trackedBalance 检测新 BNB
    ///      【设计约束】仅在 purchase 路径调用，exitGame / settleUnexited / endRoundAndDistribute 不调用。
    ///      非购买路径的未检测 BNB 会延迟到下一次 purchase 时统一分配，避免在退出/结算路径引入
    ///      不可预测的余额变动（如 selfdestruct 强制转入），确保这些路径的金额计算确定性。
    /// @param round 当前轮次信息
    /// @return injectionAmount 注入池金额
    /// @return pendingAmount 待注入池金额
    function detectAndDistributeBNB(RoundInfo storage round) internal returns (uint256 injectionAmount, uint256 pendingAmount) {
        AppStorage storage s = LibAppStorage.appStorage();
        uint256 currentBalance = address(this).balance;
        if (currentBalance <= s.trackedBalance) {
            return (0, 0);
        }

        uint256 newBNB = currentBalance - s.trackedBalance;

        // 立即更新 trackedBalance：检测到的 BNB 即将分配到池子，标记为已追踪
        // 转出时由 transferBNB() 自动扣减 trackedBalance
        s.trackedBalance = currentBalance;

        // 分成注入池和待注入池（injectionPoolBps + pendingPoolBps == 10000，见 LibAdmin.setPoolConfig）
        // pendingAmount 通过减法隐式应用 pendingPoolBps，避免双次 mulBps 各自向下取整丢失 dust
        injectionAmount = mulBps(newBNB, s.injectionPoolBps);
        pendingAmount = newBNB - injectionAmount;
        s.pendingPool += pendingAmount;

        // 注入池再分：分红 + 大奖
        uint256 dividendAmount = mulBps(injectionAmount, s.dividendBps);
        uint256 grandPrizeAmount = injectionAmount - dividendAmount;

        // 大奖直接入池
        round.grandPrizePool += grandPrizeAmount;

        // 分红：如果有 shares 则更新 EPS，否则全部进大奖
        if (round.totalShares > 0) {
            (uint256 newEps, uint256 newRem) =
                applyEpsDistribution(round.totalShares, dividendAmount, round.earningsPerShare, round.epsRemainder);
            round.earningsPerShare = newEps;
            round.epsRemainder = newRem;
            round.dividendPool += dividendAmount;
        } else {
            round.grandPrizePool += dividendAmount;
        }

    }

    // ============ lastBuyers 队列 ============

    /// @notice 更新最后 10 个买家队列
    /// @dev 如果买家已在队列中，移到最前面；否则整体后移，新买家插入 [0]
    function updateLastBuyers(address[10] storage lastBuyers, address buyer) internal {
        // 检查是否已存在
        uint256 existingIndex = type(uint256).max;
        for (uint256 i = 0; i < LibConstants.LAST_BUYERS_COUNT;) {
            if (lastBuyers[i] == buyer) {
                existingIndex = i;
                break;
            }
            unchecked { ++i; }
        }

        if (existingIndex == 0) {
            // 已经在最前面，不动
            return;
        }

        if (existingIndex != type(uint256).max) {
            // 已存在但不在最前面，移到最前面
            for (uint256 i = existingIndex; i > 0;) {
                lastBuyers[i] = lastBuyers[i - 1];
                unchecked { --i; }
            }
        } else {
            // 不存在，整体后移一位（最后一个被淘汰）
            for (uint256 i = LibConstants.LAST_BUYERS_COUNT - 1; i > 0;) {
                lastBuyers[i] = lastBuyers[i - 1];
                unchecked { --i; }
            }
        }
        lastBuyers[0] = buyer;
    }

    // ============ 工具函数 ============

    /// @notice basis points 乘法
    function mulBps(uint256 amount, uint16 bps) internal pure returns (uint256) {
        return (amount * bps) / LibConstants.BASIS_POINTS;
    }

    /// @notice 安全转账 BNB，同时扣减 trackedBalance
    function transferBNB(address to, uint256 amount) internal {
        if (amount == 0) return;
        AppStorage storage s = LibAppStorage.appStorage();
        s.trackedBalance -= amount;
        // 如果 call 失败会 revert，trackedBalance 的扣减也会回滚
        (bool success,) = payable(to).call{value: amount}("");
        if (!success) revert LibErrors.TransferFailed();
    }
}
