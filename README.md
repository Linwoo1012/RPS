# Rock-Paper-Scissors-Lizard-Spock (RPSLS) Smart Contract

## How It Works

1. [Players join the game](#add-player-mechanism)
2. [Commit phase](#commit-phase-input-and-gethash-function)
3. [Reveal phase](#reveal-phase-revealchoice-function)
4. [Winner determination](#determining-the-winner-_checkwinnerandpay-function)
5. [Timeout handling & Reset state](#handling-player-delays--preventing-locked-funds-in-the-contract)

---

## Code Explanations

### Variables Explanation
```solidity
pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPS is CommitReveal, TimeUnit {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (address => uint) public player_choice; // 0 - Rock, 1 - Paper, 2 - Scissors, 3 - Lizard, 4 - Spock, 5 - Undefined
    mapping(address => bool) public player_not_played;
    address[] public players;

    mapping (address => bool) public isCommit;
    uint public numInput = 0;
    uint public numReveal = 0;
    uint public timeoutDeration = 1 minutes;
    // uint public lastAction = block.timestamp;

    mapping(address => bool) private whitelistedPlayers;

    constructor() {
        whitelistedPlayers[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
        whitelistedPlayers[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
        whitelistedPlayers[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = true;
        whitelistedPlayers[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = true;
    }
```
- Import [CommitReveal.sol](https://github.com/Linwoo1012/RPS/blob/main/CommitReveal.sol) and [TimeUnit.sol](https://github.com/Linwoo1012/RPS/blob/main/TimeUnit.sol).
- contract `RPS` inherit `CommitReveal` and `CommitReveal` to use function from these contract.
- `numPlayer` Tracks the number of players in the game (max 2).
- `reward` The total prize pool collected from the players.
- `player_choice` Maps each player to their chosen move (0-4, with 5 as undefined).
- `player_not_played` Tracks whether a player has submitted their commitment.
- `players` Stores the addresses of the two players.
- `isCommit` Indicates whether a player has committed their choice.
- `numInput` Tracks the number of committed inputs.
- `numReveal` Tracks the number of revealed choices.
- `timeoutDeration` Defines the timeout duration for inactivity (1 minute).
- `whitelistedPlayers` A list of allowed players to prevent unauthorized access.

---

## **Add player Mechanism**
```solidity
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

    // lastAction = block.timestamp;
    setStartTime();
}

event playerAdded(address sender, uint numPlayer);
```
- `Player Limit` Ensures there are no more than 2 players.
- `Whitelist Check` Verifies the player is whitelisted.
- `Prevents Duplicate Players` Ensures the same player can't join twice.
- `Payment Requirement` Requires the player to pay exactly 1 ether.
- `Game State Update` Updates the reward pool, initializes player data (`player_choice`, `isCommit`), and adds the player to the game.
- `Increment Player` Count Increases `numPlayer`.
- `Set Start Time` Calls setStartTime() to log the start time.
---

## **Commit-Reveal Mechanism**
To prevent players from knowing each other's choices before both have committed, the contract follows a **commit-reveal** pattern:
- ### Commit phase (`input` and `getHash` function)
  - `getHash` function
    Create input by using choice concatenated with random bits (in Solidity is hard to get real ramdom numbers thus, using Python for random input is a better solution.) [choice_hiding_code.ipynb](https://colab.research.google.com/drive/1cPqxOqzJ-brL05pd0WRAwwwK0Zzx-Rnl?usp=sharing)
    ```solidity
    function getHash(bytes32 data) public pure returns(bytes32){
        return keccak256(abi.encodePacked(data));
    }
    ```
  - `generateRandomBytes32` function (use it instead of [choice_hiding_code.ipynb](https://colab.research.google.com/drive/1cPqxOqzJ-brL05pd0WRAwwwK0Zzx-Rnl?usp=sharing))
    ```solidity
    function generateRandomBytes32(uint8 choice, string memory salt) public view returns (bytes32) {
        require(choice <= 4, "Invalid choice");
        
        // Generate a random 31-byte value
        bytes32 randomHash = keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, salt));
        bytes31 randomBytes = bytes31(randomHash);
        
        // Append the choice as the last byte
        bytes32 dataInput = bytes32(abi.encodePacked(randomBytes, bytes1(choice)));
        
        return dataInput;
    }
    ```
  - `input` function
    `hashAns` is bytes32 that we got from `getHash` function.
    Use `setStartTime()` for reset time.
    ```solidity
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

        // lastAction = block.timestamp;
        setStartTime();
    }

    event playerCommitHashed(address sender, uint numInput);
    ```
  
- ### **Reveal phase** (`revealChoice` function)
  `hashChoice` is created by [choice_hiding_code.ipynb](https://colab.research.google.com/drive/1cPqxOqzJ-brL05pd0WRAwwwK0Zzx-Rnl?usp=sharing) in **Commit phase**
  `player_choice` is the last byte of `hashChoice` because [choice_hiding_code.ipynb](https://colab.research.google.com/drive/1cPqxOqzJ-brL05pd0WRAwwwK0Zzx-Rnl?usp=sharing) generates bytes32 and saves the choice at the last byte.
  Use `setStartTime()` for reset time.
  ```solidity
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

        // lastAction = block.timestamp;
        setStartTime();

        if(numReveal == 2){
            _checkWinnerAndPay();
            _reset();
        }
    }
  ```
- ### **Determining the Winner** (`_checkWinnerAndPay` function)
  ![img](https://raw.githubusercontent.com/Linwoo1012/RPS/refs/heads/main/img/RPSLS.webp)<br/>
To determine the winner, we use modulo arithmetic instead of a complex if-else chain. This method checks the outcome based on the players' choices.

  - **Equal Choices** If both players select the same choice (p0Choice == p1Choice), the reward is split equally between them.
  - **Player 1 Wins** If Player 1's choice beats Player 0's choice (using modulo logic), Player 1 receives the entire reward.
  - **Player 0 Wins** If Player 0's choice beats Player 1's, Player 0 receives the entire reward.
   ```solidity
   function _checkWinnerAndPay() private {
       if (p0Choice == p1Choice) {
           account0.transfer(reward / 2);
           account1.transfer(reward / 2);
       } else if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
           account1.transfer(reward);
       } else {
           account0.transfer(reward);
       }
   }
   ```

---

## **Handling Player Delays & Preventing Locked Funds in the Contract**
The contract ensures that funds are always withdrawn and never permanently locked by implementing
### A **timeout withdrawal mechanism** in `timeOutWithDraw()`
  ```solidity
    function timeOutWithDraw() public {
        require(numPlayer >= 1);
        // require(block.timestamp > lastAction + timeoutDeration);
        require(elapsedSeconds() > timeoutDeration, "You need to wait 1 minute for withdraw.");
        require(address(this).balance >= reward, "Contract has insufficient balance.");
        address payable account0 = payable(players[0]);
        // only one player
        if (numPlayer == 1) {
            account0.transfer(reward);
            _reset();
        }
        else if (numPlayer == 2) {
            address payable account1 = payable(players[1]);
            // two players, not input or input but not reveal
            if (numInput == 0 || (numInput == 2 && numReveal == 0)) {
                account0.transfer(reward / 2);
                account1.transfer(reward / 2);
                _reset();
            }
            // two players, only one input
            else if (numInput == 1) {
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
            else if (numInput == 2 && numReveal == 1) {
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
  ```

### Function Breakdown

### 1. **Preconditions and Requirements**

``` solidity
require(numPlayer >= 1);
require(elapsedSeconds() > timeoutDeration, "You need to wait 1 minute for withdraw.");
require(address(this).balance >= reward, "Contract has insufficient balance.");
```

- Ensures at least one player is in the game.
- Checks if the required timeout period has passed before allowing withdrawal.
- Ensures the contract has enough balance to distribute the reward.

### 2. Handling the First Player
```solidity
address payable account0 = payable(players[0]);
```
Retrieves the first player's address.

### 3. Case 1: Only One Player
```solidity
if (numPlayer == 1) {
    account0.transfer(reward);
    _reset();
}
```
- If there's only one player, they receive the full reward.
- The game state is reset using _reset().
### 4. Case 2: Two Players
```solidity
else if (numPlayer == 2) {
    address payable account1 = payable(players[1]);
```
- Retrieves the second player's address.

**Scenario 1: No Input or No Reveal**
```solidity
if (numInput == 0 || (numInput == 2 && numReveal == 0)) {
    account0.transfer(reward / 2);
    account1.transfer(reward / 2);
    _reset();
}
```
- If no input was given, or both players input but neither revealed, the reward is split equally.

**Scenario 2: Only One Player Provided Input**
```solidity
else if (numInput == 1) {
    if (isCommit[account0] == true) {
        account0.transfer(reward);
    }
    else {
        account1.transfer(reward);
    }
    _reset();
}
```
- If only one player submitted input, the full reward goes to that player.

**Scenario 3: One Player Revealed Their Input**
```solidity
else if (numInput == 2 && numReveal == 1) {
    if (player_choice[account0] != 5) {
        account0.transfer(reward);
    }
    else {
        account1.transfer(reward);
    }
    _reset();
}
```
- If both players input but only one revealed, the player who revealed their input gets the full reward.

### A **reset mechanism** in `_reset()`
```solidity
function _reset() private {
    delete players;

    numPlayer = 0;
    numInput = 0;
    numReveal = 0;
    reward = 0;
}
```
- When the game ended or the player used `timeOutWithDraw()` the `_reset()` will call and reset state of the contract
---