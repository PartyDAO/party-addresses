// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8;

import "forge-std/Script.sol";

import "../contracts/crowdfund/AuctionCrowdfund.sol";
import "../contracts/crowdfund/BuyCrowdfund.sol";
import "../contracts/crowdfund/CollectionBuyCrowdfund.sol";
import "../contracts/crowdfund/CollectionBatchBuyCrowdfund.sol";
import "../contracts/operators/CollectionBatchBuyOperator.sol";
import "../contracts/operators/ERC20SwapOperator.sol";
import "../contracts/crowdfund/InitialETHCrowdfund.sol";
import "../contracts/crowdfund/CrowdfundFactory.sol";
import "../contracts/distribution/TokenDistributor.sol";
import "../contracts/gatekeepers/AllowListGateKeeper.sol";
import "../contracts/gatekeepers/TokenGateKeeper.sol";
import "../contracts/gatekeepers/IGateKeeper.sol";
import "../contracts/globals/Globals.sol";
import "../contracts/globals/LibGlobals.sol";
import "../contracts/party/Party.sol";
import "../contracts/party/PartyFactory.sol";
import "../contracts/renderers/MetadataRegistry.sol";
import "../contracts/renderers/MetadataProvider.sol";
import "../contracts/renderers/CrowdfundNFTRenderer.sol";
import "../contracts/renderers/PartyNFTRenderer.sol";
import "../contracts/renderers/fonts/PixeldroidConsoleFont.sol";
import "../contracts/proposals/ProposalExecutionEngine.sol";
import "../contracts/utils/PartyHelpers.sol";
import "../contracts/market-wrapper/NounsMarketWrapper.sol";
import { AtomicManualParty } from "../contracts/crowdfund/AtomicManualParty.sol";
import { ContributionRouter } from "../contracts/crowdfund/ContributionRouter.sol";
import { AddPartyCardsAuthority } from "../contracts/authorities/AddPartyCardsAuthority.sol";
import { SellPartyCardsAuthority } from "../contracts/authorities/SellPartyCardsAuthority.sol";
import { SSTORE2MetadataProvider } from "../contracts/renderers/SSTORE2MetadataProvider.sol";
import { BasicMetadataProvider } from "../contracts/renderers/BasicMetadataProvider.sol";
import { OffChainSignatureValidator } from "../contracts/signature-validators/OffChainSignatureValidator.sol";
import { BondingCurveAuthority } from "../contracts/authorities/BondingCurveAuthority.sol";
import "./LibDeployConstants.sol";

abstract contract Deploy {
    enum DeployerRole {
        Default,
        PartyFactory,
        CrowdfundFactory,
        TokenDistributor
    }

    struct AddressMapping {
        string key;
        address value;
    }

    mapping(address => uint256) private _deployerGasBefore;
    mapping(address => uint256) private _deployerGasUsage;

    // temporary variables to store deployed contract addresses
    Globals public globals;
    InitialETHCrowdfund public initialETHCrowdfund;
    CrowdfundFactory public crowdfundFactory;
    Party public party;
    PartyFactory public partyFactory;
    AtomicManualParty public atomicManualParty;
    BondingCurveAuthority public bondingCurveAuthority;

    function deploy(LibDeployConstants.DeployConstants memory deployConstants) public virtual {
        _switchDeployer(DeployerRole.Default);

        // DEPLOY_PARTY_IMPLEMENTATION
        console.log("");
        console.log("### Party implementation");
        console.log("  Deploying - Party implementation");
        _trackDeployerGasBefore();
        party = new Party(globals);
        _trackDeployerGasAfter();
        console.log("  Deployed - Party implementation", address(party));

        // DEPLOY_PARTY_FACTORY
        console.log("");
        console.log("### PartyFactory");
        console.log("  Deploying - PartyFactory");
        _switchDeployer(DeployerRole.PartyFactory);
        _trackDeployerGasBefore();
        partyFactory = new PartyFactory(globals);
        _trackDeployerGasAfter();
        console.log("  Deployed - PartyFactory", address(partyFactory));
        _switchDeployer(DeployerRole.Default);

        // DEPLOY_INITIAL_ETH_CF_IMPLEMENTATION
        console.log("");
        console.log("### InitialETHCrowdfund crowdfund implementation");
        console.log("  Deploying - InitialETHCrowdfund crowdfund implementation");
        _trackDeployerGasBefore();
        initialETHCrowdfund = new InitialETHCrowdfund(globals);
        _trackDeployerGasAfter();
        console.log(
            "  Deployed - InitialETHCrowdfund crowdfund implementation",
            address(initialETHCrowdfund)
        );

        // DEPLOY_PARTY_CROWDFUND_FACTORY
        console.log("");
        console.log("### CrowdfundFactory");
        console.log("  Deploying - CrowdfundFactory");
        _switchDeployer(DeployerRole.CrowdfundFactory);
        _trackDeployerGasBefore();
        crowdfundFactory = new CrowdfundFactory();
        _trackDeployerGasAfter();
        console.log("  Deployed - CrowdfundFactory", address(crowdfundFactory));
        _switchDeployer(DeployerRole.Default);

        // Deploy_BONDING_CURVE_AUTHORITY
        console.log("");
        console.log("### BondingCurveAuthority");
        console.log("  Deploying - BondingCurveAuthority");
        _trackDeployerGasBefore();
        bondingCurveAuthority = new BondingCurveAuthority(
            payable(deployConstants.partyDaoMultisig),
            250,
            1000,
            250
        );
        _trackDeployerGasAfter();
        console.log("  Deployed - BondingCurveAuthority", address(bondingCurveAuthority));

        console.log("");
        console.log("  Deploying - AtomicManualParty");
        _trackDeployerGasBefore();
        atomicManualParty = new AtomicManualParty(partyFactory);
        _trackDeployerGasAfter();
        console.log("  Deployed - AtomicManualParty", address(atomicManualParty));
    }

    function getDeployer() external view returns (address) {
        return msg.sender;
    }

    function isTest() internal view returns (bool) {
        return address(this) == this.getDeployer();
    }

    function _getDeployerGasUsage(address deployer) internal view returns (uint256) {
        return _deployerGasUsage[deployer];
    }

    function _trackDeployerGasBefore() private {
        address deployer = this.getDeployer();
        _deployerGasBefore[deployer] = gasleft();
    }

    function _trackDeployerGasAfter() private {
        address deployer = this.getDeployer();
        uint256 usage = _deployerGasBefore[deployer] - gasleft();
        _deployerGasUsage[deployer] += usage;
    }

    function _switchDeployer(DeployerRole role) internal virtual;
}

contract DeployFork is Deploy {
    function deployMainnetFork(address multisig) public {
        LibDeployConstants.DeployConstants memory dc = LibDeployConstants.mainnet();
        dc.partyDaoMultisig = multisig;
        deploy(dc);
    }

    function _switchDeployer(DeployerRole role) internal override {}
}

contract DeployScript is Script, Deploy {
    mapping(DeployerRole => address) internal _deployerByRole;
    address[] private _deployersUsed;

    function run() external {
        vm.startBroadcast();

        _run();

        {
            uint256 n = _deployersUsed.length;
            console.log("");
            for (uint256 i; i < n; ++i) {
                address deployer = _deployersUsed[i];
                uint256 gasUsed = _getDeployerGasUsage(deployer);
                console.log("deployer:", deployer);
                console.log("cost:", gasUsed * tx.gasprice);
                console.log("gas:", gasUsed);
                if (i + 1 < n) {
                    console.log("");
                }
            }
        }
    }

    function _run() internal virtual {}

    function _switchDeployer(DeployerRole role) internal override {
        vm.stopBroadcast();
        {
            address deployer_ = _deployerByRole[role];
            if (deployer_ != address(0)) {
                vm.startBroadcast(deployer_);
            } else {
                vm.startBroadcast();
            }
        }
        address deployer = this.getDeployer();
        console.log("Switched deployer to", deployer);
        for (uint256 i; i < _deployersUsed.length; ++i) {
            if (_deployersUsed[i] == deployer) {
                return;
            }
        }
        _deployersUsed.push(deployer);
        if (vm.envUint("DRY_RUN") == 1) {
            vm.deal(deployer, 100e18);
        }
    }

    function deploy(LibDeployConstants.DeployConstants memory deployConstants) public override {
        Deploy.deploy(deployConstants);
        vm.stopBroadcast();

        AddressMapping[] memory addressMapping = new AddressMapping[](6);
        addressMapping[0] = AddressMapping("PartyFactory", address(partyFactory));
        addressMapping[1] = AddressMapping("Party", address(party));
        addressMapping[2] = AddressMapping("InitialETHCrowdfund", address(initialETHCrowdfund));
        addressMapping[3] = AddressMapping("CrowdfundFactory", address(crowdfundFactory));
        addressMapping[4] = AddressMapping("AtomicManualParty", address(atomicManualParty));
        addressMapping[5] = AddressMapping("BondingCurveAuthority", address(bondingCurveAuthority));

        console.log("");
        console.log("### Deployed addresses");
        string memory jsonRes = generateJSONString(addressMapping);
        console.log(jsonRes);

        writeAddressesToFile(deployConstants.networkName, jsonRes);
        writeAbisToFiles();
        console.log("");
        console.log("Ending deploy script.");
    }

    function generateJSONString(
        AddressMapping[] memory parts
    ) private pure returns (string memory) {
        string memory vals = "";
        for (uint256 i; i < parts.length; ++i) {
            string memory newValue = string.concat(
                '"',
                parts[i].key,
                '": "',
                Strings.toHexString(parts[i].value),
                '"'
            );
            if (i != parts.length - 1) {
                newValue = string.concat(newValue, ",");
            }
            vals = string.concat(vals, newValue);
        }
        return string.concat("{", vals, "}");
    }

    function writeAbisToFiles() private {
        string[] memory ffiCmd = new string[](2);
        ffiCmd[0] = "node";
        ffiCmd[1] = "./js/output-abis.js";
        bytes memory ffiResp = vm.ffi(ffiCmd);

        bool wroteSuccessfully = keccak256(ffiResp) ==
            keccak256(hex"0000000000000000000000000000000000000001");
        if (!wroteSuccessfully) {
            revert("Could not write ABIs to file");
        }
        console.log("Successfully wrote ABIS to files");
    }

    function writeAddressesToFile(string memory networkName, string memory jsonRes) private {
        string[] memory ffiCmd = new string[](4);
        ffiCmd[0] = "node";
        ffiCmd[1] = "./js/save-json.js";
        ffiCmd[2] = networkName;
        ffiCmd[3] = jsonRes;
        bytes memory ffiResp = vm.ffi(ffiCmd);

        bool wroteSuccessfully = keccak256(ffiResp) ==
            keccak256(hex"0000000000000000000000000000000000000001");
        if (!wroteSuccessfully) {
            revert("Could not write to file");
        }
        console.log("Successfully wrote to file");
    }
}
