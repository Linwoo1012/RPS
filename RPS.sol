
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPS is CommitReveal {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (address => uint) public player_choice; // 0 - Rock, 1 - Paper, 2 - Scissors, 3 - Lizard, 4 - Spock, 5 - Undefined
    mapping(address => bool) public player_not_played;
    address[] public players;

    mapping (address => bool) public isCommit;
    uint public numInput = 0;
    uint public numReveal = 0;
    uint public timeoutDeration = 1 minutes;
    uint public lastAction = block.timestamp;

    mapping(address => bool) private whitelistedPlayers;

    constructor() {
        whitelistedPlayers[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
        whitelistedPlayers[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
        whitelistedPlayers[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = true;
        whitelistedPlayers[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = true;
    }

    function addPlayer() public payable {
        require(numPlayer < 2, "Game already has 2 players.");
        require(whitelistedPlayers[msg.sender], "You are not allowed to play.");
        if (numPlayer > 0) {
            require(msg.sender != players[0]);
        }
        require(msg.value == 1 ether, "Pay 1 ether to play game.");
        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        player_choice[msg.sender] = 5;
        isCommit[msg.sender] = false;
        numPlayer++;
        emit playerAdded(msg.sender, numPlayer);

        lastAction = block.timestamp;
    }

    event playerAdded(address sender, uint numPlayer);

    // function getBytes32(uint choice, string memory salt) view  public returns (bytes32){
    //     require(choice >= 0 && choice <= 4, "Your choice needs to be between 0 to 4");
    //     bytes32 saltByte = bytes32(abi.encodePacked(salt));
    //     bytes32 choiceByte = bytes32(abi.encodePacked(choice));
    //     return getSaltedHash(choiceByte, saltByte);
    // }


    function input(bytes32 hashAns) public  {
        require(numPlayer == 2, "Game needs 2 players.");
        require(numInput < 2);
        require(player_not_played[msg.sender]);
        require(isCommit[msg.sender] == false, "You already commited.");
        
        player_not_played[msg.sender] = false;
        isCommit[msg.sender] = true;
        commit(hashAns);

        numInput++;
        emit playerCommitHashed(msg.sender,numInput);

        lastAction = block.timestamp;
    }

    event playerCommitHashed(address sender, uint numInput);

    function revealChoice(bytes32 hashChoice) public {
        require(numPlayer == 2);
        require(numInput == 2);

        uint choice = uint8(hashChoice[31]);
        require(choice >= 0 && choice <= 4, "Your choice needs to be between 0 to 4");
        require(isCommit[msg.sender], "You need to commit first.");

        // bytes32 saltByte = bytes32(abi.encodePacked(salt));
        // bytes32 choiceByte = bytes32(abi.encodePacked(choice));

        // revealAnswer(choiceByte, saltByte);
        reveal(hashChoice);

        player_choice[msg.sender] = choice;

        numReveal++;

        lastAction = block.timestamp;

        if(numReveal == 2){
            _checkWinnerAndPay();
            _reset();
        }
    }


    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);
        if (p0Choice == p1Choice) {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        } 
        else if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
            // to pay player[1]
            account1.transfer(reward);
        }
        else {
            // to pay player[0]
            account0.transfer(reward);    
        }
    }

    function _reset() private {
        delete players;

        numPlayer = 0;
        numInput = 0;
        numReveal = 0;
        reward = 0;
    }

    function timeOutWithDraw() public {
        require(numPlayer >= 1);
        require(block.timestamp > lastAction + timeoutDeration);
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);
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
            if (isCommit[account0] == true) {
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
            if (player_choice[account0] != 5) {
                account0.transfer(reward);
            }
            else {
                account1.transfer(reward);
            }
            _reset();
        }
    }
}