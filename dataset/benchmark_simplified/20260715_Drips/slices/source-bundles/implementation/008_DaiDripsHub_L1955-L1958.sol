    modifier whenNotPaused() {
        require(!paused(), "Contract paused");
        _;
    }
