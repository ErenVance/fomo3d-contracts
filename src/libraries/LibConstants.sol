// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

library LibConstants {
    uint16 constant BASIS_POINTS = 10000;
    uint64 constant DEFAULT_INITIAL_COUNTDOWN = 3600; // 60 min
    uint64 constant DEFAULT_EXTENSION = 60; // 60 sec
    uint64 constant DEFAULT_MAX_COUNTDOWN = 3600; // 60 min
    uint8 constant LAST_BUYERS_COUNT = 10;
    address constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 constant EPS_PRECISION = 1e18;
}
