// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibAppStorage, AppStorage, RoundInfo, PlayerInfo, RoundStatus} from "../storage/AppStorage.sol";
import {LibGame} from "../libraries/LibGame.sol";

contract ViewFacet {
    function getRoundInfo(uint32 roundNumber) external view returns (
        RoundStatus status,
        bool isPrizePaid,
        uint64 startTime,
        uint64 endTime,
        uint256 totalShares,
        uint256 earningsPerShare,
        uint256 grandPrizePool,
        uint256 dividendPool
    ) {
        AppStorage storage s = LibAppStorage.appStorage();
        RoundInfo storage r = s.rounds[roundNumber];
        return (r.status, r.isPrizePaid, r.startTime, r.endTime, r.totalShares, r.earningsPerShare, r.grandPrizePool, r.dividendPool);
    }

    function getCurrentRoundNumber() external view returns (uint32) {
        return LibAppStorage.appStorage().roundNumber;
    }

    function getLastBuyers(uint32 roundNumber) external view returns (address[10] memory) {
        return LibAppStorage.appStorage().roundLastBuyers[roundNumber];
    }

    function getPlayerInfo(address player) external view returns (
        uint256 earningsPerShare,
        uint256 accumulatedEarnings,
        uint32 roundNumber,
        uint256 shares,
        bool hasExited
    ) {
        PlayerInfo storage p = LibAppStorage.appStorage().players[player];
        return (p.earningsPerShare, p.accumulatedEarnings, p.roundNumber, p.shares, p.hasExited);
    }

    function getPlayerPendingEarnings(address player) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        PlayerInfo storage p = s.players[player];
        if (p.shares == 0 || p.roundNumber == 0) return 0;
        RoundInfo storage r = s.rounds[p.roundNumber];
        return LibGame.pendingEarnings(p, r);
    }

    function getCountdownRemaining() external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        RoundInfo storage r = s.rounds[s.roundNumber];
        if (r.status != RoundStatus.Active) return 0;
        if (block.timestamp >= r.endTime) return 0;
        return r.endTime - block.timestamp;
    }

    function getPools() external view returns (
        uint256 pendingPool,
        uint256 nextRoundCarryover,
        uint256 trackedBalance,
        uint256 contractBalance
    ) {
        AppStorage storage s = LibAppStorage.appStorage();
        return (s.pendingPool, s.nextRoundCarryover, s.trackedBalance, address(this).balance);
    }

    function getPendingWithdrawal(address player) external view returns (uint256) {
        return LibAppStorage.appStorage().pendingWithdrawals[player];
    }

    function isPaused() external view returns (bool) {
        return LibAppStorage.appStorage().paused;
    }

    function getConfig() external view returns (
        address burnToken,
        address devAddress,
        uint16 devFeeBps,
        uint64 initialCountdown,
        uint64 countdownExtension,
        uint64 maxCountdown,
        uint16 injectionPoolBps,
        uint16 pendingPoolBps,
        uint16 dividendBps,
        uint16 grandPrizeBps,
        uint16 grandTop1Bps,
        uint16 grandOthersBps,
        uint16 unexitedPenaltyBps
    ) {
        AppStorage storage s = LibAppStorage.appStorage();
        return (
            s.burnToken, s.devAddress, s.devFeeBps,
            s.initialCountdown, s.countdownExtension, s.maxCountdown,
            s.injectionPoolBps, s.pendingPoolBps, s.dividendBps, s.grandPrizeBps,
            s.grandTop1Bps, s.grandOthersBps, s.unexitedPenaltyBps
        );
    }

    function getSharePrice() external view returns (uint256) {
        return LibAppStorage.appStorage().sharePrice;
    }
}
