// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    uint8 public constant DECIMALS = 8; // 8 decimals for price feed
    int256 public constant INITIAL_PRICE = 2000e8; // 2000 USD in 8 decimals
    // 11155111 is Sepolia ETH chain id
    // 31337 is Anvil ETH chain id
    constructor(){
        if(block.chainid == 11155111){ //chain id is the chains current id
            activeNetworkConfig = getSepoliaEthConfig();    //11155111 is ETH Sepolia 
        }else if(block.chainid == 31337){ //    //1 is ETH Mainnet
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }else{
            revert("No configuration found");
        }
    }
    struct NetworkConfig{
        address priceFeed;
    }
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory){
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return sepoliaConfig;
    }
    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory ethConfig = NetworkConfig({
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        });
        return ethConfig;
    }
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({
            priceFeed: address(mockPriceFeed)
        });
        activeNetworkConfig = anvilConfig;   // save it
        return anvilConfig;
    }
}
