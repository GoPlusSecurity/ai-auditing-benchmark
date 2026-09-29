    function verifyParsedQuote(V3Struct.ParsedV3QuoteStruct calldata v3quote)
        external
        view
        override
        returns (bool, bytes memory)
    {
        return _verifyParsedQuote(v3quote);
    }
