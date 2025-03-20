// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RPS is CommitReveal, TimeUnit {
    IERC20 public token;
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping(address => uint) public player_choice;
    mapping(address => bool) public isCommit;
    uint public numInput = 0;
    uint public numReveal = 0;
    uint public timeoutDuration = 1 minutes;
    address[] public players;
    uint256 public requiredAmount = 0.000001 ether;


    constructor(address _token) {
        token = IERC20(_token);
    }

    function checkAllowance() public view returns (uint256) {
        return token.allowance(msg.sender, msg.sender);
    }

    function addPlayer() public {
        require(numPlayer < 2, "Game already has 2 players.");
        require(token.allowance(msg.sender, msg.sender) >= requiredAmount, "Approve contract to withdraw funds.");
        
        if (numPlayer > 0) {
            require(msg.sender != players[0], "You are already in the game.");
        }
        
        players.push(msg.sender);
        player_choice[msg.sender] = 5; // Undefined
        isCommit[msg.sender] = false;
        numPlayer++;
        
        reward += requiredAmount;
        
        emit PlayerAdded(msg.sender, numPlayer);
        setStartTime();
    }

    event PlayerAdded(address sender, uint numPlayer);

    function input(bytes32 hashAns) public {
        require(numPlayer == 2, "Game needs 2 players.");
        require(numInput < 2, "Already committed.");
        require(!isCommit[msg.sender], "You already committed.");
        
        isCommit[msg.sender] = true;
        commit(hashAns);
        numInput++;

        if (numInput == 2) {
            _collectFunds();
        }
        
        emit PlayerCommitHashed(msg.sender, numInput);
        setStartTime();
    }

    event PlayerCommitHashed(address sender, uint numInput);

    function revealChoice(bytes32 hashChoice) public {
        require(numPlayer == 2);
        require(numInput == 2);
        require(isCommit[msg.sender], "You need to commit first.");
        
        uint choice = uint8(hashChoice[31]);
        require(choice >= 0 && choice <= 4, "Invalid choice.");
        
        reveal(hashChoice);
        player_choice[msg.sender] = choice;
        numReveal++;
        
        setStartTime();
        
        if (numReveal == 2) {
            _checkWinnerAndPay();
            _reset();
        }
    }

    function _collectFunds() private {
        require(token.allowance(players[0], players[0]) >= requiredAmount, "Player 1 has not approved enough funds.");
        require(token.allowance(players[1], players[1]) >= requiredAmount, "Player 2 has not approved enough funds.");
        
        token.transferFrom(players[0], address(this), requiredAmount);
        token.transferFrom(players[1], address(this), requiredAmount);
        reward += requiredAmount * 2;
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address winner;

        if (p0Choice == p1Choice) {
            token.transfer(players[0], reward / 2);
            token.transfer(players[1], reward / 2);
        } else if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
            winner = players[1];
        } else {
            winner = players[0];
        }
        
        if (winner != address(0)) {
            token.transfer(winner, reward);
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
        // require(block.timestamp > lastAction + timeoutDeration);
        require(elapsedSeconds() > timeoutDuration, "You need to wait 1 minute for withdraw.");
        require(address(this).balance >= reward, "Contract has insufficient balance.");
        address payable account0 = payable(players[0]);
        // only one player
        if (numPlayer == 1) {
            token.transfer(players[0], reward);
            _reset();
        }
        else if (numPlayer == 2) {
            // two players, not input or input but not reveal
            if (numInput == 0 || (numInput == 2 && numReveal == 0)) {
                token.transfer(players[0], reward/2);
                token.transfer(players[1], reward/2);
                _reset();
            }
            // two players, only one input
            else if (numInput == 1) {
                // pay to the player who input
                if (isCommit[account0] == true) {
                    token.transfer(players[0], reward);
                }
                else {
                    token.transfer(players[1], reward);
                }
                _reset();
            }
            // two players, only one reveal
            else if (numInput == 2 && numReveal == 1) {
                // pay to the player who reveal
                if (player_choice[account0] != 5) {
                    token.transfer(players[0], reward);
                }
                else {
                    token.transfer(players[1], reward);
                }
                _reset();
            }
            else if (numReveal == 2) {
                token.transfer(msg.sender, reward);
            }
        }
    }
}