//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entrenceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entrenceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    ////////////////////////
    /// Enter Raffle///////
    //////////////////////
    function testRaffleRevertWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entrenceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
        // Assert
    }

    function testEmitsEventOnEntrence() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entrenceFee}();
    }

    function testCantEnterWhenRaffleIsCalculation() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entrenceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entrenceFee}();
    }

    //////////////////////
    /// CheckUpKeep///////
    //////////////////////

    function testCheckUpkeepreturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1); // makes so enough time has passed // true
        vm.roll(block.number + 1); //

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // assert
        assert(!upkeepNeeded); // false because it has no balance
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entrenceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //assert
        assert(upkeepNeeded == false); // false because raffle is not open
    }

    function testCheckUpkeepReturnsTrueIfItHasBalance() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entrenceFee}();
        vm.warp(block.timestamp + interval + 1); // makes so enough time has passed // true
        vm.roll(block.number + 1); //

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // assert
        assert(upkeepNeeded); // true because it has balance
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasentPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entrenceFee}();
        vm.warp(block.timestamp + interval - 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // assert
        assert(!upkeepNeeded); // false because not enough time has passed
    }

    function testCheckUpkeepReturnsTrueWhenAllParametersAreGood() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entrenceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // assert
        assert(upkeepNeeded); // true because all parameters are good
    }

    /*function testCheckUpkeepReturnsTrueWhenRaffleIsOpen() public {
        //arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entrenceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        //act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //assert
        assert(upkeepNeeded == true);
    }*/

    //////////////////////
    /// PerformUpkeep/////
    //////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entrenceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        // act / assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    modifier PlayerEnteredWithBalanceAndTimeHasPassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entrenceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        PlayerEnteredWithBalanceAndTimeHasPassed
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); //emit request id
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    // chainlink nodes listen to events.

    ////////////////////////
    /// fulfillRandomWords//
    ////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFullfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public PlayerEnteredWithBalanceAndTimeHasPassed skipFork {
        // Arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksWinnerResetAndSendsMoney()
        public
        PlayerEnteredWithBalanceAndTimeHasPassed
        skipFork
    {
        // Arrange
        uint256 additinalEntrant = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additinalEntrant;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entrenceFee}();
        }

        uint256 prize = entrenceFee * (additinalEntrant + 1);

        vm.recordLogs();
        raffle.performUpkeep(""); //emit request id
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // pretend to be chainlink vrf to get random number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert best practice is to have 1 assert per test
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE + prize - entrenceFee
        );
    }
}
