// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./context.sol";
import './safeMath.sol';
import './IERC20.sol';

contract SeedVesting is Ownable {
    using SafeMath for uint256;

    struct Participant {
        // How much he already bought

        uint256 fipiTokenPurcheased;

        uint256 fipiTokenClaimed;

        uint256 releasesClaimed;
    }

    event Bought(address indexed account, uint256 indexed amount);
    event Claimed(address indexed account, uint256 indexed amount);

    uint256 public tgeDeciles; //how much tokens for one bnb

    uint256[12] public releaseDates;
    uint256 public tgeDate;
    
    IERC20 public fiPiToken;

    
    function setListingDate(uint256 listingDateTimestamp) external onlyOwner {
        
        //FLUSH EVERYTHING
        delete releaseDates;
        tgeDate = listingDateTimestamp;

        //7776000
        listingDateTimestamp = listingDateTimestamp.add(7776000);
        //WE RELEASE TOKENS FOR 10 MONTHS
        for(uint256 i = 0; i < 12; i++)
        {
            //30 days 2592000
            //6h for tests 21600
            //1h for tests 3600
            releaseDates[i] = listingDateTimestamp;
            listingDateTimestamp = listingDateTimestamp.add(2592000);
            
        }
    }

    mapping(address => Participant) public participants;


    function setTokenAdress(IERC20 _fipiToken) external onlyOwner {
        fiPiToken = _fipiToken;
    }

    function addParticipant(address user, uint256 _alloc) external onlyOwner {
        require(user != address(0));
        participants[user].fipiTokenPurcheased = _alloc;
    }


    function addParticipantBatch(address[] memory _addresses, uint256[] memory _alloc) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) 
        {
            participants[_addresses[i]].fipiTokenPurcheased = _alloc[i];
        }
    }

    function revokeParticipant(address user) external onlyOwner {
        require(user != address(0));
        participants[user].fipiTokenPurcheased = 0;
    }

    function nextReleaseIn() external view returns (uint256){
        for (uint256 i = 0; i < releaseDates.length; i++) 
        {
            if (releaseDates[i] >= block.timestamp) 
            {
               return releaseDates[i];
            }
        }
        return 0;
    }

    constructor(uint256 _tgeDeciles) 
    {
        tgeDeciles = _tgeDeciles;
    } 



    function claim() public
    {
        require(msg.sender != address(0));
        Participant storage participant = participants[msg.sender];

        require(participant.fipiTokenPurcheased > 0, "You did not bought anything!");

        uint256 unlockedReleasesCount = 0;

        require(tgeDate > 0, "Listing date is not yet provided!");
        require(block.timestamp > tgeDate, "Token is not yet listed");

        //we start from 30% at tge
        uint256 tokenClaimable = participant.fipiTokenPurcheased.mul(tgeDeciles).div(10);

        //70% is vested
        uint256 restTokensVested = participant.fipiTokenPurcheased.sub(tokenClaimable);

        //now we check how many relesaes is done
        for (uint256 i = 0; i < releaseDates.length; i++) 
        {
            if (releaseDates[i] <= block.timestamp) 
            {
               unlockedReleasesCount ++;
            }
        }

        //we add everything released to initial 30%
        tokenClaimable = tokenClaimable.add(restTokensVested.mul(unlockedReleasesCount).div(12));

        require(tokenClaimable > participant.fipiTokenClaimed, "You have nothing left to claim wait for next release.");

        uint256 tokenToBeSendNow = tokenClaimable.sub(participant.fipiTokenClaimed);
        
        fiPiToken.transfer(msg.sender, tokenToBeSendNow);
        participant.fipiTokenClaimed = tokenClaimable;

        emit Claimed(msg.sender, tokenToBeSendNow);

    }

    function tokensAvailableForClaim(address account) external view returns (uint256){
        Participant storage participant = participants[account];

        if(participant.fipiTokenPurcheased == 0 || tgeDate == 0 || block.timestamp < tgeDate){
            return 0;
        }

        uint256 unlockedReleasesCount = 0;

        uint256 tokenClaimable = participant.fipiTokenPurcheased.mul(tgeDeciles).div(10);
        uint256 restTokensVested = participant.fipiTokenPurcheased.sub(tokenClaimable);
        for (uint256 i = 0; i < releaseDates.length; i++) 
        {
            if (releaseDates[i] <= block.timestamp) 
            {
               unlockedReleasesCount ++;
            }
        }

        //we add everything released to initial 30%
        tokenClaimable = tokenClaimable.add(restTokensVested.mul(unlockedReleasesCount).div(12));

        uint256 tokenToBeSendNow = tokenClaimable.sub(participant.fipiTokenClaimed);
        return tokenToBeSendNow;
    }

    function withDrawLeftTokens() external onlyOwner {
        fiPiToken.transfer(msg.sender, fiPiToken.balanceOf(address(this)));
    }
    
}