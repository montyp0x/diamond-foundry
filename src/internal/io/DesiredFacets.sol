// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../../errors/Errors.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";
import {Paths} from "../utils/Paths.sol";
import {StringUtils} from "../utils/StringUtils.sol";
import {HexUtils} from "../utils/HexUtils.sol";

/// @title DesiredFacetsIO
/// @notice JSON I/O for `.diamond-upgrades/<name>.facets.json`.
/// @dev No try/catch with stdJson; assume fields exist per our templates/tests.
library DesiredFacetsIO {
    using stdJson for string;

    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct InitSpec {
        address target;
        bytes data;
    }

    struct Facet {
        string artifact;
        bytes4[] selectors;
        string[] uses;
    }

    struct DesiredState {
        string name;
        Facet[] facets;
        InitSpec init;
    }

    // ── Load ────────────────────────────────────────────────────────────────────
    function load(string memory name) internal view returns (DesiredState memory d) {
        string memory path = Paths.facetsJson(name);
        string memory raw;
        try VM.readFile(path) returns (string memory data) {
            raw = data;
        } catch {
            revert Errors.DesiredFacetsNotFound(name);
        }

        d.name = name;

        // init
        address initTarget = raw.readAddress(".init.target");
        bytes memory initData = raw.readBytes(".init.data");

        // facets
        uint256 n = raw.readUint(".facetsCount");
        d.facets = new Facet[](n);
        for (uint256 i = 0; i < n; i++) {
            string memory base = string.concat(".facets[", StringUtils.toString(i), "]");
            d.facets[i].artifact = raw.readString(string.concat(base, ".artifact"));

            // selectors as bytes32[] -> cast to bytes4
            bytes32[] memory s32 = raw.readBytes32Array(string.concat(base, ".selectors"));
            d.facets[i].selectors = new bytes4[](s32.length);
            for (uint256 j = 0; j < s32.length; j++) {
                d.facets[i].selectors[j] = bytes4(s32[j]);
            }

            // uses as string[]
            d.facets[i].uses = raw.readStringArray(string.concat(base, ".uses"));
        }

        d.init = InitSpec({target: initTarget, data: initData});
    }

    // ── Save (direct pretty JSON build) ─────────────────────────────────────────
    function save(DesiredState memory d) internal {
        string memory path = Paths.facetsJson(d.name);

        string memory json = string.concat(
            "{\n",
            "  \"name\": \"",
            d.name,
            "\",\n",
            "  \"init\": {\n",
            "    \"target\": \"",
            VM.toString(d.init.target),
            "\",\n",
            "    \"data\": \"",
            HexUtils.toHexString(d.init.data),
            "\"\n",
            "  },\n",
            "  \"facetsCount\": ",
            StringUtils.toString(d.facets.length),
            ",\n",
            "  \"facets\": ",
            _facetsArrayJsonPretty(d.facets),
            "\n",
            "}"
        );

        // Overwrite atomically to avoid stale trailing bytes in prior file contents
        try VM.removeFile(path) {} catch {}
        VM.writeFile(path, json);
    }

    // ── Helpers ─────────────────────────────────────────────────────────────────
    function totalSelectors(DesiredState memory d) internal pure returns (uint256 n) {
        for (uint256 i = 0; i < d.facets.length; i++) {
            n += d.facets[i].selectors.length;
        }
    }

    function flattenSelectors(DesiredState memory d) internal pure returns (bytes4[] memory flat) {
        uint256 n = totalSelectors(d);
        flat = new bytes4[](n);
        uint256 w = 0;
        for (uint256 i = 0; i < d.facets.length; i++) {
            for (uint256 j = 0; j < d.facets[i].selectors.length; j++) {
                flat[w++] = d.facets[i].selectors[j];
            }
        }
    }

    function findFacet(DesiredState memory d, string memory artifact)
        internal
        pure
        returns (bool found, uint256 index)
    {
        bytes32 key;
        assembly {
            key := keccak256(add(artifact, 0x20), mload(artifact))
        }
        for (uint256 i = 0; i < d.facets.length; i++) {
            if (keccak256(bytes(d.facets[i].artifact)) == key) return (true, i);
        }
        return (false, 0);
    }

    // JSON building (pretty formatted)
    function _facetsArrayJsonPretty(Facet[] memory arr) private pure returns (string memory) {
        if (arr.length == 0) return "[]";

        string memory out = "[\n";
        for (uint256 i = 0; i < arr.length; i++) {
            out = string.concat(
                out,
                "    {\n",
                "      \"artifact\": \"",
                arr[i].artifact,
                "\",\n",
                "      \"selectors\": ",
                _selectorsArrayJsonPretty(arr[i].selectors),
                ",\n",
                "      \"uses\": ",
                _stringArrayJsonPretty(arr[i].uses),
                "\n",
                "    }",
                i + 1 == arr.length ? "\n" : ",\n"
            );
        }
        out = string.concat(out, "  ]");
        return out;
    }

    function _selectorsArrayJsonPretty(bytes4[] memory arr) private pure returns (string memory) {
        if (arr.length == 0) return "[]";

        string memory out = "[\n";
        for (uint256 i = 0; i < arr.length; i++) {
            out =
                string.concat(out, "        \"", VM.toString(bytes32(arr[i])), "\"", i + 1 == arr.length ? "\n" : ",\n");
        }
        out = string.concat(out, "      ]");
        return out;
    }

    function _stringArrayJsonPretty(string[] memory arr) private pure returns (string memory) {
        if (arr.length == 0) return "[]";

        string memory out = "[\n";
        for (uint256 i = 0; i < arr.length; i++) {
            out = string.concat(out, "        \"", arr[i], "\"", i + 1 == arr.length ? "\n" : ",\n");
        }
        out = string.concat(out, "      ]");
        return out;
    }
}
