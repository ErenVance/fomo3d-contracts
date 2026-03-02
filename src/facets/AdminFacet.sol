// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibDiamond} from "../diamond/libraries/LibDiamond.sol";
import {LibAdmin} from "../libraries/LibAdmin.sol";
import {IFomo3DEvents} from "../interfaces/IFomo3DEvents.sol";
import {Modifiers} from "./Modifiers.sol";

contract AdminFacet is Modifiers, IFomo3DEvents {
    function setToken(address token) external {
        LibDiamond.enforceIsContractOwner();
        LibAdmin.setToken(token);
    }

    function setDevAddress(address dev) external {
        LibDiamond.enforceIsContractOwner();
        LibAdmin.setDevAddress(dev);
    }

    function setDevFee(uint16 bps) external {
        LibDiamond.enforceIsContractOwner();
        LibAdmin.setDevFee(bps);
    }

    function setTimerConfig(uint64 initial, uint64 extension, uint64 max) external {
        LibDiamond.enforceIsContractOwner();
        LibAdmin.setTimerConfig(initial, extension, max);
    }

    function setPoolConfig(uint16 injectionBps, uint16 pendingBps, uint16 dividendBps, uint16 grandPrizeBps) external {
        LibDiamond.enforceIsContractOwner();
        LibAdmin.setPoolConfig(injectionBps, pendingBps, dividendBps, grandPrizeBps);
    }

    function setGrandPrizeSplit(uint16 top1Bps, uint16 othersBps) external {
        LibDiamond.enforceIsContractOwner();
        LibAdmin.setGrandPrizeSplit(top1Bps, othersBps);
    }

    function setSharePrice(uint256 price) external {
        LibDiamond.enforceIsContractOwner();
        LibAdmin.setSharePrice(price);
    }

    function setUnexitedPenalty(uint16 bps) external {
        LibDiamond.enforceIsContractOwner();
        LibAdmin.setUnexitedPenalty(bps);
    }

    function setPaused(bool _paused) external {
        LibDiamond.enforceIsContractOwner();
        LibAdmin.setPaused(_paused, msg.sender);
    }

}
