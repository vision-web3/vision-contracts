// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
// solhint-disable func-name-mixedcase
// solhint-disable one-contract-per-file

import {VisionToken} from "../src/VisionToken.sol";
import {VisionTokenMigrator} from "../src/VisionTokenMigrator.sol";

import {BaseTest} from "./BaseTest.t.sol";
import {MockERC20} from "./helpers/MockERC20.sol";

contract VisionTokenMigratorTest is BaseTest {
    address public constant DEFAULT_ADMIN_ADDRESS = address(uint160(uint256(keccak256("DefaultAdmin"))));
    VisionTokenMigrator internal visionTokenMigrator;
    MockERC20 internal pantosToken;
    MockERC20 internal bestToken;
    VisionToken internal visionToken;

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT LOGIC                                                           
    //////////////////////////////////////////////////////////////*/

    function test_deployment_zero_address_pantos_token() external {
        vm.expectRevert(VisionTokenMigrator.InvalidZeroAddress.selector);
        visionTokenMigrator = new VisionTokenMigrator(
            address(0x0), address(bestToken), address(visionToken), address(this), DEFAULT_ADMIN_ADDRESS
        );
    }

    function test_deployment_zero_address_best_token() external {
        vm.expectRevert(VisionTokenMigrator.InvalidZeroAddress.selector);
        visionTokenMigrator = new VisionTokenMigrator(
            address(pantosToken), address(0x0), address(visionToken), address(this), DEFAULT_ADMIN_ADDRESS
        );
    }

    function test_deployment_zero_address_vision_token() external {
        vm.expectRevert(VisionTokenMigrator.InvalidZeroAddress.selector);
        visionTokenMigrator = new VisionTokenMigrator(
            address(pantosToken), address(bestToken), address(0x0), address(this), DEFAULT_ADMIN_ADDRESS
        );
    }

    function test_deployment_zero_address_CRITICAL_OPS_ROLE() external {
        vm.expectRevert(VisionTokenMigrator.InvalidZeroAddress.selector);
        visionTokenMigrator = new VisionTokenMigrator(
            address(pantosToken), address(bestToken), address(visionToken), address(0x0), DEFAULT_ADMIN_ADDRESS
        );
    }

    function test_deployment_zero_address_default_admin() external {
        vm.expectRevert(VisionTokenMigrator.InvalidZeroAddress.selector);
        visionTokenMigrator = new VisionTokenMigrator(
            address(pantosToken), address(bestToken), address(visionToken), address(this), address(0x0)
        );
    }

    /*//////////////////////////////////////////////////////////////
                            MIGRATION LOGIC                                                           
    //////////////////////////////////////////////////////////////*/

    function test_startTokenMigration_Correct() external {
        _mint_and_approve_vision(visionToken, 1);
        vm.expectEmit();
        emit VisionTokenMigrator.TokenMigrationStarted(1);

        visionTokenMigrator.startTokenMigration(1);

        assertTrue(visionTokenMigrator.isTokenMigrationStarted());
        assertEq(visionToken.balanceOf(address(visionTokenMigrator)), 1);
    }

    function test_startTokenMigration_AlreadyStarted() external {
        _mint_and_approve_vision(visionToken, 1);
        visionTokenMigrator.startTokenMigration(1);

        vm.expectRevert(VisionTokenMigrator.TokenMigrationAlreadyStarted.selector);
        visionTokenMigrator.startTokenMigration(1);
    }

    function test_previewPantosMigration() external {
        uint256 amountToMigrate = 100 * 10 ** pantosToken.decimals();
        pantosToken.mint(address(this), amountToMigrate);
        uint256 expectedVisionAmount = 88_752446040000000000;

        assertEq(visionTokenMigrator.previewPantosMigration(), expectedVisionAmount);
    }

    function test_previewPantosMigration_SmallestAmount() external {
        uint256 amountToMigrate = 1;
        pantosToken.mint(address(this), amountToMigrate);
        uint256 expectedVisionAmount = 8875244604;

        assertEq(visionTokenMigrator.previewPantosMigration(), expectedVisionAmount);
    }

    function test_previewBestMigration() external {
        uint256 amountToMigrate = 100 * 10 ** pantosToken.decimals();
        bestToken.mint(address(this), amountToMigrate);
        uint256 expectedVisionAmount = 491_390340400000000000;

        assertEq(visionTokenMigrator.previewBestMigration(), expectedVisionAmount);
    }

    function test_previewBestMigration_SmallestAmount() external {
        uint256 amountToMigrate = 1;
        bestToken.mint(address(this), amountToMigrate);
        uint256 expectedVisionAmount = 49139034040;

        assertEq(visionTokenMigrator.previewBestMigration(), expectedVisionAmount);
    }

    function test_previewPantosAndBestMigration() external {
        uint256 pantosAmount = 100 * 10 ** pantosToken.decimals();
        uint256 bestAmount = 100 * 10 ** bestToken.decimals();
        pantosToken.mint(address(this), pantosAmount);
        bestToken.mint(address(this), bestAmount);
        uint256 expectedVisionAmount = 88_752446040000000000 + 491_390340400000000000;

        assertEq(visionTokenMigrator.previewPantosAndBestMigration(), expectedVisionAmount);
    }

    function test_previewPantosAndBestMigration_SmallestAmount() external {
        uint256 pantosAmount = 1;
        uint256 bestAmount = 1;
        pantosToken.mint(address(this), pantosAmount);
        bestToken.mint(address(this), bestAmount);
        uint256 expectedVisionAmount = 8875244604 + 49139034040;

        assertEq(visionTokenMigrator.previewPantosAndBestMigration(), expectedVisionAmount);
    }

    function test_migrateTokens() external {
        uint256 pantosAmount = 100 * 10 ** pantosToken.decimals();
        uint256 bestAmount = 100 * 10 ** bestToken.decimals();
        uint256 visionAmount = 88_752446040000000000 + 491_390340400000000000;
        _mint_and_approve_old_tokens(pantosToken, pantosAmount);
        _mint_and_approve_old_tokens(bestToken, bestAmount);
        _mint_and_approve_vision(visionToken, visionAmount);
        visionTokenMigrator.startTokenMigration(visionAmount);
        vm.expectEmit();
        emit VisionTokenMigrator.TokensMigrated(address(this), pantosAmount, bestAmount, visionAmount);

        assertEq(pantosToken.balanceOf(address(this)), pantosAmount);
        assertEq(bestToken.balanceOf(address(this)), bestAmount);
        assertEq(visionToken.balanceOf(address(visionTokenMigrator)), visionAmount);
        assertEq(visionToken.balanceOf(address(this)), 0);

        visionTokenMigrator.migrateTokens();

        assertEq(pantosToken.balanceOf(address(this)), 0);
        assertEq(bestToken.balanceOf(address(this)), 0);
        assertEq(visionToken.balanceOf(address(visionTokenMigrator)), 0);
        assertEq(visionToken.balanceOf(address(this)), visionAmount);
    }

    function test_migrateTokens_ZeroPantos() external {
        uint256 bestAmount = 100 * 10 ** bestToken.decimals();
        uint256 visionAmount = 491_390340400000000000;
        _mint_and_approve_old_tokens(bestToken, bestAmount);
        _mint_and_approve_vision(visionToken, visionAmount);
        visionTokenMigrator.startTokenMigration(visionAmount);
        vm.expectEmit();
        emit VisionTokenMigrator.TokensMigrated(address(this), 0, bestAmount, visionAmount);

        assertEq(pantosToken.balanceOf(address(this)), 0);
        assertEq(bestToken.balanceOf(address(this)), bestAmount);
        assertEq(visionToken.balanceOf(address(visionTokenMigrator)), visionAmount);
        assertEq(visionToken.balanceOf(address(this)), 0);

        visionTokenMigrator.migrateTokens();

        assertEq(pantosToken.balanceOf(address(this)), 0);
        assertEq(bestToken.balanceOf(address(this)), 0);
        assertEq(visionToken.balanceOf(address(visionTokenMigrator)), 0);
        assertEq(visionToken.balanceOf(address(this)), visionAmount);
    }

    function test_migrateTokens_ZeroBest() external {
        uint256 pantosAmount = 100 * 10 ** pantosToken.decimals();
        uint256 visionAmount = 88_752446040000000000;
        _mint_and_approve_old_tokens(pantosToken, pantosAmount);
        _mint_and_approve_vision(visionToken, visionAmount);
        visionTokenMigrator.startTokenMigration(visionAmount);
        vm.expectEmit();
        emit VisionTokenMigrator.TokensMigrated(address(this), pantosAmount, 0, visionAmount);

        assertEq(pantosToken.balanceOf(address(this)), pantosAmount);
        assertEq(bestToken.balanceOf(address(this)), 0);
        assertEq(visionToken.balanceOf(address(visionTokenMigrator)), visionAmount);
        assertEq(visionToken.balanceOf(address(this)), 0);

        visionTokenMigrator.migrateTokens();

        assertEq(pantosToken.balanceOf(address(this)), 0);
        assertEq(bestToken.balanceOf(address(this)), 0);
        assertEq(visionToken.balanceOf(address(visionTokenMigrator)), 0);
        assertEq(visionToken.balanceOf(address(this)), visionAmount);
    }

    function test_migrateTokens_ZeroTokensToMigrate() external {
        uint256 pantosAmount = 0;
        uint256 bestAmount = 0;
        uint256 visionAmount = 1;
        _mint_and_approve_old_tokens(pantosToken, pantosAmount);
        _mint_and_approve_old_tokens(bestToken, bestAmount);
        _mint_and_approve_vision(visionToken, visionAmount);
        visionTokenMigrator.startTokenMigration(visionAmount);

        vm.expectRevert(VisionTokenMigrator.ZeroTokensToMigrate.selector);
        visionTokenMigrator.migrateTokens();
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTERS                                                           
    //////////////////////////////////////////////////////////////*/

    function test_getPantosToVisionExchangeRate() external view {
        uint256 expectedExchangeRate = 8875244604;
        assertEq(visionTokenMigrator.getPantosToVisionExchangeRate(), expectedExchangeRate);
    }

    function test_getBestToVisionExchangeRate() external view {
        uint256 expectedExchangeRate = 49139034040;
        assertEq(visionTokenMigrator.getBestToVisionExchangeRate(), expectedExchangeRate);
    }

    function test_getExchangeRateScalingFactor() external view {
        uint256 expectedScalingFactor = 1e10;
        assertEq(visionTokenMigrator.getExchangeRateScalingFactor(), expectedScalingFactor);
    }

    function test_getPantosTokenAddress() external view {
        assertEq(visionTokenMigrator.getPantosTokenAddress(), address(pantosToken));
    }

    function test_getBestTokenAddress() external view {
        assertEq(visionTokenMigrator.getBestTokenAddress(), address(bestToken));
    }

    function test_getVisionTokenAddress() external view {
        assertEq(visionTokenMigrator.getVisionTokenAddress(), address(visionToken));
    }

    /*//////////////////////////////////////////////////////////////
                            SETUP & HELPERS                                                
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        pantosToken = new MockERC20(8);
        bestToken = new MockERC20(8);
        deployVisionToken();
        visionToken = token;

        visionTokenMigrator = new VisionTokenMigrator(
            address(pantosToken), address(bestToken), address(visionToken), address(this), DEFAULT_ADMIN_ADDRESS
        );
    }

    function test_SetUpState() external view {
        assertEq(visionTokenMigrator.getPantosTokenAddress(), address(pantosToken));
        assertEq(visionTokenMigrator.getBestTokenAddress(), address(bestToken));
        assertEq(visionTokenMigrator.getVisionTokenAddress(), address(visionToken));
        assertFalse(visionTokenMigrator.isTokenMigrationStarted());
    }

    function _mint_and_approve_old_tokens(MockERC20 token, uint256 amount) internal {
        token.mint(address(this), amount);
        token.approve(address(visionTokenMigrator), amount);
    }

    function _mint_and_approve_vision(VisionToken token, uint256 amount) internal {
        vm.prank(minter);
        token.mint(address(this), amount);
        token.approve(address(visionTokenMigrator), amount);
    }
}
