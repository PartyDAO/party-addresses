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
    Globals public globals = Globals(0x753e22d4e112a4D8b07dF9C4C578b116E3B48792);
    IZoraAuctionHouse public zoraAuctionHouse;
    AuctionCrowdfund public auctionCrowdfundImpl;
    RollingAuctionCrowdfund public rollingAuctionCrowdfundImpl;
    BuyCrowdfund public buyCrowdfundImpl;
    CollectionBuyCrowdfund public collectionBuyCrowdfundImpl;
    CollectionBatchBuyCrowdfund public collectionBatchBuyCrowdfundImpl;
    CrowdfundFactory public crowdfundFactory;
    Party public partyImpl = Party(payable(0xa3b4A7110b48FDFf1970D787D1cdCB9679176464));
    PartyFactory public partyFactory = PartyFactory(0xD1bc5eED9a90911caa76A8EA1f11C4Ea012976FC);
    ProposalExecutionEngine public proposalEngineImpl =
        ProposalExecutionEngine(0xD36689563949DDF6FF01d89b514f6BFc2b443dDE);
    TokenDistributor public tokenDistributor =
        TokenDistributor(0xE6F58B31344404E3479d81fB8f9dD592feB37965);
    RendererStorage public rendererStorage =
        RendererStorage(0x35c3bD81F7b3E2ddCE70f2b9f2cA94aC9992EE23);
    CrowdfundNFTRenderer public crowdfundNFTRenderer =
        CrowdfundNFTRenderer(0xe99446935bc7EF76f68cb0250f0E3e1C72371fB4);
    PartyNFTRenderer public partyNFTRenderer =
        PartyNFTRenderer(0xeEf9Cd7a71d31054f794545308cf0503708B2980);
    PartyHelpers public partyHelpers = PartyHelpers(0xd86eD6b7EBEe2B0924ba6FFe57B552c88f20c888);
    IGateKeeper public allowListGateKeeper =
        IGateKeeper(0xADcec7b4Db7969DFf00b9e5304be8e0d1261d6B4);
    IGateKeeper public tokenGateKeeper = IGateKeeper(0xa6FbcE9898A34a1e6db5Dab699B20b6bfEfda8c3);
    FoundationMarketWrapper public foundationMarketWrapper =
        FoundationMarketWrapper(0xc1bb865106E3c86B1804FfAaC7795F82c93c8ceF);
    NounsMarketWrapper public nounsMarketWrapper =
        NounsMarketWrapper(0x8633B1f69DA83067AB1Ec85a3411DE354fBF96cD);
    ZoraMarketWrapper public zoraMarketWrapper =
        ZoraMarketWrapper(0x969Ee9Ea5cebc042b689bff8e5497F96808353AE);
    PixeldroidConsoleFont public pixeldroidConsoleFont =
        PixeldroidConsoleFont(0x2262595460B14a91Cc8c175A8a6304637ef28669);

    function deploy(LibDeployConstants.DeployConstants memory deployConstants) public virtual {
        _switchDeployer(DeployerRole.Default);

        // DEPLOY_AUCTION_CF_IMPLEMENTATION
        console.log("");
        console.log("### AuctionCrowdfund crowdfund implementation");
        console.log("  Deploying - AuctionCrowdfund crowdfund implementation");
        _trackDeployerGasBefore();
        auctionCrowdfundImpl = new AuctionCrowdfund(globals);
        _trackDeployerGasAfter();
        console.log(
            "  Deployed - AuctionCrowdfund crowdfund implementation",
            address(auctionCrowdfundImpl)
        );

        // DEPLOY_BUY_CF_IMPLEMENTATION
        console.log("");
        console.log("### BuyCrowdfund crowdfund implementation");
        console.log("  Deploying - BuyCrowdfund crowdfund implementation");
        _trackDeployerGasBefore();
        buyCrowdfundImpl = new BuyCrowdfund(globals);
        _trackDeployerGasAfter();
        console.log(
            "  Deployed - BuyCrowdfund crowdfund implementation",
            address(buyCrowdfundImpl)
        );

        // DEPLOY_COLLECTION_BUY_CF_IMPLEMENTATION
        console.log("");
        console.log("### CollectionBuyCrowdfund crowdfund implementation");
        console.log("  Deploying - CollectionBuyCrowdfund crowdfund implementation");
        _trackDeployerGasBefore();
        collectionBuyCrowdfundImpl = new CollectionBuyCrowdfund(globals);
        _trackDeployerGasAfter();
        console.log(
            "  Deployed - CollectionBuyCrowdfund crowdfund implementation",
            address(collectionBuyCrowdfundImpl)
        );

        console.log("");
        console.log("  Globals - setting CollectionBuyCrowdfund crowdfund implementation address");
        globals.setAddress(
            LibGlobals.GLOBAL_COLLECTION_BUY_CF_IMPL,
            address(collectionBuyCrowdfundImpl)
        );
        console.log(
            "  Globals - successfully set CollectionBuyCrowdfund crowdfund implementation address",
            address(collectionBuyCrowdfundImpl)
        );

        // DEPLOY_COLLECTION_BATCH_BUY_CF_IMPLEMENTATION
        console.log("");
        console.log("### CollectionBatchBuyCrowdfund crowdfund implementation");
        console.log("  Deploying - CollectionBatchBuyCrowdfund crowdfund implementation");
        _trackDeployerGasBefore();
        collectionBatchBuyCrowdfundImpl = new CollectionBatchBuyCrowdfund(globals);
        _trackDeployerGasAfter();
        console.log(
            "  Deployed - CollectionBatchBuyCrowdfund crowdfund implementation",
            address(collectionBatchBuyCrowdfundImpl)
        );

        console.log("");
        console.log(
            "  Globals - setting CollectionBatchBuyCrowdfund crowdfund implementation address"
        );
        globals.setAddress(
            LibGlobals.GLOBAL_COLLECTION_BATCH_BUY_CF_IMPL,
            address(collectionBatchBuyCrowdfundImpl)
        );
        console.log(
            "  Globals - successfully set CollectionBatchBuyCrowdfund crowdfund implementation address",
            address(collectionBatchBuyCrowdfundImpl)
        );

        // DEPLOY_ROLLING_AUCTION_CF_IMPLEMENTATION
        console.log("");
        console.log("### RollingAuctionCrowdfund crowdfund implementation");
        console.log("  Deploying - RollingAuctionCrowdfund crowdfund implementation");
        rollingAuctionCrowdfundImpl = new RollingAuctionCrowdfund(globals);
        console.log(
            "  Deployed - RollingAuctionCrowdfund crowdfund implementation",
            address(rollingAuctionCrowdfundImpl)
        );

        console.log("");
        console.log("  Globals - setting RollingAuctionCrowdfund crowdfund implementation address");
        globals.setAddress(
            LibGlobals.GLOBAL_ROLLING_AUCTION_CF_IMPL,
            address(rollingAuctionCrowdfundImpl)
        );
        console.log(
            "  Globals - successfully set RollingAuctionCrowdfund crowdfund implementation address",
            address(rollingAuctionCrowdfundImpl)
        );

        // DEPLOY_PARTY_CROWDFUND_FACTORY
        console.log("");
        console.log("### CrowdfundFactory");
        console.log("  Deploying - CrowdfundFactory");
        _switchDeployer(DeployerRole.CrowdfundFactory);
        _trackDeployerGasBefore();
        crowdfundFactory = new CrowdfundFactory(globals);
        _trackDeployerGasAfter();
        console.log("  Deployed - CrowdfundFactory", address(crowdfundFactory));
        _switchDeployer(DeployerRole.Default);

        // Set Global values and transfer ownership
        {
            console.log("### Configure Globals");
            bytes[] memory multicallData = new bytes[](25);
            uint256 n = 0;
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (LibGlobals.GLOBAL_AUCTION_CF_IMPL, address(auctionCrowdfundImpl))
            );
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (LibGlobals.GLOBAL_BUY_CF_IMPL, address(buyCrowdfundImpl))
            );
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (LibGlobals.GLOBAL_COLLECTION_BUY_CF_IMPL, address(collectionBuyCrowdfundImpl))
            );
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (
                    LibGlobals.GLOBAL_COLLECTION_BATCH_BUY_CF_IMPL,
                    address(collectionBatchBuyCrowdfundImpl)
                )
            );
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (LibGlobals.GLOBAL_ROLLING_AUCTION_CF_IMPL, address(rollingAuctionCrowdfundImpl))
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

        AddressMapping[] memory addressMapping = new AddressMapping[](18);
        addressMapping[0] = AddressMapping("Globals", address(globals));
        addressMapping[1] = AddressMapping("TokenDistributor", address(tokenDistributor));
        addressMapping[2] = AddressMapping("ProposalExecutionEngine", address(proposalEngineImpl));
        addressMapping[3] = AddressMapping("Party", address(partyImpl));
        addressMapping[4] = AddressMapping("PartyFactory", address(partyFactory));
        addressMapping[5] = AddressMapping("AuctionCrowdfund", address(auctionCrowdfundImpl));
        addressMapping[6] = AddressMapping(
            "RollingAuctionCrowdfund",
            address(rollingAuctionCrowdfundImpl)
        );
        addressMapping[7] = AddressMapping("BuyCrowdfund", address(buyCrowdfundImpl));
        addressMapping[8] = AddressMapping(
            "CollectionBuyCrowdfund",
            address(collectionBuyCrowdfundImpl)
        );
        addressMapping[9] = AddressMapping(
            "CollectionBatchBuyCrowdfund",
            address(collectionBatchBuyCrowdfundImpl)
        );
        addressMapping[10] = AddressMapping("CrowdfundFactory", address(crowdfundFactory));
        addressMapping[11] = AddressMapping("CrowdfundNFTRenderer", address(crowdfundNFTRenderer));
        addressMapping[12] = AddressMapping("PartyNFTRenderer", address(partyNFTRenderer));
        addressMapping[13] = AddressMapping("PartyHelpers", address(partyHelpers));
        addressMapping[14] = AddressMapping("AllowListGateKeeper", address(allowListGateKeeper));
        addressMapping[15] = AddressMapping("TokenGateKeeper", address(tokenGateKeeper));
        addressMapping[16] = AddressMapping("RendererStorage", address(rendererStorage));
        addressMapping[17] = AddressMapping(
            "PixeldroidConsoleFont",
            address(pixeldroidConsoleFont)
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
        ffiCmd[1] = "./js/utils/output-abis.js";
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
