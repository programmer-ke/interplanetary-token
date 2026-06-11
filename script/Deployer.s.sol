// SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

import {Script} from "forge-std/Script.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {TokenAdminRegistry} from "@ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";
import {
    RegistryModuleOwnerCustom
} from "@ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {CCIPLocalSimulatorFork} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Register} from "@chainlink-local/src/ccip/Register.sol";

contract TokenAndPoolDeployer is Script {
    function run() public returns (RebaseToken token, RebaseTokenPool pool) {
        CCIPLocalSimulatorFork localSimulator = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails =
            localSimulator.getNetworkDetails(block.chainid);
        vm.startBroadcast();

        // create token and pool
        token = new RebaseToken();
        uint8 tokenDecimals = 18;
        address[] memory whitelist = new address[](0);
        pool = new RebaseTokenPool(
            IERC20(address(token)),
            tokenDecimals,
            whitelist,
            networkDetails.rmnProxyAddress,
            networkDetails.routerAddress
        );
        token.grantMintAndBurnRole(address(pool));

        // register pool
        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress)
            .setPool(address(token), address(pool));

        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run(address _rebaseToken) public returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(_rebaseToken));
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
