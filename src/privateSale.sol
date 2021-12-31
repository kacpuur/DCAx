// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./context.sol";
import './safeMath.sol';
import './IERC20.sol';

contract Privatesale is Ownable {
    using SafeMath for uint256;

    // A participant in the privatesale
    struct Participant {
        // The amount someone can buy
        uint256 maxPurchaseAmountInBNB;
        // How much he already bought
        uint256 alreadyPurcheasedInBNB;

        uint256 fipiTokenPurcheased;

        uint256 fipiTokenClaimed;
    }

    event Bought(address indexed account, uint256 indexed amount);

    uint256 public tokenBNBRatio; //how much tokens for one bnb
    address payable public _BNBReciever;

    uint256 public tolalTokenSold; 
    uint256 public tolalBNBRaised; 
    uint256 public hardCap; 
    

    IERC20 public binanceCoin;
    IERC20 public fiPiToken;


    mapping(address => Participant) private participants;

    function addParticipant(address user, uint256 maxPurchaseAmount) external onlyOwner {
        require(user != address(0));
        participants[user].maxPurchaseAmountInBNB = maxPurchaseAmount;
    }

    function revokeParticipant(address user) external onlyOwner {
        require(user != address(0));
        participants[user].maxPurchaseAmountInBNB = 0;
    }

    //0xc41359a5f17D497D0cfc888D86f6EC9b0396187F
    constructor(IERC20 _fipiToken) public {

        _BNBReciever = payable(_msgSender());
        tokenBNBRatio = 10500;
        fiPiToken = _fipiToken;
        hardCap = 2 * 10 ** 18; //hardcap 200 BNB IN WEI
    } 

    function buy() payable public 
    {
        uint256 amountTobuy = msg.value;
        require(amountTobuy > 0, "You need to send some BNB");
        require(tolalBNBRaised.add(amountTobuy) <= hardCap, "Hardcap exceeded");


        require(msg.sender != address(0));
        Participant storage participant = participants[msg.sender];
        require(participant.maxPurchaseAmountInBNB > 0, "You are not on whitelist");
        require(participant.alreadyPurcheasedInBNB.add(amountTobuy) <= participant.maxPurchaseAmountInBNB, "You already bought your limit");
        
        uint256 numTokens = amountTobuy.div(10 ** 9).mul(tokenBNBRatio);
        uint256 fipiBalanceOfContract = fiPiToken.balanceOf(address(this));
        
        require(numTokens <= fipiBalanceOfContract, "Not enough tokens for the transaction");
         

        tolalTokenSold = tolalTokenSold.add(numTokens);
        tolalBNBRaised = tolalBNBRaised.add(amountTobuy);
        participant.alreadyPurcheasedInBNB = participant.alreadyPurcheasedInBNB.add(amountTobuy);
        participant.fipiTokenPurcheased = participant.fipiTokenPurcheased.add(numTokens);

        emit Bought(msg.sender, msg.value);
    }   

    function isWhitelisted(address account) external view returns (bool){
        Participant storage participant = participants[account];
        return participant.maxPurchaseAmountInBNB > 0;
    }

    function bnbInPrivateSaleSpend(address account) external view returns (uint256){
        Participant storage participant = participants[account];
        return participant.alreadyPurcheasedInBNB;
    }

    function yourFiPiTokens(address account) external view returns (uint256){
        Participant storage participant = participants[account];
        return participant.fipiTokenPurcheased;
    }


    function withdrawLeftTokens() external onlyOwner {
        fiPiToken.transfer(owner(), fiPiToken.balanceOf(address(this)));
    }
    
    function withDrawBNB() public {
        require(_msgSender() == _BNBReciever, "Only the bnb reciever can use this function!");
        _BNBReciever.transfer(address(this).balance);
    }

    function toString(uint256 value) internal pure returns (string memory) {

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

}