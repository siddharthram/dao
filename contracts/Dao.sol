// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;


// given an address and a token type, return the balance
// this is a copy of the contract in opensea..
// have a look at https://mumbai.polygonscan.com/address/0x2953399124f0cbb46d2cbacd8a89cf0599974963#readContract e.g.
// This allows us to verify that there are valid tokens present 
// at that address

interface IdaoContract {
    function balanceOf(address, uint256) external view returns (uint256);
}
contract Dao {

   // owner of the contract - anyone can view who the owner of the smart contract is
  address public owner;
  // each proposal as a unique ID
    uint256 nextProposal;
    // who is allowed to vote?
    uint256[] public validTokens;
    IdaoContract daoContract;

// run at deployment of smart contract (only once)

// msg is a 'global' in EVM
constructor() {
    owner = msg.sender;
    nextProposal = 1;// the first proposal #
    // This points to the smartcontract in opensea that gives us the balance - see
    //https://mumbai.polygonscan.com/address/0x2953399124f0cbb46d2cbacd8a89cf0599974963 or look at 'details' in an opensea item

    daoContract =  IdaoContract(0x2953399124F0cBB46d2CbACD8A89cF0599974963);
    // make sure that the wallet has this token  before being allowed to bid on the contract
    validTokens = [48224081352976844695306393642189880612767604058366108554195382259535149268993];
}

struct proposal {
    uint256 id; // nextproposal id
    bool exists; // does this proposal exist? helpful for require statements
    string description; // 
    uint deadLine; // deadline to cast votes.. block # e.g block+100
    uint256 votesUp; // 
    uint256 votesDown; //
    address[] canVote; // which wallet address can vote? must have valid NFT's at this address
    uint256 maxVotes; // lenght of address array
    mapping (address => bool) voteStatus; // voting status - given an address, get voting status. can vote multiple times
    bool countConducted; // have the votes been tallied
    bool passed; // result of voting
}


mapping(uint256 => proposal) public Proposals; // maps a proposal id to a proposal struct

//
// EVENTS
// what events do we emit? This can be consumed by the UI
//


event proposalCreated (
    uint256 id, // proposal id
    string description,
    uint256 maxVotes, // how many wallet addresses can vote on this
    address proposal // who made the proposal?
);

event newVote(
    uint256 votesUp,
    uint256 votesDown,
    address voter,
    uint256 proposal, 
    bool votedFor
);

// emit this when the time has elapsed

event proposalCount(
    uint256 id,
    bool passed
);
//
//
// PRIVATE FUNCTIONS
//
/*

run thru all valid tokens.. allow it if there is a valid token

*/

function checkProposalEligibility(address _proposer) private view returns (bool) {
    for (uint i=0; i < validTokens.length; i++) {
        if(daoContract.balanceOf(_proposer, validTokens[i]) >= 1){
            return true;
        }
    }
    return false;
}

function checkVoteEligibility(uint256 _id, address _voter) private view returns (bool) {
    for(uint256 i=0; i < Proposals[_id].canVote.length; i++) {
        if (Proposals[_id].canVote[i]== _voter) {
            return true;
        }
    }
    return false;
}


//
//
// Public - create a proposal
//

// storage and memory - https://docs.soliditylang.org/en/v0.8.15/introduction-to-smart-contracts.html?highlight=memory#storage-memory-and-the-stack

function createProposal(string memory _description, address[] memory _canVote) public {
   //Require -  https://docs.soliditylang.org/en/v0.8.15/control-structures.html?highlight=require#panic-via-assert-and-error-via-require
   // require needs a falsy condition

    require(checkProposalEligibility(msg.sender), "Only NFT holders can put forth proposals");

/*

Each account has a data area called storage, which is persistent between function calls and transactions. Storage is a key-value store that maps 256-bit words to 256-bit words. It is not possible to enumerate storage from within a contract, it is comparatively costly to read, and even more to initialise and modify storage. Because of this cost, you should minimize what you store in persistent storage to what the contract needs to run. Store data like derived calculations, caching, and aggregates outside of the contract. A contract can neither read nor write to any storage apart from its own.

*/  
    proposal storage newProposal = Proposals[nextProposal];
    newProposal.id = nextProposal;
    newProposal.exists = true;
    newProposal.description = _description;
    newProposal.deadLine = block.number + 100;
    newProposal.canVote = _canVote;
    newProposal.maxVotes = _canVote.length;

    emit proposalCreated(nextProposal, _description, _canVote.length, msg.sender);

    nextProposal++;

}


function voteOnProposal(uint256 _id, bool _vote) public {
    require(Proposals[_id].exists, "This proposal does not exist");
    require(checkVoteEligibility(_id, msg.sender),"You cannot vote on this proposal");
    require(!Proposals[_id].voteStatus[msg.sender], "You have already voted on this Proposal");
    require(block.number <= Proposals[_id].deadLine, "The deadLine for voting on this proposal has passed");

    proposal storage p = Proposals[_id];

    if (_vote) {
        p.votesUp++;
    } else {
        p.votesDown++;
    }

    p.voteStatus[msg.sender] = true;

    emit newVote(p.votesUp, p.votesDown, msg.sender, _id, _vote);

}

// when the deadline passes...
 
 function countVotes(uint256 _id) public {
    require(msg.sender == owner, "Only the owner can count votes");
    require(Proposals[_id].exists, "Proposal does not exist");
    require(block.number > Proposals[_id].deadLine, "deadline has not passed");
    require(!Proposals[_id].countConducted, "Count has been completed already");

    proposal storage p = Proposals[_id];

    if (p.votesDown < p.votesUp){
        p.passed = true;
    } else {
        p.passed = false;
    }

    p.countConducted = true;

    emit proposalCount(_id, p.passed);

 }

function addTokenId(uint256 _tokenid) public {
    require(msg.sender == owner, "Only the owner can add tokens");
    validTokens.push(_tokenid);
}

}

