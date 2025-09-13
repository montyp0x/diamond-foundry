// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IDiamondLoupe} from "../../interfaces/diamond/IDiamondLoupe.sol";
import {IERC173} from "../../interfaces/diamond/IERC173.sol";
import {IDiamondCut} from "../../interfaces/diamond/IDiamondCut.sol";
import {IDiamond} from "../../interfaces/diamond/IDiamond.sol";
import {DiamondArgs} from "../../Diamond.sol";

/// @title DiamondDeployer
/// @notice Deploys the core Diamond and provides helpers for standard facets (Cut/Loupe/Ownership).
/// @dev Relies on Foundry cheatcodes (scripts/tests). Artifact ids must match this repo layout.
library DiamondDeployer {
    // Foundry Vm handle
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // Artifacts in this library (adjust if your layout changes)
    string internal constant ARTIFACT_DIAMOND            = "Diamond.sol:Diamond";
    string internal constant ARTIFACT_DIAMOND_CUT_FACET  = "DiamondCutFacet.sol:DiamondCutFacet";
    string internal constant ARTIFACT_DIAMOND_LOUPE      = "DiamondLoupeFacet.sol:DiamondLoupeFacet";
    string internal constant ARTIFACT_OWNERSHIP_FACET    = "OwnershipFacet.sol:OwnershipFacet";

    /// @notice Deployed core component addresses.
    struct Core {
        address diamond;
        address cutFacet;
        address loupeFacet;
        address ownershipFacet;
    }

    /// @notice Deploy all core facets (Cut, Ownership, Loupe) and Diamond with the standard EIP-2535 constructor.
    function deployCore(address owner) internal returns (Core memory c) {
        // 1) Deploy all core facets
        address cut = VM.deployCode(ARTIFACT_DIAMOND_CUT_FACET);
        address ownership = VM.deployCode(ARTIFACT_OWNERSHIP_FACET);
        address loupe = VM.deployCode(ARTIFACT_DIAMOND_LOUPE);

        // 2) Prepare FacetCuts for all core facets (they need to be added during deployment)
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](3);
        
        // DiamondCutFacet
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = IDiamondCut.diamondCut.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: cut,
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });
        
        // OwnershipFacet
        bytes4[] memory ownerSelectors = ownershipSelectors();
        diamondCut[1] = IDiamond.FacetCut({
            facetAddress: ownership,
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ownerSelectors
        });
        
        // DiamondLoupeFacet
        bytes4[] memory loupeSels = loupeSelectors();
        diamondCut[2] = IDiamond.FacetCut({
            facetAddress: loupe,
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: loupeSels
        });

        // 3) Prepare Diamond constructor arguments
        DiamondArgs memory args = DiamondArgs({
            owner: owner,
            init: address(0),
            initCalldata: ""
        });

        // 4) Deploy Diamond with proper EIP-2535 constructor
        bytes memory ctor = abi.encode(diamondCut, args);
        address diamond = VM.deployCode(ARTIFACT_DIAMOND, ctor);

        c.diamond = diamond;
        c.cutFacet = cut;
        c.loupeFacet = loupe;
        c.ownershipFacet = ownership;
    }

    /// @notice Deploy the loupe facet (no constructors assumed).
    function deployLoupeFacet() internal returns (address loupe) {
        loupe = VM.deployCode(ARTIFACT_DIAMOND_LOUPE);
    }

    /// @notice Canonical selectors for the IDiamondLoupe interface.
    function loupeSelectors() internal pure returns (bytes4[] memory sel) {
        sel = new bytes4[](4);
        sel[0] = IDiamondLoupe.facets.selector;
        sel[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        sel[2] = IDiamondLoupe.facetAddresses.selector;
        sel[3] = IDiamondLoupe.facetAddress.selector;
    }

    /// @notice Return the artifact id (path:Name) for the loupe facet shipped in this lib.
    function loupeArtifact() internal pure returns (string memory) {
        return ARTIFACT_DIAMOND_LOUPE;
    }

    /// @notice Canonical selectors for the IERC173 ownership interface.
    function ownershipSelectors() internal pure returns (bytes4[] memory sel) {
        sel = new bytes4[](2);
        sel[0] = IERC173.owner.selector;
        sel[1] = IERC173.transferOwnership.selector;
    }

    /// @notice Return the artifact id (path:Name) for the ownership facet shipped in this lib.
    function ownershipArtifact() internal pure returns (string memory) {
        return ARTIFACT_OWNERSHIP_FACET;
    }

}
