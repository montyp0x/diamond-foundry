// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";

import {Utils} from "../utils/Utils.sol";
import {StringUtils} from "../utils/StringUtils.sol";
import {DesiredFacetsIO} from "../io/DesiredFacets.sol";
import {StorageConfigIO} from "../io/StorageConfig.sol";
import {FacetSync} from "../sync/FacetSync.sol";

library FacetDiscovery {
    using StringUtils for string;

    Vm internal constant vm = Vm(Utils.CHEATCODE_ADDRESS);

    struct Options {
        bool overwrite; // перезаписать facets.json, если уже есть
        bool autoSync; // сразу FacetSync.syncSelectors(name)
        bool inferUsesFromTags; // читать // @uses <ns> из исходника
        bool fallbackSingleNamespace; // если в storage.json один ns — подставить
    }

    /// @notice Сканирует src/<name>/facets/**.sol, находит их контракты в out/, пишет facets.json и (опц.) синкает селекторы.
    function discoverAndWrite(string memory name, Options memory opt) internal {
        string memory facetsPath = string.concat(".diamond-upgrades/", name, "/facets.json");
        if (!opt.overwrite) {
            try vm.readFile(facetsPath) {
                return;
            } catch {}
        }

        // 1) список исходников из src/<name>/facets/**/*.sol командой find
        string[] memory srcFiles = _listSources(name);

        // 2) собрать Facet[]: по каждому .sol найти соответствующие артефакты из out/<File>.sol/*.json,
        //    отфильтровать по .sourceName == src/<name>/facets/.../<File>.sol
        DesiredFacetsIO.Facet[] memory facets = _collectFacets(name, srcFiles, opt);

        // 3) записать facets.json
        DesiredFacetsIO.DesiredState memory d;
        d.name = name;
        d.init = DesiredFacetsIO.InitSpec({target: address(0), data: ""});
        d.facets = facets;
        DesiredFacetsIO.save(d);

        // 4) синк селекторов
        if (opt.autoSync) {
            FacetSync.syncSelectors(name);
        }
    }

    // ───────────────────────────────────────────────────────────────────────────

    function _listSources(string memory name) private returns (string[] memory list) {
        // find "src/<name>/facets" -type f -name "*.sol" (recursive search)
        string memory root = string.concat("src/", name, "/facets");
        string[] memory args = new string[](6);
        args[0] = "find";
        args[1] = root;
        args[2] = "-type";
        args[3] = "f";
        args[4] = "-name";
        args[5] = "*.sol";
        // через Utils.runAsBashCommand
        Vm.FfiResult memory r = Utils.runAsBashCommand(args);
        string memory out = string(r.stdout);
        if (bytes(out).length == 0) return new string[](0);
        list = vm.split(out, "\n");
        // убрать пустую последнюю строку
        if (list.length > 0 && bytes(list[list.length - 1]).length == 0) {
            string[] memory trimmed = new string[](list.length - 1);
            for (uint256 i = 0; i < trimmed.length; i++) {
                trimmed[i] = list[i];
            }
            list = trimmed;
        }
    }

    function _collectFacets(string memory name, string[] memory srcFiles, Options memory opt)
        private
        returns (DesiredFacetsIO.Facet[] memory out)
    {
        // fallback: если один namespace — используем его
        string[] memory fallbackNs = _getFallbackNamespaces(name, opt);

        // грубая верхняя граница: максимум по числу обнаруженных src-файлов * N контрактов в файле
        DesiredFacetsIO.Facet[] memory buf = new DesiredFacetsIO.Facet[](srcFiles.length * 4);
        uint256 w = 0;

        for (uint256 i = 0; i < srcFiles.length; i++) {
            w = _processSourceFile(srcFiles[i], fallbackNs, opt, buf, w);
        }

        // trim
        out = new DesiredFacetsIO.Facet[](w);
        for (uint256 t = 0; t < w; t++) {
            out[t] = buf[t];
        }
    }

    function _getFallbackNamespaces(string memory name, Options memory opt)
        private
        view
        returns (string[] memory fallbackNs)
    {
        fallbackNs = new string[](0);
        if (opt.fallbackSingleNamespace) {
            fallbackNs = _singleNs(name);
        }
    }

    function _processSourceFile(
        string memory src,
        string[] memory fallbackNs,
        Options memory opt,
        DesiredFacetsIO.Facet[] memory buf,
        uint256 w
    ) private returns (uint256 newW) {
        if (bytes(src).length == 0) return w;

        string[] memory artifacts = _getArtifactsForSource(src);
        if (artifacts.length == 0) return w;

        newW = w;
        for (uint256 j = 0; j < artifacts.length; j++) {
            DesiredFacetsIO.Facet memory facet = _createFacetFromArtifact(artifacts[j], src, fallbackNs, opt);
            if (bytes(facet.artifact).length > 0) {
                buf[newW++] = facet;
            }
        }
    }

    function _getArtifactsForSource(string memory src) private returns (string[] memory artifacts) {
        string memory fileSol = _basename(src);
        string memory dir = string.concat(Utils.getOutDir(), "/", fileSol);

        string[] memory args = new string[](3);
        args[0] = "bash";
        args[1] = "-c";
        args[2] = string.concat("ls -1 ", dir, "/*.json 2>/dev/null || true");

        Vm.FfiResult memory r = vm.tryFfi(args);
        if (r.exitCode != 0 && r.stdout.length == 0) {
            return new string[](0);
        }

        string memory outList = string(r.stdout);
        if (bytes(outList).length == 0) {
            return new string[](0);
        }

        artifacts = vm.split(outList, "\n");
        if (artifacts.length > 0 && bytes(artifacts[artifacts.length - 1]).length == 0) {
            string[] memory trimmed = new string[](artifacts.length - 1);
            for (uint256 k = 0; k < trimmed.length; k++) {
                trimmed[k] = artifacts[k];
            }
            artifacts = trimmed;
        }
    }

    function _createFacetFromArtifact(
        string memory ap,
        string memory src,
        string[] memory fallbackNs,
        Options memory opt
    ) private returns (DesiredFacetsIO.Facet memory facet) {
        if (bytes(ap).length == 0 || !_endsWith(ap, ".json")) {
            return facet;
            // empty facet
        }

        string memory json;
        try vm.readFile(ap) returns (string memory fileContent) {
            json = fileContent;
        } catch {
            return facet;
            // empty facet
        }

        if (!json.contains(src)) {
            return facet;
            // empty facet
        }

        string memory fileSol = _basename(src);
        string memory contractName = _chopSuffix(_basename(ap), ".json");
        string memory artifactId = string.concat(fileSol, ":", contractName);

        string[] memory uses = fallbackNs;
        if (opt.inferUsesFromTags) {
            try vm.readFile(src) returns (string memory srcCode) {
                string[] memory tags = _extractUsesTags(srcCode);
                if (tags.length > 0) uses = tags;
            } catch {}
        }

        facet = DesiredFacetsIO.Facet({artifact: artifactId, selectors: new bytes4[](0), uses: uses});
    }

    // единственный namespace → ["ns"] иначе []
    function _singleNs(string memory name) internal view returns (string[] memory one) {
        StorageConfigIO.StorageConfig memory cfg = StorageConfigIO.load(name);
        if (cfg.namespaces.length == 1) {
            one = new string[](1);
            one[0] = cfg.namespaces[0].namespaceId;
        } else {
            one = new string[](0);
        }
    }

    // // @uses <ns> парсер (по одной строке)
    function _extractUsesTags(string memory src) private returns (string[] memory out) {
        bytes memory b = bytes(src);
        string[] memory tmp = new string[](8);
        uint256 w;
        for (uint256 i = 0; i + 7 < b.length; i++) {
            if (b[i] == "/" && b[i + 1] == "/") {
                uint256 j = i;
                while (j < b.length && b[j] != "\n") j++;
                string memory line = string(_slice(b, i, j - i));
                if (line.contains("@uses")) {
                    string memory ns = _lastToken(line);
                    if (bytes(ns).length > 0) {
                        if (w == tmp.length) tmp = _grow(tmp, w + 8);
                        tmp[w++] = ns;
                    }
                }
                i = j;
            }
        }
        out = new string[](w);
        for (uint256 k = 0; k < w; k++) {
            out[k] = tmp[k];
        }
    }

    // ── маленькие утилки строк/байт ────────────────────────────────────────────
    function _basename(string memory p) private pure returns (string memory) {
        bytes memory b = bytes(p);
        int256 last = -1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == "/") last = int256(i);
        }
        if (last < 0) return p;
        uint256 s = uint256(last) + 1;
        bytes memory out = new bytes(b.length - s);
        for (uint256 j = 0; j < out.length; j++) {
            out[j] = b[s + j];
        }
        return string(out);
    }

    function _chopSuffix(string memory s, string memory suf) private pure returns (string memory) {
        bytes memory a = bytes(s);
        bytes memory b = bytes(suf);
        bytes memory out = new bytes(a.length - b.length);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = a[i];
        }
        return string(out);
    }

    function _endsWith(string memory s, string memory suf) private pure returns (bool) {
        bytes memory a = bytes(s);
        bytes memory b = bytes(suf);
        if (b.length > a.length) return false;
        for (uint256 i = 0; i < b.length; i++) {
            if (a[a.length - b.length + i] != b[i]) return false;
        }
        return true;
    }

    function _eq(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function _lastToken(string memory line) private pure returns (string memory) {
        bytes memory b = bytes(line);
        int256 e = int256(b.length) - 1;
        while (e >= 0 && (b[uint256(e)] == " " || b[uint256(e)] == "\t" || b[uint256(e)] == "\r")) e--;
        if (e < 0) return "";
        int256 s = e;
        while (s >= 0 && b[uint256(s)] != " ") s--;
        uint256 u = uint256(s + 1);
        bytes memory out = new bytes(uint256(e) - u + 1);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = b[u + i];
        }
        return string(out);
    }

    function _slice(bytes memory b, uint256 off, uint256 len) private pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = b[off + i];
        }
    }

    function _grow(string[] memory a, uint256 n) private pure returns (string[] memory b) {
        b = new string[](n);
        for (uint256 i = 0; i < a.length; i++) {
            b[i] = a[i];
        }
    }
}
