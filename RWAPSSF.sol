// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";

contract RPS is CommitReveal {
    struct Player {
        uint choice; // 0 - Rock, 1 - water , 2 -Air, 3-Paper, 4-sponge, 5-Scissors, 6-Fire, 7-undefined
        address addr;
        bool isCommit;
    }
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (uint => Player) public player;
    uint public numInput = 0;
    uint public numReveal = 0;
    uint public deadlineDuration = 1 minutes;
    uint public lastAction = block.timestamp;

    function addPlayer() public payable {
        require(numPlayer < 2);
        require(msg.value == 1 ether);
        reward += msg.value;
        player[numPlayer].addr = msg.sender;
        player[numPlayer].choice = 7;
        player[numPlayer].isCommit = false;
        numPlayer++;
        emit playerAdded(msg.sender, numPlayer);

        lastAction = block.timestamp;
    }

    event playerAdded(address sender, uint numPlayer);
    
    function getBytes32(uint choice, string memory salt) view  public returns (bytes32){
        require(choice >= 0 && choice <= 6);
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

        lastAction = block.timestamp;
    }
    
    event playerCommitHashed(address sender, uint numInput);

    function revealChoice(uint choice, uint idx, string memory salt) public {
        require(numPlayer == 2);
        require(numInput == 2);
        require(msg.sender == player[idx].addr);
        require(choice >= 0 && choice <= 6);
        require(player[idx].isCommit == true);
        
        bytes32 saltByte = bytes32(abi.encodePacked(salt));
        bytes32 ChoiceByte = bytes32(abi.encodePacked(choice));

        revealAnswer(ChoiceByte, saltByte);
        player[idx].choice = choice;
        numReveal++;

        lastAction = block.timestamp;

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
        if (p0Choice == p1Choice) {
        account0.transfer(reward / 2);
        account1.transfer(reward / 2);
        } 
        else if (((p0Choice + 1) % 7) == p1Choice || ((p0Choice + 2) % 7) == p1Choice || ((p0Choice + 3) % 7) == p1Choice) {
        account1.transfer(reward);
        } else {
        account0.transfer(reward);
        }
    }

    function _reset() private {
        numPlayer = 0;
        reward = 0;
        numInput = 0;
        numReveal = 0;
    }

    function timeOutWithDraw() public {
        require(numPlayer >= 1);
        require(block.timestamp > lastAction + deadlineDuration);
        address payable account0 = payable(player[0].addr);
        address payable account1 = payable(player[1].addr);
        // only one player
        if (numPlayer == 1) {
            account0.transfer(reward);
            _reset();
        }
        // two players, not input or input but not reveal
        else if (numPlayer == 2 && (numInput == 0 || (numInput == 2 && numReveal == 0))) {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
            _reset();
        }
        // two players, only one input
        else if (numPlayer == 2 && numInput == 1) {
            // pay to the player who input
            if (player[0].isCommit == true) {
                account0.transfer(reward);
            }
            else {
                account1.transfer(reward);
            }
            _reset();
        }
        // two players, only one reveal
        else if (numPlayer == 2 && numInput == 2 && numReveal == 1) {
            // pay to the player who reveal
            if (player[0].choice != 7) {
                account0.transfer(reward);
            }
            else {
                account1.transfer(reward);
            }
            _reset();
        }
    }
}
