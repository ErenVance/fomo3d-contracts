// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IFomo3DEvents {
    event TokenSet(address indexed token);
    event RoundStarted(uint32 indexed roundNumber, uint64 startTime, uint64 endTime);
    event RoundEnded(uint32 indexed roundNumber, uint64 endTime);
    event SharesPurchased(address indexed player, uint256 shares, uint256 tokensBurned, uint32 indexed roundNumber);
    event BNBDetected(uint256 amount, uint256 injectionAmount, uint256 pendingAmount);
    event PlayerExited(address indexed player, uint256 earnings, uint256 devFee, uint32 indexed roundNumber);
    event UnexitedSettled(address indexed player, uint256 playerAmount, uint256 penaltyAmount, uint256 devFee, uint32 indexed roundNumber);
    event GrandPrizeDistributed(uint32 indexed roundNumber, address indexed recipient, uint8 rank, uint256 amount);
    event NextRoundStarted(uint32 indexed roundNumber, uint256 initialGrandPrize);
    event PrizeCredited(address indexed recipient, uint256 amount, uint32 indexed roundNumber);
    event PrizeClaimed(address indexed recipient, uint256 amount, uint256 devFee);
    event CountdownExtended(address indexed player, uint64 newEndTime, uint32 indexed roundNumber);
    event ConfigUpdated(string param);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event DividendPoolCapped(address indexed player, uint256 calculated, uint256 capped, uint32 indexed roundNumber);
}
