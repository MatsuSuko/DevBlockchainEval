// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract VoteNFT is ERC721 {
    uint256 private _tokenIdCounter;
    address public votingContract;
    
    constructor() ERC721("VoteNFT", "VNFT") {
        votingContract = msg.sender;
    }
    
    function mint(address voter) external {
        require(msg.sender == votingContract, "Only voting contract");
        _safeMint(voter, _tokenIdCounter);
        _tokenIdCounter++;
    }
    
    function hasVoted(address voter) external view returns (bool) {
        return balanceOf(voter) > 0;
    }
}

contract SimpleVotingSystem is Ownable, AccessControl {
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
    
    enum WorkflowStatus {
        REGISTER_CANDIDATES,
        FOUND_CANDIDATES,
        VOTE,
        COMPLETED
    }
    WorkflowStatus public currentStatus;
    
    struct Candidate {
        uint id;
        string name;
        uint voteCount;
        uint fundsReceived;
    }

    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public voters;
    uint[] private candidateIds;
    
    VoteNFT public voteNFT;
    uint256 public voteStartTime;
    
    uint256 public winnerId;
    bool public winnerDeclared;

    constructor() Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        currentStatus = WorkflowStatus.REGISTER_CANDIDATES;
        voteNFT = new VoteNFT();
    }

    function addCandidate(string memory _name) public onlyOwner {
        require(currentStatus == WorkflowStatus.REGISTER_CANDIDATES, "Wrong status");
        require(bytes(_name).length > 0, "Candidate name cannot be empty");
        uint candidateId = candidateIds.length + 1;
        candidates[candidateId] = Candidate(candidateId, _name, 0, 0);
        candidateIds.push(candidateId);
    }
    
    function changeWorkflowStatus(WorkflowStatus _newStatus) external onlyOwner {
        require(uint(_newStatus) == uint(currentStatus) + 1, "Must follow order");
        currentStatus = _newStatus;
        
        if (_newStatus == WorkflowStatus.VOTE) {
            voteStartTime = block.timestamp;
        }
    }
    
    function fundCandidate(uint _candidateId) external payable onlyRole(FOUNDER_ROLE) {
        require(currentStatus == WorkflowStatus.FOUND_CANDIDATES, "Wrong status");
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid ID");
        require(msg.value > 0, "Send ETH");
        
        candidates[_candidateId].fundsReceived += msg.value;
    }

    function vote(uint _candidateId) public {
    require(currentStatus == WorkflowStatus.VOTE, "Wrong status");
    require(block.timestamp >= voteStartTime + 1 hours, "Wait 1 hour");
    require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
    require(!voteNFT.hasVoted(msg.sender), "Already have NFT");

    voters[msg.sender] = true;
    candidates[_candidateId].voteCount += 1;
    voteNFT.mint(msg.sender);
}
    
    function declareWinner() external onlyOwner returns (uint) {
        require(currentStatus == WorkflowStatus.VOTE, "Wrong status");
        require(!winnerDeclared, "Already declared");
        
        uint maxVotes = 0;
        uint winningId = 0;
        
        for (uint i = 0; i < candidateIds.length; i++) {
            uint candidateId = candidateIds[i];
            if (candidates[candidateId].voteCount > maxVotes) {
                maxVotes = candidates[candidateId].voteCount;
                winningId = candidateId;
            }
        }
        
        require(winningId > 0, "No winner");
        winnerId = winningId;
        winnerDeclared = true;
        return winningId;
    }
    
    function completeVoting() external onlyOwner {
        require(winnerDeclared, "Declare winner first");
        currentStatus = WorkflowStatus.COMPLETED;
    }

    function getTotalVotes(uint _candidateId) public view returns (uint) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId].voteCount;
    }

    function getCandidatesCount() public view returns (uint) {
        return candidateIds.length;
    }

    function getCandidate(uint _candidateId) public view returns (Candidate memory) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId];
    }
    
    function getWinner() external view returns (uint, string memory, uint) {
        require(winnerDeclared, "No winner yet");
        Candidate memory winner = candidates[winnerId];
        return (winner.id, winner.name, winner.voteCount);
    }
    
    function grantFounderRole(address account) external onlyOwner {
        grantRole(FOUNDER_ROLE, account);
    }
    
    function grantWithdrawerRole(address account) external onlyOwner {
        grantRole(WITHDRAWER_ROLE, account);
    }

    function withdrawFunds() external onlyRole(WITHDRAWER_ROLE) {
        require(currentStatus == WorkflowStatus.COMPLETED, "Wrong status");
        uint balance = address(this).balance;
        require(balance > 0, "No funds");
        
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
    }
    
    receive() external payable {}
}