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
    Globals public globals;
    AuctionCrowdfund public auctionCrowdfund;
    RollingAuctionCrowdfund public rollingAuctionCrowdfund;
    BuyCrowdfund public buyCrowdfund;
    CollectionBuyCrowdfund public collectionBuyCrowdfund;
    CollectionBatchBuyCrowdfund public collectionBatchBuyCrowdfund;
    CrowdfundFactory public crowdfundFactory;

    function deploy(
        LibDeployConstants.DeployConstants memory deployConstants
    ) public virtual {
        _switchDeployer(DeployerRole.Default);

        // DEPLOY_AUCTION_CF_IMPLEMENTATION
        console.log("");
        console.log("### AuctionCrowdfund crowdfund implementation");
        console.log("  Deploying - AuctionCrowdfund crowdfund implementation");
        _trackDeployerGasBefore();
        auctionCrowdfund = new AuctionCrowdfund(globals);
        _trackDeployerGasAfter();
        console.log(
            "  Deployed - AuctionCrowdfund crowdfund implementation",
            address(auctionCrowdfund)
        );

        // DEPLOY_BUY_CF_IMPLEMENTATION
        console.log("");
        console.log("### BuyCrowdfund crowdfund implementation");
        console.log("  Deploying - BuyCrowdfund crowdfund implementation");
        _trackDeployerGasBefore();
        buyCrowdfund = new BuyCrowdfund(globals);
        _trackDeployerGasAfter();
        console.log(
            "  Deployed - BuyCrowdfund crowdfund implementation",
            address(buyCrowdfund)
        );

        // DEPLOY_COLLECTION_BUY_CF_IMPLEMENTATION
        console.log("");
        console.log("### CollectionBuyCrowdfund crowdfund implementation");
        console.log(
            "  Deploying - CollectionBuyCrowdfund crowdfund implementation"
        );
        _trackDeployerGasBefore();
        collectionBuyCrowdfund = new CollectionBuyCrowdfund(globals);
        _trackDeployerGasAfter();
        console.log(
            "  Deployed - CollectionBuyCrowdfund crowdfund implementation",
            address(collectionBuyCrowdfund)
        );

        console.log("");
        console.log(
            "  Globals - setting CollectionBuyCrowdfund crowdfund implementation address"
        );
        globals.setAddress(
            LibGlobals.GLOBAL_COLLECTION_BUY_CF_IMPL,
            address(collectionBuyCrowdfund)
        );
        console.log(
            "  Globals - successfully set CollectionBuyCrowdfund crowdfund implementation address",
            address(collectionBuyCrowdfund)
        );

        // DEPLOY_COLLECTION_BATCH_BUY_CF_IMPLEMENTATION
        console.log("");
        console.log("### CollectionBatchBuyCrowdfund crowdfund implementation");
        console.log(
            "  Deploying - CollectionBatchBuyCrowdfund crowdfund implementation"
        );
        _trackDeployerGasBefore();
        collectionBatchBuyCrowdfund = new CollectionBatchBuyCrowdfund(globals);
        _trackDeployerGasAfter();
        console.log(
            "  Deployed - CollectionBatchBuyCrowdfund crowdfund implementation",
            address(collectionBatchBuyCrowdfund)
        );

        console.log("");
        console.log(
            "  Globals - setting CollectionBatchBuyCrowdfund crowdfund implementation address"
        );
        globals.setAddress(
            LibGlobals.GLOBAL_COLLECTION_BATCH_BUY_CF_IMPL,
            address(collectionBatchBuyCrowdfund)
        );
        console.log(
            "  Globals - successfully set CollectionBatchBuyCrowdfund crowdfund implementation address",
            address(collectionBatchBuyCrowdfund)
        );

        // DEPLOY_ROLLING_AUCTION_CF_IMPLEMENTATION
        console.log("");
        console.log("### RollingAuctionCrowdfund crowdfund implementation");
        console.log(
            "  Deploying - RollingAuctionCrowdfund crowdfund implementation"
        );
        rollingAuctionCrowdfund = new RollingAuctionCrowdfund(globals);
        console.log(
            "  Deployed - RollingAuctionCrowdfund crowdfund implementation",
            address(rollingAuctionCrowdfund)
        );

        console.log("");
        console.log(
            "  Globals - setting RollingAuctionCrowdfund crowdfund implementation address"
        );
        globals.setAddress(
            LibGlobals.GLOBAL_ROLLING_AUCTION_CF_IMPL,
            address(rollingAuctionCrowdfund)
        );
        console.log(
            "  Globals - successfully set RollingAuctionCrowdfund crowdfund implementation address",
            address(rollingAuctionCrowdfund)
        );

        // DEPLOY_PARTY_CROWDFUND_FACTORY
        console.log("");
        console.log("### CrowdfundFactory");
        console.log("  Deploying - CrowdfundFactory");
        _trackDeployerGasBefore();
        crowdfundFactory = new CrowdfundFactory(globals);
        _trackDeployerGasAfter();
        console.log("  Deployed - CrowdfundFactory", address(crowdfundFactory));

        // Set Global values and transfer ownership
        {
            console.log("### Configure Globals");
            bytes[] memory multicallData = new bytes[](25);
            uint256 n = 0;
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (
                    LibGlobals.GLOBAL_AUCTION_CF_IMPL,
                    address(0xe0A0fcc467196Fda0A6cBDBbA73505aed1E31B31)
                )
            );
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (
                    LibGlobals.GLOBAL_BUY_CF_IMPL,
                    address(0x1471Fe2985810525f29412dc555c5A911403D144)
                )
            );
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (
                    LibGlobals.GLOBAL_COLLECTION_BUY_CF_IMPL,
                    address(0x0d5a70D1a340C737B74162A60fFCa0F94a4C9699)
                )
            );
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (LibGlobals.GLOBAL_COLLECTION_BATCH_BUY_CF_IMPL, address(0))
            );
            multicallData[n++] = abi.encodeCall(
                globals.setAddress,
                (LibGlobals.GLOBAL_ROLLING_AUCTION_CF_IMPL, address(0))
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

    function _getDeployerGasUsage(
        address deployer
    ) internal view returns (uint256) {
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

    function deploy(
        LibDeployConstants.DeployConstants memory deployConstants
    ) public override {
        Deploy.deploy(deployConstants);
        vm.stopBroadcast();

        AddressMapping[] memory addressMapping = new AddressMapping[](6);
        addressMapping[0] = AddressMapping(
            "AuctionCrowdfund",
            address(auctionCrowdfund)
        );
        addressMapping[1] = AddressMapping(
            "RollingAuctionCrowdfund",
            address(rollingAuctionCrowdfund)
        );
        addressMapping[2] = AddressMapping(
            "BuyCrowdfund",
            address(buyCrowdfund)
        );
        addressMapping[3] = AddressMapping(
            "CollectionBuyCrowdfund",
            address(collectionBuyCrowdfund)
        );
        addressMapping[4] = AddressMapping(
            "CollectionBatchBuyCrowdfund",
            address(collectionBatchBuyCrowdfund)
        );
        addressMapping[5] = AddressMapping(
            "CrowdfundFactory",
            address(crowdfundFactory)
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
