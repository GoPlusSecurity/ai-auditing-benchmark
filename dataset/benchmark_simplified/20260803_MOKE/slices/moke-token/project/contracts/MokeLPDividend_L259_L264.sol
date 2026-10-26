    receive() external payable {
        if (!_swapping) {
            unprocessedBNB += msg.value;
        }
    }
}
