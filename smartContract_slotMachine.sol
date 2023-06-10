// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract NumberGuessingGame {
    uint private randomNumber1; // 슬롯 머신 숫자1 (0-9 사이)
    uint private randomNumber2; // 슬롯 머신 숫자2
    uint private randomNumber3; // 슬롯 머신 숫자3
    uint private prizeAmount = 0.01 ether; // 베팅의 단위
    address private winner; // 상금을 전해줄 지갑 주소
    uint private playerCount = 0; // 이 트랜잭션(게임)을 사람들이 플레이한 횟수
    uint private randomVariable = 0; // 행운의 확률
    address private payoutAddress; // 남은 자금(이익)을 보내는 곳

    // Guess 이벤트는 사용자가 베팅을 할 때마다, 슬롯의 3개 숫자를 알려주고, 행운의 확률, 내가 베팅한 금액, 돌려 받은 금액(상금)을 log에 기록한다.
    event Guess(address indexed player, uint guess1, uint guess2, uint guess3, uint randomVariable, uint userInputValue, uint winningValue);
    
    // Payout 이벤트는 수익을 관리자가 지정한 지갑에 넣었을 때, 그 지갑의 주소와 보낸 이더를 log에 기록한다.
    event Payout(address indexed payoutAddress, uint amount);

    receive() external payable {
        // 0.01, 0.02, 0.03 이더 이외에는 트랜잭션 Fail을 만든다.
        require(msg.value == prizeAmount || msg.value == prizeAmount * 2 || msg.value == prizeAmount * 3, "Please send exactly 0.01, 0.02, or 0.03 ether to play the game.");

        // 랜덤 숫자 생성기를 통해 슬롯 머신의 3개 숫자를 정한다.
        (randomNumber1, randomNumber2, randomNumber3) = generateRandomNumbers();
        playerCount++; // 게임 플레이 횟수를 증가

        // 0.03을 베팅한 사람은 슬롯 머신의 3개 숫자 중 2개의 숫자만 동일해도 된다.
        if (msg.value == prizeAmount * 3 && (randomNumber1 == randomNumber2 || randomNumber2 == randomNumber3 || randomNumber1 == randomNumber3)) {
            uint winnings = 0.08 ether; // 맞췄을 경우 상금은 0.08 이더이다.
            if (address(this).balance < winnings) {
                winnings = address(this).balance; // 호스트가 줄 상금이 부족한 경우, 잔고에 남은 것을 모두 상금으로 준다.
            }
            winner = msg.sender; // 상금을 보내기 위해 주소를 지정한다
            emit Guess(msg.sender, randomNumber1, randomNumber2, randomNumber3, randomVariable, msg.value, winnings); // 베팅 이벤트 log에 기록
            (bool success, ) = payable(winner).call{value: winnings}(""); // payable 주소로 변환 뒤 상금 전송
            require(success, "Failed to send Ether to the winner."); // 예외 처리
        } 
        // 0.01, 0.02를 베팅한 사람들은 슬롯 머신의 3개 숫자 모두 동일해야한다.
        else if (randomNumber1 == randomNumber2 && randomNumber2 == randomNumber3) {
            uint winnings = 0;
            if (msg.value == prizeAmount) {
                winnings = 0.02 ether; // 0.01을 베팅한 사람의 상금
            } else if (msg.value == prizeAmount * 2) {
                winnings = 0.05 ether; // 0,02를 베팅한 사람의 상금
            }
            if (address(this).balance < winnings) {
                winnings = address(this).balance; // 호스트가 줄 상금이 부족한 경우, 잔고에 남은 것을 모두 상금으로 준다.
            }
            winner = msg.sender; // 상금을 보내기 위해 주소를 지정한다
            emit Guess(msg.sender, randomNumber1, randomNumber2, randomNumber3, randomVariable, msg.value, winnings); // 베팅 이벤트 log에 기록
            (bool success, ) = payable(winner).call{value: winnings}(""); // payable 주소로 변환 뒤 상금 전송
            require(success, "Failed to send Ether to the winner."); // 예외 처리
        } else {
            // 베팅에 실패했을 경우 행운의 확률을 증가 시킨다
            if (msg.value == prizeAmount || msg.value == prizeAmount * 3) { // 0.01, 0.03을 베팅한 경우 1~5 증가
                randomVariable += getRandomNumberInRange(1, 5);
            } else if (msg.value == prizeAmount * 2) { // 0.02를 베팅한 경우 3~10 으로 다소 크게 증가
                randomVariable += getRandomNumberInRange(3, 10);
            }

            // 마지막으로 행운의 확률을 돌려본다.
            if (getRandomNumberInRange(1, 100) <= randomVariable) { // 행운의 확률이 작동했다면
                uint winnings = 0;
                // 이전에 설명했던 상금과 동일
                if (msg.value == prizeAmount) {
                    winnings = 0.02 ether;
                } else if (msg.value == prizeAmount * 2) {
                    winnings = 0.05 ether;
                } else if (msg.value == prizeAmount * 3) {
                    winnings = 0.08 ether;
                }
                // 이전에 설명했던 잔금 상금
                if (address(this).balance < winnings) {
                    winnings = address(this).balance;
                }
                // 이전에 설명했던 이벤트 기록 및 이더 송금
                emit Guess(msg.sender, randomNumber1, randomNumber2, randomNumber3, randomVariable, msg.value, winnings);
                randomVariable = 0;
                (bool success, ) = payable(msg.sender).call{value: winnings}("");
                require(success, "Failed to send Ether to the winner.");
            } else {
                // 행운의 확률에도 포함되지 않았다면 그 상황의 이벤트를 기록한다.
                emit Guess(msg.sender, randomNumber1, randomNumber2, randomNumber3, randomVariable, msg.value, 0);
            }
        }
    }

    // 무작위로 0-9 사이의 3개의 슬롯 머신 넘버를 만드는 함수
    function generateRandomNumbers() private view returns (uint, uint, uint) {
        // 값을 더욱 무작위로 하기 위해서 msg.sender, block.timestamp 등 다양한 값을 포함 시킨다.
        uint num1 = uint(keccak256(abi.encodePacked(blockhash(block.number - 1), msg.sender))) % 10;
        uint num2 = uint(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))) % 10;
        uint num3 = uint(keccak256(abi.encodePacked(blockhash(block.number - 1), block.difficulty))) % 10;
        return (num1, num2, num3);
    }

    // 특정 범위 안에서의 랜덤 값을 하나 추출 ( 행운의 확률 작동 결정 조건문에 쓰임 )
    function getRandomNumberInRange(uint256 min, uint256 max) private view returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender))) % (max - min + 1)) + min;
    }

    // 게임 횟수를 반환
    function getPlayerCount() public view returns (uint) {
        return playerCount;
    }

    // 트랜잭션의 잔고(수익)을 반환
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    // 트랜잭션의 잔고(수익)를 보낼 주소 설정
    function setPayoutAddress(address _payoutAddress) public {
        require(payoutAddress == address(0), "Payout address is already set.");
        payoutAddress = _payoutAddress;
    }

    // 트랜잭션의 모든 잔고(수익)을 해당 주소로 보낸다.
    function sendRemainingBalance() public {
        require(msg.sender == payoutAddress, "You are not authorized to send the remaining balance.");
        uint remainingBalance = address(this).balance;
        (bool success, ) = payable(payoutAddress).call{value: remainingBalance}("");
        require(success, "Failed to send the remaining balance.");
        emit Payout(payoutAddress, remainingBalance);
    }
}
