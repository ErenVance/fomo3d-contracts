// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibAppStorage, AppStorage, RoundInfo, PlayerInfo, RoundStatus} from "../storage/AppStorage.sol";
import {LibGame} from "./LibGame.sol";
import {LibErrors} from "./LibErrors.sol";
import {IFomo3DEvents} from "../interfaces/IFomo3DEvents.sol";

/// @title LibPurchase — 购买 share 逻辑库
/// @dev PurchaseFacet 的所有业务逻辑
library LibPurchase {
    using SafeERC20 for IERC20;

    /// @notice 指定 share 数量购买，合约精确计算并销毁 tokenAmount = shareAmount * sharePrice
    /// @dev 运行时检测 fee-on-transfer：通过前后余额差验证实际到账 == tokenAmount，
    ///      如果 token 有转账税会 revert FeeOnTransferDetected。
    function purchase(address caller, uint256 shareAmount) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        if (s.burnToken == address(0)) revert LibErrors.TokenNotSet();
        if (shareAmount == 0) revert LibErrors.PurchaseZero();

        RoundInfo storage round = s.rounds[s.roundNumber];

        // 检查轮次状态
        if (round.status == RoundStatus.Ended) revert LibErrors.RoundAlreadyEnded();
        if (round.status == RoundStatus.Active && block.timestamp > round.endTime) {
            revert LibErrors.RoundAlreadyEnded();
        }

        // 检查玩家是否有未结算的老轮次 shares
        PlayerInfo storage player = s.players[caller];
        if (player.roundNumber != 0 && player.roundNumber != s.roundNumber && player.shares > 0) {
            revert LibErrors.PlayerHasUnsetledShares();
        }

        // 检查玩家是否有未领取的大奖
        if (s.pendingWithdrawals[caller] > 0) {
            revert LibErrors.PlayerHasPendingPrize();
        }

        // 1. 精确计算并销毁 token（转到 burnAddress），检测 fee-on-transfer
        uint256 tokenAmount = shareAmount * s.sharePrice;
        uint256 balBefore = IERC20(s.burnToken).balanceOf(s.burnAddress);
        IERC20(s.burnToken).safeTransferFrom(caller, s.burnAddress, tokenAmount);
        if (IERC20(s.burnToken).balanceOf(s.burnAddress) - balBefore != tokenAmount) {
            revert LibErrors.FeeOnTransferDetected();
        }
        s.totalBurnedTokens += tokenAmount;

        // 2. 检测并分配新 BNB
        (uint256 injectionAmount, uint256 pendingAmount) = LibGame.detectAndDistributeBNB(round);
        if (injectionAmount > 0 || pendingAmount > 0) {
            emit IFomo3DEvents.BNBDetected(injectionAmount + pendingAmount, injectionAmount, pendingAmount);
        }

        // 3. 结算玩家已有分红（如果有 shares）
        if (player.shares > 0 && player.roundNumber == s.roundNumber) {
            LibGame.settlePlayerEarnings(player, round);
        }

        // 4. 初始化/更新玩家状态
        if (player.roundNumber != s.roundNumber) {
            player.roundNumber = s.roundNumber;
            player.earningsPerShare = round.earningsPerShare;
            player.accumulatedEarnings = 0;
            player.shares = 0;
            player.hasExited = false;
        } else if (player.hasExited) {
            // 同轮次退出后重新购买：重置退出状态，从当前 EPS 快照开始（防止重复领取已结算分红）
            player.hasExited = false;
            player.earningsPerShare = round.earningsPerShare;
            player.accumulatedEarnings = 0; // exitGame 已清零，显式重置确保一致性
        }

        // 5. 增加 shares
        player.shares += shareAmount;
        round.totalShares += shareAmount;

        // 6. 处理轮次启动（首次购买）
        if (round.status == RoundStatus.NotStarted) {
            round.status = RoundStatus.Active;
            round.startTime = uint64(block.timestamp);
            round.endTime = uint64(block.timestamp) + s.initialCountdown;
            emit IFomo3DEvents.RoundStarted(s.roundNumber, round.startTime, round.endTime);
        } else {
            // 7. 延长倒计时
            round.endTime = LibGame.computeExtendedEndTime(
                round.endTime, uint64(block.timestamp), s.countdownExtension, s.maxCountdown
            );
        }

        // 8. 更新 lastBuyers 队列
        LibGame.updateLastBuyers(s.roundLastBuyers[s.roundNumber], caller);

        emit IFomo3DEvents.SharesPurchased(caller, shareAmount, tokenAmount, s.roundNumber);
    }
}
