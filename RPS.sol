// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";

contract RPS is CommitReveal {
    struct Player {
        uint choice; // 0 - Rock, 1 - Paper , 2 - Scissors, 3 - undefined
        address addr;
        bool isCommit;
    }
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (uint => Player) public player;
    uint public numInput = 0;
    uint public numReveal = 0;

    function addPlayer() public payable {
        require(numPlayer < 2);
        require(msg.value == 1 ether);
        reward += msg.value;
        player[numPlayer].addr = msg.sender;
        player[numPlayer].choice = 3;
        player[numPlayer].isCommit = false;
        numPlayer++;
        emit playerAdded(msg.sender, numPlayer);
    }

    event playerAdded(address sender, uint numPlayer);
    
    function getBytes32(uint choice, string memory salt) view  public returns (bytes32){
        require(choice >= 0 && choice <= 3);
        bytes32 saltByte = bytes32(abi.encodePacked(salt));
        bytes32 ChoiceByte = bytes32(abi.encodePacked(choice));
        return getSaltedHash(ChoiceByte, saltByte);
    }

    function input(bytes32 hashAns, uint idx) public  {
        require(numPlayer == 2);
        require(numInput < 2);
        require(msg.sender == player[idx].addr);
        require(player[idx].isCommit == false);
        player[idx].isCommit = true;
        commit(hashAns);
        numInput++;
        emit playerCommitHashed(msg.sender,numInput);
    }
    
    event playerCommitHashed(address sender, uint numInput);

    function revealChoice(uint choice, uint idx, string memory salt) public {
        require(numPlayer == 2);
        require(numInput == 2);
        require(msg.sender == player[idx].addr);
        require(choice >= 0 && choice <= 3);
        require(player[idx].isCommit == true);
        
        bytes32 saltByte = bytes32(abi.encodePacked(salt));
        bytes32 ChoiceByte = bytes32(abi.encodePacked(choice));

        revealAnswer(ChoiceByte, saltByte);
        player[idx].choice = choice;
        numReveal++;

        if (numReveal == 2) {
            _checkWinnerAndPay();
            _reset();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player[0].choice;
        uint p1Choice = player[1].choice;
        address payable account0 = payable(player[0].addr);
        address payable account1 = payable(player[1].addr);
        if ((p0Choice + 1) % 3 == p1Choice) {
            // to pay player[1]
            account1.transfer(reward);
        }
        else if ((p1Choice + 1) % 3 == p0Choice) {
            // to pay player[0]
            account0.transfer(reward);    
        }
        else {
            // to split reward
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
    }

    function _reset() private {
        numPlayer = 0;
        reward = 0;
        numInput = 0;
        numReveal = 0;
    }
}
