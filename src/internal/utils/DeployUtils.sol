// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";

library DeployUtils {
    Vm constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    error DeployFailed(string artifact, string ctorHex);

    /// @notice Deploy contract by FQN through CREATE (determinism is not guaranteed).
    function deploy(string memory artifactFqn, bytes memory ctorArgs) internal returns (address deployed) {
        bytes memory creation = _creationCode(artifactFqn, ctorArgs);
        deployed = _create(creation);
        if (deployed == address(0) || deployed.code.length == 0) {
            revert DeployFailed(artifactFqn, VM.toString(ctorArgs));
        }
    }

    // ── internal helpers ──────────────────────────────────────
    function _creationCode(string memory artifactFqn, bytes memory ctorArgs) private view returns (bytes memory) {
        bytes memory bytecode = VM.getCode(artifactFqn);
        return ctorArgs.length == 0 ? bytecode : abi.encodePacked(bytecode, ctorArgs);
    }

    function _create(bytes memory creation) private returns (address addr) {
        /// @solidity memory-safe-assembly
        assembly {
            addr := create(0, add(creation, 0x20), mload(creation))
        }
    }
}
