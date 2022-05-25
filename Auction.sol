// SPDX-License-Identifier: GPL-3.0
   pragma solidity >=0.5 <0.9;

contract Auction{

    //variables
    address private owner;
    address public highestBidder;
    bool private ownerHasWithdrawn;
    bool private cancelled;
    uint public startDate;
    uint public endDate;
    uint public bidIncrement;
    uint public highestBindingBid;
    mapping(address => uint) private bids;


    constructor(uint _startDate, uint _endDate, uint _bidIncrement){
        require(_startDate < _endDate, "Start date should be greater than end date.");
        owner = msg.sender;
        startDate = _startDate;
        endDate = _endDate;
        bidIncrement = _bidIncrement;
    }
    modifier onlyOwner(){
        require(msg.sender == owner, "Only owner can perform this action.");
        _;
    }

    modifier isCancelled(){
        require(cancelled == false, "The auction has been cancelled already.");
        _;
    }

    modifier notCancelled(){
        require(cancelled == false, "The auction has been cancelled.");
        _;
    }

    modifier auctionExpired(){
        require(block.timestamp < endDate, "The auction has expired.");
        _;
    }

    modifier auctionStarted(){
        require(block.timestamp > startDate, "The auction has not started yet.");
        _;
    }

    modifier auctionEndedOrCancelled {
        require(block.timestamp > endDate || cancelled, "Auction has not ended yet.");
        _;
    }

    modifier notOwner {
        require(msg.sender != owner, "Owner cannot bid.");
        _;
    }

    function min(uint a, uint b) private view returns (uint) {
        if (a < b) return a;
        return b;
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

     function cancelAuction() public onlyOwner isCancelled auctionExpired {
        cancelled = true;
        emit LogCancelled();
    }

    function placeBids() public payable auctionExpired auctionStarted notCancelled notOwner returns (bool) {
        
        //reject payments of 0 eth
        require(msg.value > 0, "Value needs to be greater than 0 eth.");
        uint newBid = bids[msg.sender] + msg.value;
       
        // if the user isn't even willing to overbid the highest binding bid, then revert the transaction
        require(newBid > highestBindingBid, "New bid not greater than highest binding bid."); 
       
        //take the previous highest bid before updating fundsByBidder, in case msg.sender is the
        // highestBidder and is just increasing their maximum bid).
        uint highestBid = bids[highestBidder];
        
        bids[msg.sender] = newBid;
        
        if (newBid <= highestBid) {

          
            //  you can never bid less ETH than you've already bid.
            highestBindingBid = min(newBid + bidIncrement, highestBid);
        } else {

            // if the user is NOT highestBidder, and has overbid highestBid completely, we set them
            // as the new highestBidder and recalculate highestBindingBid.
            
            if (msg.sender != highestBidder) {
                highestBidder = msg.sender;
                highestBindingBid = min(newBid, highestBid + bidIncrement);
            }
            highestBid = newBid;
        }

        emit LogBid(msg.sender, newBid, highestBidder, highestBid, highestBindingBid);
        return true;

    }

    function withdraw() public auctionEndedOrCancelled returns (bool) { 
        address payable withdrawalAccount;
        uint withdrawalAmount;

        if (cancelled) {
             // if the auction was canceled, everyone should simply be allowed to withdraw their funds.
            
            withdrawalAccount =  payable(msg.sender);
            withdrawalAmount = bids[withdrawalAccount];
        } else {

            // the auction finished without being cancelled
           
            if (msg.sender == owner) {
                // the auction's owner should be allowed to withdraw the highestBindingBid

                withdrawalAccount = payable(highestBidder);
                withdrawalAmount = highestBindingBid;
                ownerHasWithdrawn = true;
            } else if (msg.sender == highestBidder) {
                // the highest bidder should only be allowed to withdraw the difference between their highest bid and the highestBindingBid
                withdrawalAccount = payable(highestBidder);
                if (ownerHasWithdrawn) {
                    withdrawalAmount = bids[highestBidder];
                } else {
                    withdrawalAmount = bids[highestBidder] - highestBindingBid;
                }
            } else {
                //everyone who participated but didn't win the auction can withdraw their amount.
                withdrawalAccount = payable(msg.sender);
                withdrawalAmount = bids[withdrawalAccount];
            }
        }

        require(withdrawalAmount >= 0, "Withdraw amount should be >= 0.");
        bids[withdrawalAccount] -= withdrawalAmount;
        require(payable(msg.sender).send(withdrawalAmount) == true, "Could not send.");
        emit LogWithdrawal(msg.sender, withdrawalAccount, withdrawalAmount);
        return true;

    }

    event LogCancelled();
    event LogBid(address bidder, uint bid, address highestBidder, uint highestBid, uint highestBindingBid); 
    event LogWithdrawal(address withdrawer, address withdrawalAccount, uint amount);
}