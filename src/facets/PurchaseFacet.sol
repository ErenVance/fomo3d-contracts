// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {LibPurchase} from "../libraries/LibPurchase.sol";
import {IFomo3DEvents} from "../interfaces/IFomo3DEvents.sol";
import {Modifiers} from "./Modifiers.sol";

contract PurchaseFacet is Modifiers, IFomo3DEvents {
    /// @notice 指定 share 数量购买，合约精确计算并销毁 shareAmount * sharePrice 的 token
    function purchase(uint256 shareAmount) external nonReentrant whenNotPaused onlyEOA {
        LibPurchase.purchase(msg.sender, shareAmount);
    }
}
