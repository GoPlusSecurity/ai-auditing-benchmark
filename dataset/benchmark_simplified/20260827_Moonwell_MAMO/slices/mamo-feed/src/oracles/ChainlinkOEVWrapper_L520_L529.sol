    function _validateRoundData(
        uint80 roundId,
        int256 answer,
        uint256 updatedAt,
        uint80 answeredInRound
    ) internal pure {
        require(answer > 0, "Chainlink price cannot be lower or equal to 0");
        require(updatedAt != 0, "Round is in incompleted state");
        require(answeredInRound >= roundId, "Stale price");
    }
