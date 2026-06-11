// SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "@ccip/contracts/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/libraries/RateLimiter.sol";

contract ConfigurePool is Script {
    function run(
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteToken,
        bool outboundRateLimiterIsEnabled,
        uint128 outboundRateLimiterRate,
        uint128 outboundRateLimiterCapacity,
        bool inboundRateLimiterIsEnabled,
        uint128 inboundRateLimiterRate,
        uint128 inboundRateLimiterCapacity
    ) public {
        vm.startBroadcast();
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);
        bytes memory remoteTokenAddress = abi.encode(remoteToken);

        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: remoteTokenAddress,
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outboundRateLimiterIsEnabled,
                capacity: outboundRateLimiterCapacity,
                rate: outboundRateLimiterRate
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inboundRateLimiterIsEnabled,
                capacity: inboundRateLimiterCapacity,
                rate: inboundRateLimiterRate
            })
        });

        uint64[] memory chainsToRemove = new uint64[](0);
        TokenPool(localPool).applyChainUpdates(chainsToRemove, chainsToAdd);

        vm.stopBroadcast();
    }
}
