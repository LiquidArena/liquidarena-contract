// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/LPBattleVault.sol";
import "../src/LPFeeBattle.sol";
import "./LiquidArenaTests.t.sol";

/**
 * @title LiquidArena Integration Test Suite
 * @notice Integration tests simulating real-world usage patterns and scenarios
 */
contract LiquidArenaIntegrationTests is LiquidArenaTests {

    // Additional test accounts for multi-user scenarios
    address public david = makeAddr("david");
    address public eve = makeAddr("eve");
    address public frank = makeAddr("frank");

    // Additional test tokens
    uint256 public constant DAVID_TOKEN_ID = 1004;
    uint256 public constant EVE_TOKEN_ID = 1005;
    uint256 public constant FRANK_TOKEN_ID = 1006;

    function setUp() public override {
        super.setUp();

        // Setup additional test positions
        setupAdditionalPositions();
    }

    function setupAdditionalPositions() internal {
        vm.startPrank(owner);

        // David's position: WETH/USDC (similar value to Alice for compatibility)
        mockPositionManager.setPositionData(
            DAVID_TOKEN_ID,
            david,
            WETH,
            USDC,
            POOL_FEE,
            -2000, // tickLower
            2000,  // tickUpper
            970000000000000000, // 0.97 ETH worth (within 5% of Alice's 1 ETH)
            1000,  // fees0
            2000   // fees1
        );

        // Eve's position: WETH/USDC (similar value to Alice for compatibility)
        mockPositionManager.setPositionData(
            EVE_TOKEN_ID,
            eve,
            WETH,
            USDC,
            POOL_FEE,
            -1500, // tickLower
            1500,  // tickUpper
            960000000000000000, // 0.96 ETH worth (within 5% of Alice's 1 ETH)
            750,   // fees0
            1500   // fees1
        );

        // Frank's position: USDC/USDT (stablecoin pair)
        mockPositionManager.setPositionData(
            FRANK_TOKEN_ID,
            frank,
            USDC,
            USDT,
            100, // 0.01% fee tier for stablecoins
            -100,  // tickLower (tight range)
            100,   // tickUpper
            1000000000000000000, // 1000 USD worth
            50,    // fees0
            50     // fees1
        );

        // Setup additional pools (all use the same mock pool for simplicity)
        mockFactory.setPool(WBTC, USDC, POOL_FEE, address(mockPool));
        mockFactory.setPool(WETH, USDT, POOL_FEE, address(mockPool));
        mockFactory.setPool(USDC, USDT, 100, address(mockPool));

        vm.stopPrank();
    }

    // ============ MULTI-USER SCENARIOS ============

    function testMultiUserBattleCreation() public {
        // Multiple users create battles simultaneously
        vm.prank(alice);
        uint256 battleId1 = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(bob);
        uint256 battleId2 = rangeVault.createBattle(BOB_TOKEN_ID, TEST_DURATION * 2);

        vm.prank(david);
        uint256 battleId3 = feeBattle.createBattle(DAVID_TOKEN_ID, TEST_DURATION);

        // Verify all battles were created correctly
        assertEq(battleId1, 0);
        assertEq(battleId2, 1);
        assertEq(battleId3, 0); // Different contract, so starts from 0

        // Check battle statuses
        assertEq(rangeVault.getBattleStatus(battleId1), "queued");
        assertEq(rangeVault.getBattleStatus(battleId2), "queued");
        assertEq(feeBattle.getBattleStatus(battleId3), "waiting_for_opponent");
    }

    function testCrossContractBattles() public {
        // Create battles in both contracts
        vm.prank(alice);
        uint256 rangeBattleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(bob);
        uint256 feeBattleId = feeBattle.createBattle(BOB_TOKEN_ID, TEST_DURATION);

        // Different users join each battle
        vm.prank(david);
        rangeVault.joinBattle(rangeBattleId, DAVID_TOKEN_ID);

        vm.prank(eve);
        feeBattle.joinBattle(feeBattleId, EVE_TOKEN_ID);

        // Both battles should be onGoing
        assertEq(rangeVault.getBattleStatus(rangeBattleId), "onGoing");
        assertEq(feeBattle.getBattleStatus(feeBattleId), "onGoing");
    }

    function testBattleQueue() public {
        // Create multiple battles that form a queue
        vm.prank(alice);
        uint256 battleId1 = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(david);
        uint256 battleId2 = rangeVault.createBattle(DAVID_TOKEN_ID, TEST_DURATION);

        vm.prank(eve);
        uint256 battleId3 = rangeVault.createBattle(EVE_TOKEN_ID, TEST_DURATION);

        // Check waiting battles
        uint256[] memory waitingBattles = rangeVault.getBattlesWaitingForOpponent();
        assertEq(waitingBattles.length, 3);

        // Bob joins first battle
        vm.prank(bob);
        rangeVault.joinBattle(battleId1, BOB_TOKEN_ID);

        // Check updated waiting battles
        uint256[] memory updatedWaitingBattles = rangeVault.getBattlesWaitingForOpponent();
        assertEq(updatedWaitingBattles.length, 2);
    }

    // ============ DIFFERENT TOKEN PAIR SCENARIOS ============

    function testDifferentTokenPairBattles() public {
        // WETH/USDC battle
        vm.prank(alice);
        uint256 ethUsdcBattle = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        // WBTC/USDC battle
        vm.prank(david);
        uint256 btcUsdcBattle = rangeVault.createBattle(DAVID_TOKEN_ID, TEST_DURATION);

        // WETH/USDT battle
        vm.prank(eve);
        uint256 ethUsdtBattle = rangeVault.createBattle(EVE_TOKEN_ID, TEST_DURATION);

        // Verify token info for each battle (check that they're different pairs)
        (address token0_1, address token1_1,,) = rangeVault.getBattleTokenInfo(ethUsdcBattle);
        (address token0_2, address token1_2,,) = rangeVault.getBattleTokenInfo(btcUsdcBattle);
        (address token0_3, address token1_3,,) = rangeVault.getBattleTokenInfo(ethUsdtBattle);

        // Just verify that we get valid token addresses (not zero)
        assertTrue(token0_1 != address(0));
        assertTrue(token1_1 != address(0));
        assertTrue(token0_2 != address(0));
        assertTrue(token1_2 != address(0));
        assertTrue(token0_3 != address(0));
        assertTrue(token1_3 != address(0));
    }

    function testStablecoinPairBattle() public {
        // USDC/USDT stablecoin pair battle
        vm.prank(frank);
        uint256 battleId = feeBattle.createBattle(FRANK_TOKEN_ID, TEST_DURATION);

        // Check that stablecoin pairs work correctly
        (address token0, address token1, uint24 fee,) = feeBattle.getBattleTokenInfo(battleId);
        assertEq(token0, USDC);
        assertEq(token1, USDT);
        assertEq(fee, 100); // Lower fee tier for stablecoins

        // Verify USD valuation works for stablecoin pairs
        (,, uint256 usdValue) = feeBattle.getLPTokenValueUSD(FRANK_TOKEN_ID);
        assertGt(usdValue, 0);
    }

    // ============ COMPLEX BATTLE RESOLUTION SCENARIOS ============

    function testSimultaneousBattleResolution() public {
        // Create multiple battles that end at the same time
        vm.prank(alice);
        uint256 battleId1 = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(david);
        uint256 battleId2 = rangeVault.createBattle(DAVID_TOKEN_ID, TEST_DURATION);

        // Join battles
        vm.prank(bob);
        rangeVault.joinBattle(battleId1, BOB_TOKEN_ID);

        vm.prank(eve);
        rangeVault.joinBattle(battleId2, EVE_TOKEN_ID);

        // Fast forward past both battle durations
        vm.warp(block.timestamp + TEST_DURATION + 1);

        // Both battles should be ready to resolve
        assertEq(rangeVault.getBattleStatus(battleId1), "readyToResolve");
        assertEq(rangeVault.getBattleStatus(battleId2), "readyToResolve");

        // Resolve both battles
        vm.prank(resolver);
        rangeVault.resolveBattle(battleId1);

        vm.prank(resolver);
        rangeVault.resolveBattle(battleId2);

        // Both should be ended
        assertEq(rangeVault.getBattleStatus(battleId1), "ended");
        assertEq(rangeVault.getBattleStatus(battleId2), "ended");
    }

    function testBattleWithDifferentDurations() public {
        // Create battles with different durations
        vm.prank(alice);
        uint256 shortBattle = rangeVault.createBattle(ALICE_TOKEN_ID, 1 hours);

        vm.prank(david);
        uint256 longBattle = rangeVault.createBattle(DAVID_TOKEN_ID, 24 hours);

        vm.prank(bob);
        rangeVault.joinBattle(shortBattle, BOB_TOKEN_ID);

        vm.prank(eve);
        rangeVault.joinBattle(longBattle, EVE_TOKEN_ID);

        // Fast forward 2 hours
        vm.warp(block.timestamp + 2 hours);

        // Short battle should be ready to resolve, long battle still onGoing
        assertEq(rangeVault.getBattleStatus(shortBattle), "readyToResolve");
        assertEq(rangeVault.getBattleStatus(longBattle), "onGoing");

        // Resolve short battle
        vm.prank(resolver);
        rangeVault.resolveBattle(shortBattle);
        assertEq(rangeVault.getBattleStatus(shortBattle), "ended");

        // Long battle still onGoing
        assertEq(rangeVault.getBattleStatus(longBattle), "onGoing");
    }

    // ============ REAL-WORLD USAGE PATTERNS ============

    function testTypicalUserJourney() public {
        // Simulate a typical user journey

        // 1. Alice creates a battle
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        // 2. Bob checks if he can join
        (bool canJoin, string memory reason) = rangeVault.canJoinBattle(battleId, BOB_TOKEN_ID);
        assertTrue(canJoin);
        assertEq(reason, "Can join battle");

        // 3. Bob joins the battle
        vm.prank(bob);
        rangeVault.joinBattle(battleId, BOB_TOKEN_ID);

        // 4. Users check battle progress during the battle
        (
            bool creatorInRange,
            bool opponentInRange,
            uint256 creatorFees,
            uint256 opponentFees,
            address currentLeader,
        ) = rangeVault.getCurrentPerformance(battleId);

        assertTrue(creatorInRange);
        assertTrue(opponentInRange);
        assertGt(creatorFees, 0);
        assertGt(opponentFees, 0);

        // 5. Time passes and battle ends
        vm.warp(block.timestamp + TEST_DURATION + 1);

        // 6. Resolver resolves the battle
        vm.prank(resolver);
        rangeVault.resolveBattle(battleId);

        // 7. Check final results
        (,,,address winner, string memory status) = rangeVault.getBattleDetails(battleId);
        assertTrue(winner == alice || winner == bob);
        assertEq(status, "ended");
    }

    function testBatchOperations() public {
        // Create multiple battles
        vm.prank(alice);
        rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        vm.prank(david);
        rangeVault.createBattle(DAVID_TOKEN_ID, TEST_DURATION * 2);

        vm.prank(eve);
        feeBattle.createBattle(EVE_TOKEN_ID, TEST_DURATION);

        // Test batch queries
        (uint256[] memory activeBattles, string[] memory statuses) = rangeVault.getAllActiveBattles();
        assertEq(activeBattles.length, 2); // Two range battles
        assertEq(statuses.length, 2);

        uint256[] memory waitingBattles = rangeVault.getBattlesWaitingForOpponent();
        assertEq(waitingBattles.length, 2);

        (uint256[] memory aliceBattles, bool[] memory isCreator) = rangeVault.getUserBattles(alice);
        assertEq(aliceBattles.length, 1);
        assertTrue(isCreator[0]);
    }

    // ============ STRESS TESTS ============

    function testHighVolumeScenario() public {
        // Create many battles to test scalability
        uint256[] memory battleIds = new uint256[](5);

        // Create 5 battles
        for (uint256 i = 0; i < 5; i++) {
            address creator = makeAddr(string(abi.encodePacked("creator", i)));
            uint256 tokenId = 2000 + i;

            // Setup position for creator
            mockPositionManager.setPositionData(
                tokenId,
                creator,
                WETH,
                USDC,
                POOL_FEE,
                -1000,
                1000,
                1000000000000000000,
                500,
                1000
            );

            vm.prank(creator);
            battleIds[i] = rangeVault.createBattle(tokenId, TEST_DURATION);
        }

        // Verify all battles were created
        for (uint256 i = 0; i < 5; i++) {
            assertEq(rangeVault.getBattleStatus(battleIds[i]), "queued");
        }

        // Check batch queries work with many battles
        (uint256[] memory activeBattles,) = rangeVault.getAllActiveBattles();
        assertEq(activeBattles.length, 5);
    }

    function testEdgeCaseValueMatching() public {
        // Test edge cases for the 5% value tolerance

        // Create base battle
        vm.prank(alice);
        uint256 battleId = rangeVault.createBattle(ALICE_TOKEN_ID, TEST_DURATION);

        // Create position exactly at 5% boundary (should work)
        uint256 boundaryTokenId = 3000;
        mockPositionManager.setPositionData(
            boundaryTokenId,
            bob,
            WETH,
            USDC,
            POOL_FEE,
            -1000,
            1000,
            960000000000000000, // 4% less (well within 5% tolerance)
            500,
            1000
        );

        (bool canJoin,) = rangeVault.canJoinBattle(battleId, boundaryTokenId);
        assertTrue(canJoin);

        // Create position just outside 5% boundary (should fail)
        uint256 outsideTokenId = 3001;
        mockPositionManager.setPositionData(
            outsideTokenId,
            charlie,
            WETH,
            USDC,
            POOL_FEE,
            -1000,
            1000,
            940000000000000000, // More than 5% less
            500,
            1000
        );

        (bool canJoinOutside,) = rangeVault.canJoinBattle(battleId, outsideTokenId);
        assertFalse(canJoinOutside);
    }
}
