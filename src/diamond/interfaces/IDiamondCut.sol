// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IDiamondCut {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice 添加/替换/移除 facet 函数
    /// @param _diamondCut FacetCut 数组
    /// @param _init 初始化合约地址（address(0) 表示不初始化）
    /// @param _calldata 初始化调用数据
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external;

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}
