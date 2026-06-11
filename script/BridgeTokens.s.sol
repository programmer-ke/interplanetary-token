// SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

import {Script} from "forge-std/Script.sol";
import {Client} from "@ccip/contracts/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/interfaces/IRouterClient.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";

contract BridgeTokenScript is Script {
    function run(
        address receiverAddress,
        uint64 destinationChainSelector,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        address routerAddress
    ) public {
        vm.startBroadcast();

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] =
            Client.EVMTokenAmount({token: address(tokenToSendAddress), amount: amountToSend});

        // construct cross chain message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "", // no additional data to send
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });

        // fund user with transfer fee
        uint256 fee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);

        // approve spending fees and bridge amounts
        IERC20(linkTokenAddress).approve(routerAddress, fee);

        IERC20(address(tokenToSendAddress)).approve(routerAddress, amountToSend);
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);

        vm.stopBroadcast();
    }
}
