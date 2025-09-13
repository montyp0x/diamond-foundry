// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamondCut} from "../../interfaces/diamond/IDiamondCut.sol";
import {Errors} from "../../errors/Errors.sol";

/// @title PlanExecutor
/// @notice Executes a grouped cut plan against a Diamond, with an optional init delegatecall.
/// @dev Minimal wrapper around EIP-2535 diamondCut. Keeps error handling consistent.
library PlanExecutor {
    /// @notice Execute `diamondCut` with an optional init target/calldata.
    /// @param diamond The Diamond contract address.
    /// @param cuts Grouped facet cuts (Add/Replace/Remove).
    /// @param init Optional initializer target (0 if none).
    /// @param initCalldata Optional initializer calldata (empty if none).
    function execute(
        address diamond,
        IDiamondCut.FacetCut[] memory cuts,
        address init,
        bytes memory initCalldata
    ) internal {
        // Basic sanity for init pairing
        if ((init == address(0)) != (initCalldata.length == 0)) {
            // Either target without data or data without target
            revert Errors.InitCalldataMissing();
        }

        // Perform the diamondCut call
        try IDiamondCut(diamond).diamondCut(cuts, init, initCalldata) {
            // success, nothing else to do
        } catch (bytes memory returndata) {
            revert Errors.InitFailed(returndata);
        }
    }
}
