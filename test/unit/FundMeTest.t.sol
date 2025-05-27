// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    address USER = makeAddr("user");
    address priceFeedAddress;
    uint256 constant SEND_VALUE = 0.1 ether; // 10 ETH in wei
    uint256 constant STARTING_BALANCE = 10 ether; // 100 ETH in wei
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
    MockV3Aggregator mock = new MockV3Aggregator(8, 2000e8);
    priceFeedAddress = address(mock);         // <-- add this
    fundMe = new FundMe(priceFeedAddress);    // use variable here
    vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        if (block.chainid == 11155111) {
            uint256 version = fundMe.getVersion();
            assertEq(version, 4);
        } else if (block.chainid == 1) {
            uint256 version = fundMe.getVersion();
            assertEq(version, 6);
        }
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert("You need to spend more ETH!");
        fundMe.fund{value: 1e9}(); // 1 ETH is less than 5 USD
    }

    function testFundMeUpdatesFundedDataStructure() public {
        vm.prank(USER);
        fundMe.fund{value: 10e18}();
        uint256 amountFunded = fundMe.s_addressToAmountFunded(USER); // FIXED: use USER instead of address(this)
        assertEq(amountFunded, 10e18, "Amount funded should be 10 ETH");
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: 10e18}();
        address funder = fundMe.s_funders(0); // FIXED: get one address, not array
        assertEq(funder, USER, "Funder should be added to the array");
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert("NotOwner()");
        fundMe.withdraw();
    }

    function testWithdrawWIthASingleFunder() public funded {
        uint256 startingOnwerBalance = fundMe.getOwner().balance;
        uint256 startFundMeBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0); // FIXED: replaced invalid cast with assertion
        assertEq(startingOnwerBalance + startFundMeBalance, endingOwnerBalance);
    }

    function testWithdrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFundersIndex = 1;
        for (uint160 i = startingFundersIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); // FIXED: hoax handles prank + deal
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOnwerBalance = fundMe.getOwner().balance;
        uint256 startFundMeBalance = address(fundMe).balance;

        // Act
        address deployer = makeAddr("deployer");
        vm.prank(deployer);
        fundMe = new FundMe(priceFeedAddress);


        // Assert
        assertEq(fundMe.getOwner(), deployer);
        assertEq(address(fundMe).balance, 0);
        assertEq(startingOnwerBalance + startFundMeBalance, fundMe.getOwner().balance);
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFundersIndex = 1;
        for (uint160 i = startingFundersIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); // FIXED: hoax handles prank + deal
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOnwerBalance = fundMe.getOwner().balance;
        uint256 startFundMeBalance = address(fundMe).balance;

        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();
        address deployer = makeAddr("deployer");
        vm.prank(deployer);
        fundMe = new FundMe(priceFeedAddress);


        // Assert
        assertEq(fundMe.getOwner(), deployer);
        assertEq(address(fundMe).balance, 0);
        assertEq(startingOnwerBalance + startFundMeBalance, fundMe.getOwner().balance);
    }
}
