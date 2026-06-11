// SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

import {BurnMintTokenPoolAbstract} from "@ccip/contracts/pools/BurnMintTokenPoolAbstract.sol";
import {Pool} from "@ccip/contracts/libraries/Pool.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {ITypeAndVersion} from "@chainlink/contracts/src/v0.8/shared/interfaces/ITypeAndVersion.sol";
import {TokenPool} from "@ccip/contracts/pools/TokenPool.sol";

contract RebaseTokenPool is BurnMintTokenPoolAbstract {
    /*//////////////////////////////////////////////////////////////
                             State Variables
    //////////////////////////////////////////////////////////////*/

    constructor(
        IERC20 _token,
        uint8 tokenDecimals,
        address[] memory _whitelist,
        address _rnmProxy,
        address _router
    ) TokenPool(_token, tokenDecimals, _whitelist, _rnmProxy, _router) {}

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        public
        override
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);
        address sender = lockOrBurnIn.originalSender;
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(sender);

        // CCIP transfers token to the pool before lockOrBurn is called
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

        emit LockedOrBurned({
            remoteChainSelector: lockOrBurnIn.remoteChainSelector,
            token: address(i_token),
            sender: msg.sender,
            amount: lockOrBurnIn.amount
        });

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        public
        override
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        _validateReleaseOrMint(releaseOrMintIn, releaseOrMintIn.sourceDenominatedAmount);
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        address receiver = releaseOrMintIn.receiver;
        IRebaseToken(address(i_token))
            .mint(receiver, releaseOrMintIn.sourceDenominatedAmount, userInterestRate);

        emit ReleasedOrMinted({
            remoteChainSelector: releaseOrMintIn.remoteChainSelector,
            token: address(i_token),
            sender: msg.sender,
            recipient: releaseOrMintIn.receiver,
            amount: releaseOrMintIn.sourceDenominatedAmount
        });

        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.sourceDenominatedAmount});
    }
}
