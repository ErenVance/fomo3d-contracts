// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IDiamondLoupe {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice 获取所有 facet 地址及其函数 selector
    function facets() external view returns (Facet[] memory facets_);

    /// @notice 获取某个 facet 的所有函数 selector
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /// @notice 获取所有 facet 地址
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /// @notice 获取某个 selector 对应的 facet 地址
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}
