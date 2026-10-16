    function burn(uint256 amount) public override returns (bool success) {
        if (!_isExpired()) {
            return false;
        }

        _burn(msg.sender, amount);

        if (_rate.numerator != 0) {
            uint8 decimalsOfCollateral = _getCollateralDecimals();
            uint256 withdrawAmount = _applyDecimalGap(amount, decimals(), decimalsOfCollateral)
                .mul(_rate.numerator)
                .div(_rate.denominator);

            _sendCollateralTo(msg.sender, withdrawAmount);
        }

        return true;
    }
