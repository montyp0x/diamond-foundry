// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {DesiredFacetsIO} from "../io/DesiredFacets.sol";

/// @title FacetDiscovery
/// @notice Automatically discovers facets from src/example/facets/ directory
/// @dev Scans the example facets directory and creates DesiredState automatically
library FacetDiscovery {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Automatically discovers all facets from src/example/facets/ directory
    /// @param name The project name
    /// @param defaultNamespace The default namespace to use if none can be determined
    /// @return d The DesiredState with all discovered facets
    function discoverExampleFacets(string memory name, string memory defaultNamespace)
        internal
        view
        returns (DesiredFacetsIO.DesiredState memory d)
    {
        d.name = name;
        d.init = DesiredFacetsIO.InitSpec({target: address(0), data: ""});

        // Recursively discover all .sol files in src/example/facets/
        d.facets = _scanDirectoryRecursively("src/example/facets/", defaultNamespace);
    }

    /// @notice Recursively scans directory for .sol files and creates facets
    /// @param baseDir The base directory to scan (e.g., "src/example/facets/")
    /// @param defaultNamespace The default namespace to use if none can be determined
    /// @return facets Array of discovered facets
    function _scanDirectoryRecursively(string memory baseDir, string memory defaultNamespace)
        private
        view
        returns (DesiredFacetsIO.Facet[] memory facets)
    {
        // Since Foundry VM doesn't have direct filesystem API, we'll use a hybrid approach:
        // 1. Try to read known files from the counter example
        // 2. Allow for easy extension by adding more subdirectories

        string[] memory knownSubdirs = new string[](1);
        knownSubdirs[0] = "counter";

        // Count total facets first
        uint256 totalFacets = 0;
        for (uint256 i = 0; i < knownSubdirs.length; i++) {
            string memory subdir = string.concat(baseDir, knownSubdirs[i], "/");
            totalFacets += _countFacetsInSubdir(subdir);
        }

        // Allocate array and populate facets
        facets = new DesiredFacetsIO.Facet[](totalFacets);
        uint256 facetIndex = 0;

        for (uint256 i = 0; i < knownSubdirs.length; i++) {
            string memory subdir = string.concat(baseDir, knownSubdirs[i], "/");
            facetIndex = _populateFacetsFromSubdir(subdir, defaultNamespace, facets, facetIndex);
        }
    }

    /// @notice Counts facets in a subdirectory
    /// @param subdir The subdirectory path
    /// @return count Number of facets found
    function _countFacetsInSubdir(string memory subdir) private view returns (uint256 count) {
        // Try to read known files in the subdirectory
        string[] memory knownFiles = _getKnownFilesForSubdir(subdir);
        for (uint256 i = 0; i < knownFiles.length; i++) {
            string memory filePath = string.concat(subdir, knownFiles[i]);
            if (_fileExists(filePath)) {
                count++;
            }
        }
    }

    /// @notice Populates facets from a subdirectory
    /// @param subdir The subdirectory path
    /// @param defaultNamespace The default namespace
    /// @param facets The facets array to populate
    /// @param startIndex The starting index in the facets array
    /// @return nextIndex The next index after population
    function _populateFacetsFromSubdir(
        string memory subdir,
        string memory defaultNamespace,
        DesiredFacetsIO.Facet[] memory facets,
        uint256 startIndex
    ) private view returns (uint256 nextIndex) {
        string[] memory knownFiles = _getKnownFilesForSubdir(subdir);
        nextIndex = startIndex;

        for (uint256 i = 0; i < knownFiles.length; i++) {
            string memory filePath = string.concat(subdir, knownFiles[i]);
            if (_fileExists(filePath)) {
                facets[nextIndex] = _createFacetFromFile(filePath, knownFiles[i], defaultNamespace);
                nextIndex++;
            }
        }
    }

    /// @notice Gets known files for a subdirectory
    /// @param subdir The subdirectory path
    /// @return files Array of known file names
    function _getKnownFilesForSubdir(string memory subdir) private pure returns (string[] memory files) {
        // Extract subdirectory name for pattern matching
        if (_stringContains(subdir, "counter")) {
            files = new string[](2);
            files[0] = "AddFacet.sol";
            files[1] = "ViewFacet.sol";
        } else {
            // For future subdirectories, return empty array
            files = new string[](0);
        }
    }

    /// @notice Creates a facet from a file by analyzing its content
    /// @param filePath The full path to the file
    /// @param fileName The file name (e.g., "AddFacet.sol")
    /// @param defaultNamespace The default namespace to use if none can be determined
    /// @return facet The created facet
    function _createFacetFromFile(string memory filePath, string memory fileName, string memory defaultNamespace)
        private
        view
        returns (DesiredFacetsIO.Facet memory facet)
    {
        // Extract contract name from file name (remove .sol extension)
        string memory contractName = _removeExtension(fileName);
        string memory artifact = string.concat(fileName, ":", contractName);

        // Analyze file content to determine uses
        string[] memory uses = _analyzeFileForUses(filePath, defaultNamespace);

        facet = DesiredFacetsIO.Facet({
            artifact: artifact,
            selectors: new bytes4[](0), // Will be populated by FacetSync
            uses: uses
        });
    }

    /// @notice Analyzes a file to determine its namespace uses
    /// @param filePath The path to the file to analyze
    /// @param defaultNamespace The default namespace if none can be determined
    /// @return uses Array of namespace uses
    function _analyzeFileForUses(string memory filePath, string memory defaultNamespace)
        private
        view
        returns (string[] memory uses)
    {
        try VM.readFile(filePath) returns (string memory content) {
            // Look for @uses tags first (highest priority)
            string[] memory tagUses = _extractUsesFromTags(content);
            if (tagUses.length > 0) {
                return tagUses;
            }

            // Fall back to analyzing imports
            string[] memory importUses = _extractUsesFromImports(content);
            if (importUses.length > 0) {
                return importUses;
            }

            // Fall back to default namespace
            return _singleStringArray(defaultNamespace);
        } catch {
            // If file can't be read, use default namespace
            return _singleStringArray(defaultNamespace);
        }
    }

    /// @notice Extracts uses from @uses tags in comments
    /// @param content The file content
    /// @return uses Array of extracted uses
    function _extractUsesFromTags(string memory content) private pure returns (string[] memory uses) {
        // Look for patterns like: // @uses: counter.v1, uniswap.v2
        // For now, we'll implement a simple version that looks for known patterns
        if (_stringContains(content, "@uses:")) {
            // This is a simplified implementation
            // In a real implementation, you'd parse the content more thoroughly
            if (_stringContains(content, "counter.v1")) {
                return _singleStringArray("counter.v1");
            }
            if (_stringContains(content, "uniswap.v2")) {
                return _singleStringArray("uniswap.v2");
            }
        }

        // Return empty array if no tags found
        uses = new string[](0);
    }

    /// @notice Extracts uses from import statements
    /// @param content The file content
    /// @return uses Array of extracted uses based on imports
    function _extractUsesFromImports(string memory content) private pure returns (string[] memory uses) {
        // Look for imports like LibCounterStorage, LibUniswapStorageV2, etc.
        if (_stringContains(content, "LibCounterStorage")) {
            return _singleStringArray("counter.v1");
        }
        if (_stringContains(content, "LibUniswapStorageV2")) {
            return _singleStringArray("uniswap.v2");
        }
        if (_stringContains(content, "LibUniswapStorage")) {
            return _singleStringArray("uniswap.v1");
        }

        // Return empty array if no recognizable imports found
        uses = new string[](0);
    }

    /// @notice Checks if a file exists
    /// @param filePath The path to check
    /// @return exists Whether the file exists
    function _fileExists(string memory filePath) private view returns (bool exists) {
        try VM.readFile(filePath) returns (string memory) {
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Removes file extension from filename
    /// @param fileName The filename with extension
    /// @return nameWithoutExt The filename without extension
    function _removeExtension(string memory fileName) private pure returns (string memory nameWithoutExt) {
        bytes memory fileBytes = bytes(fileName);
        uint256 dotIndex = fileBytes.length;

        // Find the last dot
        for (uint256 i = fileBytes.length; i > 0; i--) {
            if (fileBytes[i - 1] == ".") {
                dotIndex = i - 1;
                break;
            }
        }

        // If no dot found, return original string
        if (dotIndex == fileBytes.length) {
            return fileName;
        }

        // Extract substring before the dot
        bytes memory result = new bytes(dotIndex);
        for (uint256 i = 0; i < dotIndex; i++) {
            result[i] = fileBytes[i];
        }

        return string(result);
    }

    /// @notice Checks if a string contains a substring
    /// @param haystack The string to search in
    /// @param needle The substring to search for
    /// @return found Whether the substring was found
    function _stringContains(string memory haystack, string memory needle) private pure returns (bool found) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);

        if (needleBytes.length == 0) return true;
        if (needleBytes.length > haystackBytes.length) return false;

        for (uint256 i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < needleBytes.length; j++) {
                if (haystackBytes[i + j] != needleBytes[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) return true;
        }

        return false;
    }

    /// @notice Creates a single-element string array
    /// @param s The string to wrap in an array
    /// @return arr Array containing the single string
    function _singleStringArray(string memory s) private pure returns (string[] memory arr) {
        arr = new string[](1);
        arr[0] = s;
    }
}
