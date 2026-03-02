// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibAppStorage, AppStorage, RoundInfo, RoundStatus} from "../storage/AppStorage.sol";
import {LibGame} from "./LibGame.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibConstants} from "./LibConstants.sol";
import {IFomo3DEvents} from "../interfaces/IFomo3DEvents.sol";

/// @title LibLifecycle — 轮次生命周期逻辑库
/// @dev LifecycleFacet 的所有业务逻辑
library LibLifecycle {
    /// @notice 倒计时结束后发放大奖并开启下一轮
    function endRoundAndDistribute() internal {
        AppStorage storage s = LibAppStorage.appStorage();
        RoundInfo storage round = s.rounds[s.roundNumber];

        // 必须是活跃轮次且倒计时已过
        if (round.status == RoundStatus.NotStarted) revert LibErrors.RoundNotActive();
        if (round.isPrizePaid) revert LibErrors.PrizeAlreadyPaid();

        // 如果还是 Active 状态，检查是否已过期
        if (round.status == RoundStatus.Active) {
            if (block.timestamp <= round.endTime) revert LibErrors.RoundNotEnded();
            round.status = RoundStatus.Ended;
            round.endTime = uint64(block.timestamp);
            emit IFomo3DEvents.RoundEnded(s.roundNumber, round.endTime);
        }

        uint256 prizePool = round.grandPrizePool;
        round.isPrizePaid = true;

        // === 分配大奖 ===
        if (prizePool > 0) {
            _distributeGrandPrize(s, prizePool);
        }

        // === 开启下一轮 ===
        _startNextRound(s, round);
    }

    /// @dev 大奖以 gross（全额）记入 pendingWithdrawals，devFee 在用户 settleUnexited 领取时扣除。
    ///      例：100 BNB 大奖 → pendingWithdrawals = 100 → 用户领取时付 5% → 净得 95，dev 得 5。
    ///      统计口径以 gross 为准（PrizeCredited/GrandPrizeDistributed 的 amount = gross）。
    ///      devFeeBps 变更只影响后续领取的费率，不需要快照——这是设计意图，非遗漏。
    function _distributeGrandPrize(AppStorage storage s, uint256 prizePool) private {
        // [0] = 最后买家 → 55%
        // [1..9] = 其余 → 各 5%
        uint256 unclaimedPrize = 0;

        uint32 roundNum = s.roundNumber;
        uint16 top1Bps = s.grandTop1Bps;
        uint16 othersBps = s.grandOthersBps;

        for (uint8 i = 0; i < LibConstants.LAST_BUYERS_COUNT;) {
            address buyer = s.roundLastBuyers[roundNum][i];
            uint256 gross = i == 0
                ? LibGame.mulBps(prizePool, top1Bps)
                : LibGame.mulBps(prizePool, othersBps);

            if (buyer == address(0)) {
                // 空位：奖金进入下一轮
                unclaimedPrize += gross;
            } else {
                // Pull 模式：记录 gross 待领取金额，dev fee 在 claim 时扣
                if (gross > 0) {
                    s.pendingWithdrawals[buyer] += gross;
                    emit IFomo3DEvents.PrizeCredited(buyer, gross, roundNum);
                }
                emit IFomo3DEvents.GrandPrizeDistributed(roundNum, buyer, i, gross);
            }

            unchecked { ++i; }
        }

        // 未领取的奖金进入下一轮
        if (unclaimedPrize > 0) {
            s.nextRoundCarryover += unclaimedPrize;
        }

        // 处理大奖池的 bps 舍入误差（dust）
        uint256 distributed = LibGame.mulBps(prizePool, top1Bps)
            + LibGame.mulBps(prizePool, othersBps) * 9;
        if (prizePool > distributed) {
            s.nextRoundCarryover += prizePool - distributed;
        }
    }

    function _startNextRound(AppStorage storage s, RoundInfo storage prevRound) private {
        // 将上一轮 EPS 余数结转（除以 EPS_PRECISION 转换回 wei）
        uint256 remainderWei = prevRound.epsRemainder / LibConstants.EPS_PRECISION;

        uint256 totalCarryover = s.pendingPool + s.nextRoundCarryover + remainderWei;

        // 再次按 injectionPoolBps / pendingPoolBps 分割，保证游戏可持续
        // 注入部分 → 本轮大奖池；剩余部分 → 继续留给下一轮
        uint256 injectionAmount = LibGame.mulBps(totalCarryover, s.injectionPoolBps);
        uint256 reserveAmount = totalCarryover - injectionAmount;

        s.roundNumber += 1;
        RoundInfo storage newRound = s.rounds[s.roundNumber];
        newRound.status = RoundStatus.NotStarted;

        newRound.grandPrizePool = injectionAmount;
        s.pendingPool = reserveAmount;
        s.nextRoundCarryover = 0;

        emit IFomo3DEvents.NextRoundStarted(s.roundNumber, newRound.grandPrizePool);
    }
}
