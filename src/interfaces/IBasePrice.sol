// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.17;


interface IBasePrice {
    function mintFloor(uint256 amount) external;

    function adjustFloor(uint256 amount) external;

    function deployAnchor(uint256 amount, uint256 anchors) external;

    function mintDiscovery(uint256 amount) external;

    function getReserve() external returns(uint256);
}