// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibDiamond} from "../diamond/libraries/LibDiamond.sol";
import {LibAppStorage, AppStorage, RoundStatus} from "../storage/AppStorage.sol";
import {LibConstants} from "../libraries/LibConstants.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {IDiamondLoupe} from "../diamond/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "../diamond/interfaces/IDiamondCut.sol";
import {IERC165} from "../diamond/interfaces/IERC165.sol";
import {IERC173} from "../diamond/interfaces/IERC173.sol";

contract DiamondInit {
    struct InitArgs {
        address devAddress;
        uint16 devFeeBps;
        uint64 initialCountdown;
        uint64 countdownExtension;
        uint64 maxCountdown;
        uint256 sharePrice; // 每个 share 需要多少 token（如 1000）
    }

    function init(InitArgs calldata args) external {
        // ERC165 接口注册
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // 游戏初始化
        AppStorage storage s = LibAppStorage.appStorage();
        require(!s.initialized, "DiamondInit: already initialized");
        s.initialized = true;

        // 参数校验（与 LibAdmin 一致）
        if (args.devAddress == address(0)) revert LibErrors.ZeroAddress();
        if (args.devFeeBps > 1000) revert LibErrors.InvalidConfig();
        if (args.initialCountdown == 0 || args.countdownExtension == 0 || args.maxCountdown == 0) {
            revert LibErrors.InvalidConfig();
        }
        if (args.sharePrice == 0) revert LibErrors.InvalidConfig();

        // 代币（后续通过 AdminFacet.setToken 设置）
        s.burnAddress = LibConstants.DEAD_ADDRESS;

        // 费用
        s.devAddress = args.devAddress;
        s.devFeeBps = args.devFeeBps;

        // 价格
        s.sharePrice = args.sharePrice;

        // 倒计时
        s.initialCountdown = args.initialCountdown;
        s.countdownExtension = args.countdownExtension;
        s.maxCountdown = args.maxCountdown;

        // 池子分配默认 50/50
        s.injectionPoolBps = 5000;
        s.pendingPoolBps = 5000;
        s.dividendBps = 5000;
        s.grandPrizeBps = 5000;

        // 惩罚
        s.unexitedPenaltyBps = 5000;

        // 大奖分配：55% + 9×5% = 100%
        s.grandTop1Bps = 5500;
        s.grandOthersBps = 500;

        // 创建第 1 轮
        s.roundNumber = 1;
        s.rounds[1].status = RoundStatus.NotStarted;
    }
}
