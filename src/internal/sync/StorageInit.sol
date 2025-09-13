// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {Paths} from "../utils/Paths.sol";
import {StorageConfigIO} from "../io/StorageConfig.sol";

/// @title StorageInit
/// @notice Script-time helper to generate (or augment) `.diamond-upgrades/<name>.storage.json`.
/// @dev Uses Foundry cheatcodes directly; call from a forge script before deploying.
library StorageInit {
    // Foundry Vm handle
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Minimal seed describing a namespace you want to ensure exists in storage.json.
    /// @dev `slot` is derived as keccak256(namespaceId) to keep convention stable.
    struct NamespaceSeed {
        string namespaceId;       // e.g., "counter.v1"
        uint64 version;           // e.g., 1
        string artifact;          // optional: "src/.../LibCounterStorage.sol:LibCounterStorage"
        string libraryName;       // optional: "LibCounterStorage"
    }

    /// @notice Ensure storage config exists and contains the given namespaces.
    /// @param name Diamond name (file will be `.diamond-upgrades/<name>.storage.json`).
    /// @param seeds Namespaces to ensure; existing ones are left untouched.
    /// @param appendOnlyPolicy Global policy flag (recommended: true).
    /// @param allowDualWrite Allow temporary v1+v2 coexistence (usually false unless migrating).
    function ensure(
        string memory name,
        NamespaceSeed[] memory seeds,
        bool appendOnlyPolicy,
        bool allowDualWrite
    ) internal {
        string memory path = Paths.storageJson(name);

        // Load if exists; otherwise start a fresh config.
        StorageConfigIO.StorageConfig memory cfg;
        bool exists = _fileExists(path);

        if (exists) {
            cfg = StorageConfigIO.load(name);
            // update policies to passed values (caller decides)
            cfg.appendOnlyPolicy = appendOnlyPolicy;
            cfg.allowDualWrite = allowDualWrite;
        } else {
            cfg.name = name;
            cfg.appendOnlyPolicy = appendOnlyPolicy;
            cfg.allowDualWrite = allowDualWrite;
            cfg.namespaces = new StorageConfigIO.NamespaceConfig[](0);
        }

        // For each seed, add if missing (do not overwrite existing entries).
        for (uint256 i = 0; i < seeds.length; i++) {
            StorageConfigIO.NamespaceConfig memory ns = _toNamespaceConfig(seeds[i]);
            (bool ok, ) = StorageConfigIO.find(cfg, ns.namespaceId);
            if (!ok) {
                cfg.namespaces = _appendNamespace(cfg.namespaces, ns);
            }
        }

        StorageConfigIO.save(cfg);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Internals
    // ─────────────────────────────────────────────────────────────────────────────

    function _fileExists(string memory path) private view returns (bool) {
        // vm.readFile reverts if not found; probe via try/catch
        try vm.readFile(path) returns (string memory /*data*/) {
            return true;
        } catch {
            return false;
        }
    }

    function _toNamespaceConfig(NamespaceSeed memory s) private pure returns (StorageConfigIO.NamespaceConfig memory ns) {
        ns.namespaceId = s.namespaceId;
        ns.slot = keccak256(bytes(s.namespaceId)); // deterministic slot from namespaceId
        ns.version = s.version == 0 ? 1 : s.version;
        ns.status = StorageConfigIO.NamespaceStatus.Active;
        ns.supersededBy = "";
        ns.artifact = s.artifact;
        ns.libraryName = s.libraryName;
    }

    function _appendNamespace(
        StorageConfigIO.NamespaceConfig[] memory arr,
        StorageConfigIO.NamespaceConfig memory ns
    ) private pure returns (StorageConfigIO.NamespaceConfig[] memory out) {
        out = new StorageConfigIO.NamespaceConfig[](arr.length + 1);
        for (uint256 i = 0; i < arr.length; i++) out[i] = arr[i];
        out[arr.length] = ns;
    }
}
