// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, GaugeRootstockCollective } from "../BaseTest.sol";

contract SupportAndDistributeTest is BaseTest {
    GaugeRootstockCollective[] public aliceGauges;
    uint256[] public aliceVotes;

    GaugeRootstockCollective[] public bobGauges;
    uint256[] public bobVotes;

    function _setUp() internal override {
        // creates 10 gauges with 40% of reward percentage
        uint64 _rewardPercentage = 0.4 ether; // 40%
        _createGauges(10, _rewardPercentage);

        // start from a new cycle
        _skipAndStartNewCycle();
    }
    /**
     * SCENARIO: All the votes occurs at the beginning of the distribution and are not re-allocated
     *  Therefore, votes and rewards are always fully considered
     *  -   10 gauges are created with 40% of reward percentage
     *  -   alice votes to gauge 4, 5 and 6. 100 ethers are distributed
     *  -   bob votes to gauge 6, 8 and 10. 100 ethers are distributed
     *  -   40 gauges are created with 20% of reward percentage
     *  -   100 ethers are distributed. Alice, bob and current builders receive the same
     *          because new gauges were not voted
     *  -   alice votes gauge 15 and 20. 100 ethers are distributed
     *  -   bob votes gauge 25 and 40. 100 ethers are distributed
     *  -   All the rewards for backers and builders are distributed correctly
     */

    function test_integration_SupportAndDistribute() public {
        // TODO: add incentives to gauges before the distribution

        // GIVEN 10 gauges with 40% of reward percentage
        //  WHEN alice votes to gauges 4, 5 and 6
        aliceGauges.push(gaugesArray[4]);
        aliceVotes.push(1 ether);

        aliceGauges.push(gaugesArray[5]);
        aliceVotes.push(10 ether);

        aliceGauges.push(gaugesArray[6]);
        aliceVotes.push(100 ether);

        vm.prank(alice);
        backersManager.allocateBatch(aliceGauges, aliceVotes);

        // AND 100 rewardTokens and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        _skipAndStartNewCycle();

        vm.prank(alice);
        // WHEN alice claims the rewards
        backersManager.claimBackerRewards(aliceGauges);
        // THEN alice receives 40 rewardTokens
        assertApproxEqAbs(_clearERC20Balance(alice), 40 ether, 100);
        // THEN alice receives 4 coinbase
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 4 ether, 100);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN builder 4 receives 0.54 rewardTokens = 60 * 1 / 111
        assertApproxEqAbs(_clearERC20Balance(builders[4]), 540_540_540_540_540_540, 100);
        // THEN builder 4 receives 0.054 coinbase = 6 * 1 / 111
        assertApproxEqAbs(_clearCoinbaseBalance(builders[4]), 54_054_054_054_054_054, 100);

        // THEN builder 5 receives 5.40 rewardTokens = 60 * 10 / 111
        assertApproxEqAbs(_clearERC20Balance(builders[5]), 5_405_405_405_405_405_405, 100);
        // THEN builder 5 receives 0.54 coinbase = 6 * 10 / 111
        assertApproxEqAbs(_clearCoinbaseBalance(builders[5]), 540_540_540_540_540_540, 100);

        // THEN builder 6 receives 54.05 rewardTokens = 60 * 100 / 111
        assertApproxEqAbs(_clearERC20Balance(builders[6]), 54_054_054_054_054_054_054, 100);
        // THEN builder 6 receives 5.405 coinbase = 6 * 100 / 111
        assertApproxEqAbs(_clearCoinbaseBalance(builders[6]), 5_405_405_405_405_405_454, 100);

        // AND bob votes to gauges 6, 8 and 10
        bobGauges.push(gaugesArray[6]);
        bobVotes.push(2 ether);

        bobGauges.push(gaugesArray[8]);
        bobVotes.push(20 ether);

        bobGauges.push(gaugesArray[10]);
        bobVotes.push(200 ether);

        vm.prank(bob);
        backersManager.allocateBatch(bobGauges, bobVotes);

        // AND 100 rewardTokens and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        _skipAndStartNewCycle();

        // WHEN alice claims the rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(aliceGauges);
        // THEN alice receives 13.33 rewardToken = 40 * 111 / 333
        assertApproxEqAbs(_clearERC20Balance(alice), 13_333_333_333_333_333_333, 100);
        // THEN alice receives 1.333 coinbase = 4 * 111 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 1_333_333_333_333_333_333, 100);

        // WHEN bob claims the rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(bobGauges);
        // THEN bob receives 26.66 rewardToken = 40 * 222 / 333
        assertApproxEqAbs(_clearERC20Balance(bob), 26_666_666_666_666_666_666, 100);
        // THEN bob receives 2.666 coinbase = 4 * 222 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(bob), 2_666_666_666_666_666_666, 100);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN builder 4 receives rewardToken 0.18 = 60 * 1 / 333
        assertApproxEqAbs(_clearERC20Balance(builders[4]), 180_180_180_180_180_180, 100);
        // THEN builder 4 receives coinbase 0.018 = 6 * 1 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(builders[4]), 18_018_018_018_018_018, 100);

        // THEN builder 5 receives rewardToken 1.80 = 60 * 10 / 333
        assertApproxEqAbs(_clearERC20Balance(builders[5]), 1_801_801_801_801_801_801, 100);
        // THEN builder 5 receives coinbase 0.180 = 6 * 10 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(builders[5]), 180_180_180_180_180_180, 100);

        // THEN builder 6 receives rewardToken 18.37 = 60 * 102 / 333
        assertApproxEqAbs(_clearERC20Balance(builders[6]), 18_378_378_378_378_378_378, 100);
        // THEN builder 6 receives coinbase 1.837 = 6 * 102 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(builders[6]), 1_837_837_837_837_837_838, 100);

        // THEN builder 4 receives rewardToken 0.36 = 60 * 2 / 333
        assertApproxEqAbs(_clearERC20Balance(builders[8]), 3_603_603_603_603_603_603, 100);
        // THEN builder 4 receives coinbase 0.036 = 6 * 2 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(builders[8]), 360_360_360_360_360_360, 100);

        // THEN builder 5 receives rewardToken 36.03 = 60 * 200 / 333
        assertApproxEqAbs(_clearERC20Balance(builders[10]), 36_036_036_036_036_036_036, 100);
        // THEN builder 5 receives coinbase 3.603 = 6 * 200 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(builders[10]), 3_603_603_603_603_603_606, 100);

        // AND creates 40 gauges with 20% of reward percentage
        uint64 _rewardPercentage = 0.2 ether; // 20%
        _createGauges(40, _rewardPercentage);

        // TODO: add incentives to new gauges before the distribution

        // AND 100 rewardTokens and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        _skipAndStartNewCycle();

        // WHEN alice claims the rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(aliceGauges);
        // THEN alice receives 13.33 rewardToken = 40 * 111 / 333
        assertApproxEqAbs(_clearERC20Balance(alice), 13_333_333_333_333_333_333, 100);
        // THEN alice receives 1.333 coinbase = 4 * 111 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 1_333_333_333_333_333_333, 100);

        // WHEN bob claims the rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(bobGauges);
        // THEN bob receives 26.66 rewardToken = 40 * 222 / 333
        assertApproxEqAbs(_clearERC20Balance(bob), 26_666_666_666_666_666_666, 100);
        // THEN bob receives 2.666 coinbase = 4 * 222 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(bob), 2_666_666_666_666_666_666, 100);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN builder 4 receives 0.18 rewardToken = 60 * 1 / 333
        assertApproxEqAbs(_clearERC20Balance(builders[4]), 180_180_180_180_180_180, 100);
        // THEN builder 4 receives 0.018 coinbase = 6 * 1 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(builders[4]), 18_018_018_018_018_018, 100);

        // THEN builder 5 receives 1.80 rewardToken = 60 * 10 / 333
        assertApproxEqAbs(_clearERC20Balance(builders[5]), 1_801_801_801_801_801_801, 100);
        // THEN builder 5 receives 0.180 coinbase = 6 * 10 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(builders[5]), 180_180_180_180_180_180, 100);

        // THEN builder 6 receives 18.37 rewardToken = 60 * 102 / 333
        assertApproxEqAbs(_clearERC20Balance(builders[6]), 18_378_378_378_378_378_378, 100);
        // THEN builder 6 receives 1.837 coinbase = 6 * 102 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(builders[6]), 1_837_837_837_837_837_838, 100);

        // THEN builder 8 receives 0.36 rewardToken = 60 * 2 / 333
        assertApproxEqAbs(_clearERC20Balance(builders[8]), 3_603_603_603_603_603_603, 100);
        // THEN builder 8 receives 0.036 coinbase = 6 * 2 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(builders[8]), 360_360_360_360_360_360, 100);

        // THEN builder 10 receives 36.03 rewardToken = 60 * 200 / 333
        assertApproxEqAbs(_clearERC20Balance(builders[10]), 36_036_036_036_036_036_036, 100);
        // THEN builder 10 receives 3.603 coinbase = 6 * 200 / 333
        assertApproxEqAbs(_clearCoinbaseBalance(builders[10]), 3_603_603_603_603_603_603, 100);

        // WHEN alice votes to gauges 15 and 20
        aliceGauges.push(gaugesArray[15]);
        aliceVotes.push(1 ether);

        aliceGauges.push(gaugesArray[20]);
        aliceVotes.push(10 ether);

        vm.prank(alice);
        backersManager.allocateBatch(aliceGauges, aliceVotes);

        // AND bob votes to gauges 25 and 40
        bobGauges.push(gaugesArray[25]);
        bobVotes.push(2 ether);

        bobGauges.push(gaugesArray[40]);
        bobVotes.push(20 ether);

        vm.prank(bob);
        backersManager.allocateBatch(bobGauges, bobVotes);

        // AND 100 rewardTokens and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        _skipAndStartNewCycle();

        // WHEN alice claims the rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(aliceGauges);
        // THEN alice receives 12.13 rewardToken = 40 * 111 / 366
        // AND alice receives 0.60 rewardToken = 20 * 11 / 366
        assertEq(_clearERC20Balance(alice), 12_732_240_437_158_469_843);
        // THEN alice receives 1.213 coinbase = 4 * 111 / 366
        // AND alice receives 0.060 coinbase = 2 * 11 / 366
        assertEq(_clearCoinbaseBalance(alice), 1_273_224_043_715_846_896);

        // WHEN bob claims the rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(bobGauges);
        // THEN bob receives 24.26 rewardToken = 40 * 222 / 366
        // AND bob receives 1.20 rewardToken = 20 * 22 / 366
        assertEq(_clearERC20Balance(bob), 25_464_480_874_316_939_690);
        // THEN bob receives 2.426 coinbase = 4 * 222 / 366
        // AND bob receives 0.120 coinbase = 2 * 22 / 366
        assertEq(_clearCoinbaseBalance(bob), 2_546_448_087_431_693_796);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN builder 4 receives rewardToken 0.16 = 60 * 1 / 366
        assertEq(_clearERC20Balance(builders[4]), 163_934_426_229_508_197);
        // THEN builder 4 receives coinbase 0.016 = 6 * 1 / 366
        assertEq(_clearCoinbaseBalance(builders[4]), 16_393_442_622_950_820);

        // THEN builder 5 receives rewardToken 1.63 = 60 * 10 / 366
        assertEq(_clearERC20Balance(builders[5]), 1_639_344_262_295_081_967);
        // THEN builder 5 receives coinbase 0.163 = 6 * 10 / 366
        assertEq(_clearCoinbaseBalance(builders[5]), 163_934_426_229_508_197);

        // THEN builder 6 receives rewardToken 16.72 = 60 * 102 / 366
        assertEq(_clearERC20Balance(builders[6]), 16_721_311_475_409_836_066);
        // THEN builder 6 receives coinbase 1.672 = 6 * 102 / 366
        assertEq(_clearCoinbaseBalance(builders[6]), 1_672_131_147_540_983_607);

        // THEN builder 4 receives rewardToken 0.32 = 60 * 2 / 366
        assertEq(_clearERC20Balance(builders[8]), 3_278_688_524_590_163_934);
        // THEN builder 4 receives coinbase 0.032 = 6 * 2 / 366
        assertEq(_clearCoinbaseBalance(builders[8]), 327_868_852_459_016_394);

        // THEN builder 5 receives rewardToken 32.78 = 60 * 200 / 366
        assertEq(_clearERC20Balance(builders[10]), 32_786_885_245_901_639_345);
        // THEN builder 5 receives coinbase 3.278 = 6 * 200 / 366
        assertEq(_clearCoinbaseBalance(builders[10]), 3_278_688_524_590_163_934);

        // THEN builder 15 receives rewardToken 0.21 = 80 * 1 / 366
        assertEq(_clearERC20Balance(builders[15]), 218_579_234_972_677_596);
        // THEN builder 15 receives coinbase 0.021 = 8 * 1 / 366
        assertEq(_clearCoinbaseBalance(builders[15]), 21_857_923_497_267_760);

        // THEN builder 20 receives rewardToken 2.18 = 80 * 10 / 366
        assertEq(_clearERC20Balance(builders[20]), 2_185_792_349_726_775_956);
        // THEN builder 20 receives coinbase 0.218 = 8 * 10 / 366
        assertEq(_clearCoinbaseBalance(builders[20]), 218_579_234_972_677_596);

        // THEN builder 25 receives rewardToken 0.43 = 80 * 2 / 366
        assertEq(_clearERC20Balance(builders[25]), 437_158_469_945_355_192);
        // THEN builder 25 receives coinbase 0.043 = 8 * 2 / 366
        assertEq(_clearCoinbaseBalance(builders[25]), 43_715_846_994_535_519);

        // THEN builder 40 receives rewardToken 4.37 = 80 * 20 / 366
        assertEq(_clearERC20Balance(builders[40]), 4_371_584_699_453_551_912);
        // THEN builder 40 receives coinbase 0.437 = 8 * 20 / 366
        assertEq(_clearCoinbaseBalance(builders[40]), 437_158_469_945_355_192);
    }
}
