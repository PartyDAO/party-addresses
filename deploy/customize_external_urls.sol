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
import "../contracts/crowdfund/ReraiseETHCrowdfund.sol";
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
    RendererStorage public rendererStorage;
    PartyNFTRenderer public partyNFTRenderer;
    PixeldroidConsoleFont public pixeldroidConsoleFont;

    function deploy(LibDeployConstants.DeployConstants memory deployConstants) public virtual {
        _switchDeployer(DeployerRole.Default);

        // DEPLOY_PARTY_NFT_RENDERER
        console.log("");
        console.log("### PartyNFTRenderer");
        console.log("  Deploying - PartyNFTRenderer");
        _trackDeployerGasBefore();
        partyNFTRenderer = new PartyNFTRenderer(
            globals,
            rendererStorage,
            IFont(address(pixeldroidConsoleFont)),
            deployConstants.oldTokenDistributor,
            deployConstants.baseExternalURL
        );
        _trackDeployerGasAfter();
        console.log("  Deployed - PartyNFTRenderer", address(partyNFTRenderer));

        // Set Global values and transfer ownership
        {
            console.log("### Configure Globals");
            bytes[] memory multicallData = new bytes[](999);
            uint256 n = 0;
            // The Globals commented out below were depreciated in 1.2; factories
            // can now choose the implementation address to deploy and no longer
            // deploy the latest implementation.
            //
            // See https://github.com/PartyDAO/party-migrations for
            // implementation addresses by release.

            // multicallData[n++] = abi.encodeCall(
            //     globals.setAddress,
            //     (LibGlobals.GLOBAL_PARTY_IMPL, address(party))
            // );
            // multicallData[n++] = abi.encodeCall(
            //     globals.setAddress,
            //     (LibGlobals.GLOBAL_CROWDFUND_FACTORY, address(crowdfundFactory))
            // );
            // multicallData[n++] = abi.encodeCall(
            //     globals.setAddress,
            //     (LibGlobals.GLOBAL_PARTY_FACTORY, address(partyFactory))
            // );
            // multicallData[n++] = abi.encodeCall(
            //     globals.setAddress,
            //     (LibGlobals.GLOBAL_AUCTION_CF_IMPL, address(auctionCrowdfund))
            // );
            // multicallData[n++] = abi.encodeCall(
            //     globals.setAddress,
            //     (LibGlobals.GLOBAL_BUY_CF_IMPL, address(buyCrowdfund))
            // );
            // multicallData[n++] = abi.encodeCall(
            //     globals.setAddress,
            //     (LibGlobals.GLOBAL_COLLECTION_BUY_CF_IMPL, address(collectionBuyCrowdfund))
            // );
            // multicallData[n++] = abi.encodeCall(
            //     globals.setAddress,
            //     (
            //         LibGlobals.GLOBAL_COLLECTION_BATCH_BUY_CF_IMPL,
            //         address(collectionBatchBuyCrowdfund)
            //     )
            // );
            // multicallData[n++] = abi.encodeCall(
            //     globals.setAddress,
            //     (LibGlobals.GLOBAL_INITIAL_ETH_CF_IMPL, address(initialETHCrowdfund))
            // );
            // multicallData[n++] = abi.encodeCall(
            //     globals.setAddress,
            //     (LibGlobals.GLOBAL_RERAISE_ETH_CF_IMPL, address(reraiseETHCrowdfund))
            // );
            // multicallData[n++] = abi.encodeCall(
            //     globals.setAddress,
            //     (LibGlobals.GLOBAL_ROLLING_AUCTION_CF_IMPL, address(rollingAuctionCrowdfund))
            // );
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (LibGlobals.GLOBAL_GOVERNANCE_NFT_RENDER_IMPL, address(partyNFTRenderer))
            );
            // transfer ownership of Globals to multisig
            if (this.getDeployer() != deployConstants.partyDaoMultisig) {
                multicallData[n++] = abi.encodeCall(
                    globals.transferMultiSig,
                    (deployConstants.partyDaoMultisig)
                );
            }
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

        AddressMapping[] memory addressMapping = new AddressMapping[](1);
        addressMapping[0] = AddressMapping("PartyNFTRenderer", address(partyNFTRenderer));

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
