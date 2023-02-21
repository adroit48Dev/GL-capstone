// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/Strings.sol";

library StringCompare {
    function isStringEqual(string memory a, string memory b)
        public
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

    function addressToString(address account)
        public
        pure
        returns (string memory)
    {
        return Strings.toHexString(uint256(uint160(account)), 20);
    }
}
