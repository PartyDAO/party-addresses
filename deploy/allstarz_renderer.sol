// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8;

import "forge-std/Script.sol";

import "../contracts/crowdfund/AuctionCrowdfund.sol";
import "../contracts/crowdfund/BuyCrowdfund.sol";
import "../contracts/crowdfund/CollectionBuyCrowdfund.sol";
import "../contracts/crowdfund/CollectionBatchBuyCrowdfund.sol";
import "../contracts/crowdfund/CrowdfundFactory.sol";
import "../contracts/distribution/TokenDistributor.sol";
import "../contracts/gatekeepers/AllowListGateKeeper.sol";
import "../contracts/gatekeepers/TokenGateKeeper.sol";
import "../contracts/gatekeepers/IGateKeeper.sol";
import "../contracts/globals/Globals.sol";
import "../contracts/globals/LibGlobals.sol";
import "../contracts/party/Party.sol";
import "../contracts/party/PartyFactory.sol";
import "../contracts/renderers/CrowdfundNFTRenderer.sol";
import "../contracts/renderers/PartyNFTRenderer.sol";
import "../contracts/renderers/MetadataRegistry.sol";
import "../contracts/renderers/fonts/PixeldroidConsoleFont.sol";
import "../contracts/proposals/ProposalExecutionEngine.sol";
import "../contracts/utils/PartyHelpers.sol";
import "../contracts/market-wrapper/FoundationMarketWrapper.sol";
import "../contracts/market-wrapper/NounsMarketWrapper.sol";
import "../contracts/market-wrapper/ZoraMarketWrapper.sol";
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
    PixeldroidConsoleFont public pixeldroidConsoleFont;
    RendererStorage public rendererStorage;

    CrowdfundNFTRenderer public crowdfundNFTRenderer;
    PartyNFTRenderer public partyNFTRenderer;
    MetadataRegistry public metadataRegistry;

    function deploy(LibDeployConstants.DeployConstants memory deployConstants)
        public
        virtual
    {
        _switchDeployer(DeployerRole.Default);

        // DEPLOY_CROWDFUND_NFT_RENDERER
        console.log("");
        console.log("### CrowdfundNFTRenderer");
        console.log("  Deploying - CrowdfundNFTRenderer");
        _trackDeployerGasBefore();
        crowdfundNFTRenderer = new CrowdfundNFTRenderer(
            globals,
            rendererStorage,
            IFont(address(pixeldroidConsoleFont))
        );
        _trackDeployerGasAfter();
        console.log(
            "  Deployed - CrowdfundNFTRenderer",
            address(crowdfundNFTRenderer)
        );

        // DEPLOY_PARTY_NFT_RENDERER
        console.log("");
        console.log("### PartyNFTRenderer");
        console.log("  Deploying - PartyNFTRenderer");
        _trackDeployerGasBefore();
        partyNFTRenderer = new PartyNFTRenderer(
            globals,
            rendererStorage,
            IFont(address(pixeldroidConsoleFont))
        );
        _trackDeployerGasAfter();
        console.log("  Deployed - PartyNFTRenderer", address(partyNFTRenderer));

        // DEPLOY_METADATA_REGISTRY
        address[] memory allowedHosts = new address[](4);
        allowedHosts[0] = 0xd66018102d639165ec15f7D0305f276835D955cE;
        allowedHosts[1] = 0x678e8bd1D8845399c8e3C1F946CB4309014456a5;
        allowedHosts[2] = 0x833b5e466f8b0ac36275938D5938AE146E9065B7;
        allowedHosts[3] = 0xba5f2ffb721648Ee6a6c51c512A258ec62f1D6af;

        console.log("");
        console.log("### MetadataRegistry");
        console.log("  Deploying - MetadataRegistry");
        _trackDeployerGasBefore();
        metadataRegistry = new MetadataRegistry(globals, allowedHosts);
        _trackDeployerGasAfter();
        console.log("  Deployed - MetadataRegistry", address(metadataRegistry));

        // Set Global values and transfer ownership
        {
            console.log("### Configure Globals");
            bytes[] memory multicallData = new bytes[](25);
            uint256 n = 0;
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (
                    LibGlobals.GLOBAL_CF_NFT_RENDER_IMPL,
                    address(crowdfundNFTRenderer)
                )
            );
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (
                    LibGlobals.GLOBAL_GOVERNANCE_NFT_RENDER_IMPL,
                    address(partyNFTRenderer)
                )
            );
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (LibGlobals.GLOBAL_METADATA_REGISTRY, address(metadataRegistry))
            );
            assembly {
                mstore(multicallData, n)
            }
            _trackDeployerGasBefore();
            globals.multicall(multicallData);
            _trackDeployerGasAfter();
        }
    }

    function getDeployer() external view returns (address) {
        return msg.sender;
    }

    function isTest() internal view returns (bool) {
        return address(this) == this.getDeployer();
    }

    function _getDeployerGasUsage(address deployer)
        internal
        view
        returns (uint256)
    {
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
        LibDeployConstants.DeployConstants memory dc = LibDeployConstants
            .mainnet();
        dc.partyDaoMultisig = multisig;
        deploy(dc);
    }

    function _switchDeployer(DeployerRole role) internal override {}
}

contract DeployScript is Script, Deploy {
    mapping(DeployerRole => address) internal _deployerByRole;
    address[] private _deployersUsed;

    function run() external {
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

    function deploy(LibDeployConstants.DeployConstants memory deployConstants)
        public
        override
    {
        Deploy.deploy(deployConstants);
        vm.stopBroadcast();

        AddressMapping[] memory addressMapping = new AddressMapping[](3);
        addressMapping[0] = AddressMapping(
            "CrowdfundNFTRenderer",
            address(crowdfundNFTRenderer)
        );
        addressMapping[1] = AddressMapping(
            "PartyNFTRenderer",
            address(partyNFTRenderer)
        );
        addressMapping[2] = AddressMapping(
            "MetadataRegistry",
            address(metadataRegistry)
        );

        console.log("");
        console.log("### Deployed addresses");
        string memory jsonRes = generateJSONString(addressMapping);
        console.log(jsonRes);

        writeAddressesToFile(deployConstants.networkName, jsonRes);
        writeAbisToFiles();
        console.log("");
        console.log("Ending deploy script.");
    }

    function generateJSONString(AddressMapping[] memory parts)
        private
        pure
        returns (string memory)
    {
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
        ffiCmd[1] = "./js/utils/output-abis.js";
        bytes memory ffiResp = vm.ffi(ffiCmd);

        bool wroteSuccessfully = keccak256(ffiResp) ==
            keccak256(hex"0000000000000000000000000000000000000001");
        if (!wroteSuccessfully) {
            revert("Could not write ABIs to file");
        }
        console.log("Successfully wrote ABIS to files");
    }

    function writeAddressesToFile(
        string memory networkName,
        string memory jsonRes
    ) private {
        string[] memory ffiCmd = new string[](4);
        ffiCmd[0] = "node";
        ffiCmd[1] = "./js/utils/save-json.js";
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
