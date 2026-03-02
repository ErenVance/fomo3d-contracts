// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

library LibErrors {
    error TokenNotSet();
    error RoundNotActive();
    error RoundNotEnded();
    error RoundAlreadyEnded();
    error PrizeAlreadyPaid();
    error PrizeNotPaid();
    error PlayerNoShares();
    error PlayerAlreadyExited();
    error PlayerNotInRound();
    error PlayerHasUnsetledShares();
    error PurchaseZero();
    error EpsCannotDecrease();
    error TransferFailed();
    error InvalidConfig();
    error Paused();
    error NotPaused();
    error ZeroAddress();
    error NothingToClaim();
    error PlayerHasPendingPrize();
    error NotEOA();
    error FeeOnTransferDetected();
}
