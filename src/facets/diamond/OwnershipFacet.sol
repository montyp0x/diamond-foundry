// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC173} from "../../interfaces/diamond/IERC173.sol";
import {LibDiamond} from "../../libraries/diamond/LibDiamond.sol";

/// @title OwnershipFacet
/// @notice Minimal IERC173 ownership facet for Diamonds.
/// @dev Uses LibDiamond's ownership storage and guards.
contract OwnershipFacet is IERC173 {
    /// @inheritdoc IERC173
    function owner() external view returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    /// @inheritdoc IERC173
    function transferOwnership(address newOwner) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(newOwner);
    }
}
