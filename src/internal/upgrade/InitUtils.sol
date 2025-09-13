// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../errors/Errors.sol";
import {DesiredFacetsIO} from "../io/DesiredFacets.sol";

/// @title InitUtils
/// @notice Helpers to prepare a single post-cut initializer (delegatecall target + calldata).
/// @dev Keeps pairing rules and merging logic in one place.
library InitUtils {
    /// @notice Canonical initializer pair.
    struct InitPair {
        address target; // 0 means "no init"
        bytes data; // empty means "no init"
    }

    /// @notice Ensure the (target,data) pair is either fully present or fully absent.
    function assertPaired(InitPair memory p) internal pure {
        bool hasTarget = p.target != address(0);
        bool hasData = p.data.length != 0;
        if (hasTarget != hasData) {
            revert Errors.InitCalldataMissing();
        }
    }

    /// @notice Convert DesiredFacetsIO.InitSpec to InitPair and validate pairing.
    function fromDesired(DesiredFacetsIO.InitSpec memory d) internal pure returns (InitPair memory p) {
        p = InitPair({target: d.target, data: d.data});
        assertPaired(p);
    }

    /// @notice Merge desired init with an explicit override; override wins when present.
    /// @dev If `overridePair` is empty (both zero), returns the desired one.
    function merge(InitPair memory desiredPair, InitPair memory overridePair)
        internal
        pure
        returns (InitPair memory out)
    {
        assertPaired(desiredPair);
        assertPaired(overridePair);

        // If override is absent, use desired.
        if (overridePair.target == address(0) && overridePair.data.length == 0) {
            return desiredPair;
        }
        return overridePair;
    }

    /// @notice True if pair is effectively empty.
    function isEmpty(InitPair memory p) internal pure returns (bool) {
        return p.target == address(0) && p.data.length == 0;
    }
}
