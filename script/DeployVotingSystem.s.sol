// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {SimpleVotingSystem} from "../src/SimplevotingSystem.sol";

contract DeployVotingSystem is Script {
    function run() external returns (SimpleVotingSystem) {
        vm.startBroadcast();
        
        SimpleVotingSystem votingSystem = new SimpleVotingSystem();
        
        console.log("VotingSystem deployed at:", address(votingSystem));
        console.log("VoteNFT deployed at:", address(votingSystem.voteNFT()));
        
        vm.stopBroadcast();
        
        return votingSystem;
    }
}