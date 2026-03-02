// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibAppStorage, AppStorage, RoundInfo, PlayerInfo, RoundStatus} from "../storage/AppStorage.sol";
import {LibGame} from "./LibGame.sol";
import {LibErrors} from "./LibErrors.sol";
import {IFomo3DEvents} from "../interfaces/IFomo3DEvents.sol";

/// @title LibExit — 退出和未退出结算逻辑库
/// @dev ExitFacet 的所有业务逻辑
///
/// Dev Fee 设计说明：
/// devFee 是用户在领取收益时支付的服务费，按领取时的 devFeeBps 费率计算。
/// 概念模型：系统将 gross 金额全额授予用户，用户从中支付 devFee 给 devAddress。
/// - 分红：gross earnings → 用户付 devFee → 用户净得 earnings - devFee
/// - 大奖：gross pendingWithdrawals → 用户付 devFee → 用户净得 prize - devFee
/// devFeeBps 变更只影响后续领取操作的费率，不回溯已领取的金额。
/// 统计口径：大奖以 gross 计（即 PrizeCredited/GrandPrizeDistributed 的 amount），
/// devFee 是用户领取时额外记录的扣费明细。
library LibExit {
    /// @notice 活跃轮次中退出，领取分红（扣 dev fee）
    function exitGame(address caller) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        RoundInfo storage round = s.rounds[s.roundNumber];
        PlayerInfo storage player = s.players[caller];

        // 验证
        if (round.status != RoundStatus.Active) revert LibErrors.RoundNotActive();
        if (block.timestamp > round.endTime) revert LibErrors.RoundAlreadyEnded();
        if (player.roundNumber != s.roundNumber) revert LibErrors.PlayerNotInRound();
        if (player.shares == 0) revert LibErrors.PlayerNoShares();
        if (player.hasExited) revert LibErrors.PlayerAlreadyExited();

        // 结算分红
        LibGame.settlePlayerEarnings(player, round);
        uint256 earnings = player.accumulatedEarnings;

        // 下溢防护
        if (earnings > round.dividendPool) {
            emit IFomo3DEvents.DividendPoolCapped(caller, earnings, round.dividendPool, s.roundNumber);
            earnings = round.dividendPool;
        }

        // dev fee：用户从分红中支付服务费，按当前 devFeeBps 计算
        uint256 devFee = LibGame.mulBps(earnings, s.devFeeBps);
        uint256 netEarnings = earnings - devFee;

        // 更新轮次状态（减少 totalShares）
        round.totalShares -= player.shares;
        round.dividendPool -= earnings;

        // 清空玩家状态
        player.shares = 0;
        player.accumulatedEarnings = 0;
        player.earningsPerShare = 0;
        player.hasExited = true;

        // 延长倒计时
        round.endTime = LibGame.computeExtendedEndTime(
            round.endTime, uint64(block.timestamp), s.countdownExtension, s.maxCountdown
        );

        // 转账
        if (netEarnings > 0) {
            LibGame.transferBNB(caller, netEarnings);
        }
        if (devFee > 0) {
            LibGame.transferBNB(s.devAddress, devFee);
        }

        emit IFomo3DEvents.PlayerExited(caller, netEarnings, devFee, s.roundNumber);
    }

    /// @notice 轮次结束后结算未退出的 shares（带惩罚）+ 领取大奖
    /// @dev 支持两种场景：
    ///   1. 有 shares 未退出 → 结算分红（惩罚）+ 领取大奖
    ///   2. 已退出但有 pendingWithdrawals → 仅领取大奖
    function settleUnexited(address caller) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        PlayerInfo storage player = s.players[caller];

        bool hasShares = player.shares > 0 && !player.hasExited;
        uint256 pendingPrize = s.pendingWithdrawals[caller];

        // 必须有 shares 或 pendingWithdrawals
        if (!hasShares && pendingPrize == 0) revert LibErrors.NothingToClaim();

        uint256 netPlayer = 0;
        uint256 penalty = 0;
        uint256 devFee = 0;
        uint32 settledRound;

        // === 分红结算（有 shares 时）===
        if (hasShares) {
            settledRound = player.roundNumber;
            RoundInfo storage round = s.rounds[settledRound];

            bool roundEnded = (round.status == RoundStatus.Ended)
                || (round.status == RoundStatus.Active && block.timestamp > round.endTime)
                || (settledRound < s.roundNumber);
            if (!roundEnded) revert LibErrors.RoundNotEnded();

            LibGame.settlePlayerEarnings(player, round);
            uint256 earnings = player.accumulatedEarnings;
            if (earnings > round.dividendPool) {
                emit IFomo3DEvents.DividendPoolCapped(caller, earnings, round.dividendPool, settledRound);
                earnings = round.dividendPool;
            }

            penalty = LibGame.mulBps(earnings, s.unexitedPenaltyBps);
            // dev fee 基于罚后金额，按当前 devFeeBps 费率
            devFee = LibGame.mulBps(earnings - penalty, s.devFeeBps);
            netPlayer = earnings - penalty - devFee;

            s.nextRoundCarryover += penalty;
            round.totalShares -= player.shares;
            round.dividendPool -= earnings;

            player.shares = 0;
            player.accumulatedEarnings = 0;
            player.earningsPerShare = 0;
            player.hasExited = true;

            emit IFomo3DEvents.UnexitedSettled(caller, netPlayer, penalty, devFee, settledRound);
        }

        // === 大奖领取 ===
        // pendingWithdrawals 记录的是 gross（大奖全额），用户领取时按当前 devFeeBps 付费。
        // 统计以 gross 为准（如 PrizeCredited 事件的 amount），devFee 是领取时的扣费记录。
        uint256 netPrize = 0;
        uint256 prizeFee = 0;
        if (pendingPrize > 0) {
            s.pendingWithdrawals[caller] = 0;
            prizeFee = LibGame.mulBps(pendingPrize, s.devFeeBps);
            netPrize = pendingPrize - prizeFee;
            devFee += prizeFee;
        }

        // === 合并转账 ===
        uint256 payout = netPlayer + netPrize;
        if (payout > 0) {
            LibGame.transferBNB(caller, payout);
        }
        if (devFee > 0) {
            LibGame.transferBNB(s.devAddress, devFee);
        }

        if (netPrize > 0) {
            emit IFomo3DEvents.PrizeClaimed(caller, netPrize, prizeFee);
        }
    }
}
