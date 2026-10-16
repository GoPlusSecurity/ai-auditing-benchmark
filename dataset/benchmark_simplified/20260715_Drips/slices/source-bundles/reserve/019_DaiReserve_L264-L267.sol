    function setUser(address newUser) public onlyOwner {
        emit UserSet(user, newUser);
        user = newUser;
    }
