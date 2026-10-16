    function convertFromVerusNumber(uint256 a, uint8 decimals) internal pure returns (uint256 c) {

        if(decimals > 8 ) {
            uint8 power = decimals - 8;// number of decimals in verus
            c = a * (10 ** power);
        }else if(decimals < 8){
            uint8 power = 8 - decimals;// number of decimals in verus
            c = a / (10 ** power);
        } else {
            c = a;
        }
    
        return c;
    }
