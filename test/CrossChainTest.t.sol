// SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Register} from "@chainlink-local/src/ccip/Register.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {
    RegistryModuleOwnerCustom
} from "@ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "@ccip/contracts/libraries/RateLimiter.sol";
import {TokenPool} from "@ccip/contracts/pools/TokenPool.sol";
import {Client} from "@ccip/contracts/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/interfaces/IRouterClient.sol";

contract CrossChainTest is Test {
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    Vault vault;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // deploy in sepolia fork
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        console.log("sepolia", block.chainid);
        uint8 localTokenDecimals = 18;

        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            localTokenDecimals,
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaToken.grantMintAndBurnRole(address(vault));
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(sepoliaToken), address(sepoliaPool));
        vm.stopPrank();

        // deploy in arb sepolia fork
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        console.log("sepolia", block.chainid);

        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            localTokenDecimals,
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaToken), address(arbSepoliaPool));

        //
        assertEq(
            TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
                .getPool(address(arbSepoliaToken)),
            address(arbSepoliaPool),
            "Pool not set for arbSepolia"
        );

        vm.stopPrank();

        // configure pools
        configureTokenPool(
            sepoliaFork,
            address(sepoliaPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaPool),
            address(arbSepoliaToken)
        );
        configureTokenPool(
            arbSepoliaFork,
            address(arbSepoliaPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaPool),
            address(sepoliaToken)
        );
    }

    /// @dev Helper function that does pool configuration
    function configureTokenPool(
        uint256 localForkId,
        address localPoolAddress,
        uint64 remoteChainSelector,
        address remotePoolAddress,
        address remoteTokenAddress
    ) public {
        vm.selectFork(localForkId);

        // not removing any configuration, pass empty array
        uint64[] memory remoteChainSelectorsToRemove = new uint64[](0);

        // construct chains to add
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePoolAddress);

        RebaseTokenPool.ChainUpdate[] memory chainsToAdd = new RebaseTokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });

        // apply chain updates
        vm.prank(owner);
        TokenPool(localPoolAddress).applyChainUpdates(remoteChainSelectorsToRemove, chainsToAdd);
    }

    function bridgeTokens(
        address user,
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork);

        // create token amounts
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] =
            Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});

        // construct cross chain message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "", // no additional data to send
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 500_000})) // use default gas limit
        });

        // fund user with transfer fee
        uint256 fee = IRouterClient(localNetworkDetails.routerAddress)
            .getFee(remoteNetworkDetails.chainSelector, message);

        console.log("fee", fee);

        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);

        // approve router to spend LINK fee
        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);

        // approve router to tranfer the amount to bridge
        vm.prank(user);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);

        // bridge token
        uint256 localInterestRate = localToken.getUserInterestRate(user);
        uint256 localBalanceBefore = localToken.balanceOf(user);

        console.log("localInterestRate", localInterestRate);
        console.log("localBalanceBefore", localBalanceBefore);

        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress)
            .ccipSend(remoteNetworkDetails.chainSelector, message);

        uint256 localBalanceAfter = localToken.balanceOf(user);
        assertEq(
            localBalanceBefore - localBalanceAfter,
            amountToBridge,
            "Local balance incorrect after change"
        );

        // check initial remote balance
        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 20 minutes);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);
        console.log("remoteBalanceBefore", remoteBalanceBefore);

        // Switch back to local fork and route message
        vm.selectFork(localFork);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        vm.selectFork(remoteFork);
        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);
        uint256 remoteInterestRate = remoteToken.getUserInterestRate(user);

        console.log("remoteBalanceAfter", remoteBalanceAfter);
        console.log("remoteInterestRate", remoteInterestRate);

        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
        assertEq(localInterestRate, remoteInterestRate, "Interest Rates do not match");
    }

    function testBridgeAllTokens() public {
        uint256 DEPOSIT_AMOUNT = 1e5;

        // deposit into vault in sepolia
        vm.selectFork(sepoliaFork);
        vm.deal(user, DEPOSIT_AMOUNT);
        vm.prank(user);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        assertEq(sepoliaToken.balanceOf(user), DEPOSIT_AMOUNT);

        // Bridge tokens: sepolia -> arb sepolia
        bridgeTokens(
            user,
            DEPOSIT_AMOUNT,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaToken,
            arbSepoliaToken
        );

        // Bridge tokens in reverse.
        vm.warp(block.timestamp + 20 minutes);
        uint256 arbBalance = arbSepoliaToken.balanceOf(user);
        assertTrue(arbBalance > 0);

        bridgeTokens(
            user,
            arbBalance,
            arbSepoliaFork,
            sepoliaFork,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            arbSepoliaToken,
            sepoliaToken
        );

        vm.selectFork(sepoliaFork);
        // Balance may include some little interest
        assertGe(sepoliaToken.balanceOf(user), DEPOSIT_AMOUNT);
    }
}
