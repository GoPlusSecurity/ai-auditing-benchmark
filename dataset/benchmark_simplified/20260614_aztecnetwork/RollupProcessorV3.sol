// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 Aztec.
pragma solidity >=0.8.4;

interface IVerifier {
    function verify(bytes memory _serializedProof, uint256 _publicInputsHash) external returns (bool);

    function getVerificationKeyHash() external pure returns (bytes32);
}


library AztecTypes {
    enum AztecAssetType {
        NOT_USED,
        ETH,
        ERC20,
        VIRTUAL
    }

    struct AztecAsset {
        uint256 id;
        address erc20Address;
        AztecAssetType assetType;
    }
}


library SafeCast {
    error SAFE_CAST_OVERFLOW();

    function toU128(uint256 a) internal pure returns (uint128) {
        if (a > type(uint128).max) revert SAFE_CAST_OVERFLOW();
        return uint128(a);
    }
}


/**
 * @title TokenTransfers
 * @dev Provides functions to safely call `transfer` and `transferFrom` methods on ERC20 tokens,
 * as well as the ability to call `transfer` and `transferFrom` without bubbling up errors
 */
library TokenTransfers {
    error INVALID_ADDRESS_NO_CODE();

    bytes4 private constant INVALID_ADDRESS_NO_CODE_SELECTOR = 0x21409272; // bytes4(keccak256('INVALID_ADDRESS_NO_CODE()'));
    bytes4 private constant TRANSFER_SELECTOR = 0xa9059cbb; // bytes4(keccak256('transfer(address,uint256)'));
    bytes4 private constant TRANSFER_FROM_SELECTOR = 0x23b872dd; // bytes4(keccak256('transferFrom(address,address,uint256)'));

    /**
     * @dev Safely call ERC20.transfer, handles tokens that do not throw on transfer failure or do not return transfer result
     * @param tokenAddress Where does the token live?
     * @param to Who are we sending tokens to?
     * @param amount How many tokens are we transferring?
     */
    function safeTransferTo(address tokenAddress, address to, uint256 amount) internal {
        // The ERC20 token standard states that:
        // 1. failed transfers must throw
        // 2. the result of the transfer (success/fail) is returned as a boolean
        // Some token contracts don't implement the spec correctly and will do one of the following:
        // 1. Contract does not throw if transfer fails, instead returns false
        // 2. Contract throws if transfer fails, but does not return any boolean value
        // We can check for these by evaluating the following:
        // | call succeeds? (c) | return value (v) | returndatasize == 0 (r)| interpreted result |
        // | ---                | ---              | ---                    | ---                |
        // | false              | false            | false                  | transfer fails     |
        // | false              | false            | true                   | transfer fails     |
        // | false              | true             | false                  | transfer fails     |
        // | false              | true             | true                   | transfer fails     |
        // | true               | false            | false                  | transfer fails     |
        // | true               | false            | true                   | transfer succeeds  |
        // | true               | true             | false                  | transfer succeeds  |
        // | true               | true             | true                   | transfer succeeds  |
        //
        // i.e. failure state = !(c && (r || v))
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, TRANSFER_SELECTOR)
            mstore(add(ptr, 0x4), to)
            mstore(add(ptr, 0x24), amount)
            if iszero(extcodesize(tokenAddress)) {
                mstore(0, INVALID_ADDRESS_NO_CODE_SELECTOR)
                revert(0, 0x4)
            }
            let call_success := call(gas(), tokenAddress, 0, ptr, 0x44, 0x00, 0x20)
            let result_success := or(iszero(returndatasize()), and(mload(0), 1))
            if iszero(and(call_success, result_success)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    /**
     * @dev Safely call ERC20.transferFrom, handles tokens that do not throw on transfer failure or do not return transfer result
     * @param tokenAddress Where does the token live?
     * @param source Who are we transferring tokens from
     * @param target Who are we transferring tokens to?
     * @param amount How many tokens are being transferred?
     */
    function safeTransferFrom(address tokenAddress, address source, address target, uint256 amount) internal {
        assembly {
            // call tokenAddress.transferFrom(source, target, value)
            let mPtr := mload(0x40)
            mstore(mPtr, TRANSFER_FROM_SELECTOR)
            mstore(add(mPtr, 0x04), source)
            mstore(add(mPtr, 0x24), target)
            mstore(add(mPtr, 0x44), amount)
            if iszero(extcodesize(tokenAddress)) {
                mstore(0, INVALID_ADDRESS_NO_CODE_SELECTOR)
                revert(0, 0x4)
            }
            let call_success := call(gas(), tokenAddress, 0, mPtr, 0x64, 0x00, 0x20)
            let result_success := or(iszero(returndatasize()), and(mload(0), 1))
            if iszero(and(call_success, result_success)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    /**
     * @dev Calls ERC(tokenAddress).transfer(to, amount). Errors are ignored! Use with caution!
     * @param tokenAddress Where does the token live?
     * @param to Who are we sending to?
     * @param amount How many tokens are being transferred?
     * @param gasToSend Amount of gas to send the contract. If value is 0, function uses gas() instead
     */
    function transferToDoNotBubbleErrors(address tokenAddress, address to, uint256 amount, uint256 gasToSend)
        internal
    {
        assembly {
            let callGas := gas()
            if gasToSend { callGas := gasToSend }
            let ptr := mload(0x40)
            mstore(ptr, TRANSFER_SELECTOR)
            mstore(add(ptr, 0x4), to)
            mstore(add(ptr, 0x24), amount)
            pop(call(callGas, tokenAddress, 0, ptr, 0x44, 0x00, 0x00))
        }
    }

    /**
     * @dev Calls ERC(tokenAddress).transferFrom(source, target, amount). Errors are ignored! Use with caution!
     * @param tokenAddress Where does the token live?
     * @param source Who are we transferring tokens from
     * @param target Who are we transferring tokens to?
     * @param amount How many tokens are being transferred?
     * @param gasToSend Amount of gas to send the contract. If value is 0, function uses gas() instead
     */
    function transferFromDoNotBubbleErrors(
        address tokenAddress,
        address source,
        address target,
        uint256 amount,
        uint256 gasToSend
    ) internal {
        assembly {
            let callGas := gas()
            if gasToSend { callGas := gasToSend }
            let mPtr := mload(0x40)
            mstore(mPtr, TRANSFER_FROM_SELECTOR)
            mstore(add(mPtr, 0x04), source)
            mstore(add(mPtr, 0x24), target)
            mstore(add(mPtr, 0x44), amount)
            pop(call(callGas, tokenAddress, 0, mPtr, 0x64, 0x00, 0x00))
        }
    }
}


library RollupProcessorLibrary {
    error SIGNATURE_ADDRESS_IS_ZERO();
    error SIGNATURE_RECOVERY_FAILED();
    error INVALID_SIGNATURE();

    /**
     * Extracts the address of the signer with ECDSA. Performs checks on `s` and `v` to
     * to prevent signature malleability based attacks
     * @param digest - Hashed data being signed over.
     * @param signature - ECDSA signature over the secp256k1 elliptic curve.
     * @param signer - Address that signs the signature.
     */
    function validateSignature(bytes32 digest, bytes memory signature, address signer) internal view {
        bool result;
        address recoveredSigner = address(0x0);
        if (signer == address(0x0)) {
            revert SIGNATURE_ADDRESS_IS_ZERO();
        }

        // prepend "\x19Ethereum Signed Message:\n32" to the digest to create the signed message
        bytes32 message;
        assembly {
            mstore(0, "\x19Ethereum Signed Message:\n32")
            mstore(add(0, 28), digest)
            message := keccak256(0, 60)
        }
        assembly {
            let mPtr := mload(0x40)
            let byteLength := mload(signature)

            // store the signature digest
            mstore(mPtr, message)

            // load 'v' - we need it for a condition check
            // add 0x60 to jump over 3 words - length of bytes array, r and s
            let v := shr(248, mload(add(signature, 0x60))) // bitshifting, to resemble padLeft
            let s := mload(add(signature, 0x40))

            /**
             * Original memory map for input to precompile
             *
             * signature : signature + 0x20            message
             * signature + 0x20 : signature + 0x40     r
             * signature + 0x40 : signature + 0x60     s
             * signature + 0x60 : signature + 0x80     v
             * Desired memory map for input to precompile
             *
             * signature : signature + 0x20            message
             * signature + 0x20 : signature + 0x40     v
             * signature + 0x40 : signature + 0x60     r
             * signature + 0x60 : signature + 0x80     s
             */

            // store s
            mstore(add(mPtr, 0x60), s)
            // store r
            mstore(add(mPtr, 0x40), mload(add(signature, 0x20)))
            // store v
            mstore(add(mPtr, 0x20), v)
            result :=
                and(
                    and(
                        // validate s is in lower half order
                        lt(s, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1),
                        and(
                            // validate signature length == 0x41
                            eq(byteLength, 0x41),
                            // validate v == 27 or v == 28
                            or(eq(v, 27), eq(v, 28))
                        )
                    ),
                    // validate call to ecrecover precompile succeeds
                    staticcall(gas(), 0x01, mPtr, 0x80, mPtr, 0x20)
                )

            // save the recoveredSigner only if the first word in signature is not `message` anymore
            switch eq(message, mload(mPtr))
            case 0 { recoveredSigner := mload(mPtr) }
            mstore(mPtr, byteLength) // and put the byte length back where it belongs

            // validate that recoveredSigner is not address(0x00)
            result := and(result, not(iszero(recoveredSigner)))
        }
        if (!result) {
            revert SIGNATURE_RECOVERY_FAILED();
        }
        if (recoveredSigner != signer) {
            revert INVALID_SIGNATURE();
        }
    }

    /**
     * Extracts the address of the signer with ECDSA. Performs checks on `s` and `v` to
     * to prevent signature malleability based attacks
     * This 'Unpacked' version expects 'signature' to be a 96-byte array.
     * i.e. the `v` parameter occupies a full 32 bytes of memory, not 1 byte
     * @param hashedMessage - Hashed data being signed over. This function only works if the message has been pre formated to EIP https://eips.ethereum.org/EIPS/eip-191
     * @param signature - ECDSA signature over the secp256k1 elliptic curve.
     * @param signer - Address that signs the signature.
     */
    function validateShieldSignatureUnpacked(bytes32 hashedMessage, bytes memory signature, address signer)
        internal
        view
    {
        bool result;
        address recoveredSigner = address(0x0);
        if (signer == address(0x0)) {
            revert SIGNATURE_ADDRESS_IS_ZERO();
        }
        assembly {
            // There's a little trick we can pull. We expect `signature` to be a byte array, of length 0x60, with
            // 'v', 'r' and 's' located linearly in memory. Preceeding this is the length parameter of `signature`.
            // We *replace* the length param with the signature msg to get a memory block formatted for the precompile
            // load length as a temporary variable
            // N.B. we mutate the signature by re-ordering r, s, and v!
            let byteLength := mload(signature)

            // store the signature digest
            mstore(signature, hashedMessage)

            // load 'v' - we need it for a condition check
            // add 0x60 to jump over 3 words - length of bytes array, r and s
            let v := mload(add(signature, 0x60))
            let s := mload(add(signature, 0x40))

            /**
             * Original memory map for input to precompile
             *
             * signature : signature + 0x20            message
             * signature + 0x20 : signature + 0x40     r
             * signature + 0x40 : signature + 0x60     s
             * signature + 0x60 : signature + 0x80     v
             * Desired memory map for input to precompile
             *
             * signature : signature + 0x20            message
             * signature + 0x20 : signature + 0x40     v
             * signature + 0x40 : signature + 0x60     r
             * signature + 0x60 : signature + 0x80     s
             */

            // move s to v position
            mstore(add(signature, 0x60), s)
            // move r to s position
            mstore(add(signature, 0x40), mload(add(signature, 0x20)))
            // move v to r position
            mstore(add(signature, 0x20), v)
            result :=
                and(
                    and(
                        // validate s is in lower half order
                        lt(s, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1),
                        and(
                            // validate signature length == 0x60 (unpacked)
                            eq(byteLength, 0x60),
                            // validate v == 27 or v == 28
                            or(eq(v, 27), eq(v, 28))
                        )
                    ),
                    // validate call to ecrecover precompile succeeds
                    staticcall(gas(), 0x01, signature, 0x80, signature, 0x20)
                )

            // save the recoveredSigner only if the first word in signature is not `message` anymore
            switch eq(hashedMessage, mload(signature))
            case 0 { recoveredSigner := mload(signature) }
            mstore(signature, byteLength) // and put the byte length back where it belongs

            // validate that recoveredSigner is not address(0x00)
            result := and(result, not(iszero(recoveredSigner)))
        }
        if (!result) {
            revert SIGNATURE_RECOVERY_FAILED();
        }
        if (recoveredSigner != signer) {
            revert INVALID_SIGNATURE();
        }
    }

    /**
     * Extracts the address of the signer with ECDSA. Performs checks on `s` and `v` to
     * to prevent signature malleability based attacks
     * This 'Unpacked' version expects 'signature' to be a 96-byte array.
     * i.e. the `v` parameter occupies a full 32 bytes of memory, not 1 byte
     * @param digest - Hashed data being signed over.
     * @param signature - ECDSA signature over the secp256k1 elliptic curve.
     * @param signer - Address that signs the signature.
     */
    function validateUnpackedSignature(bytes32 digest, bytes memory signature, address signer) internal view {
        bool result;
        address recoveredSigner = address(0x0);
        if (signer == address(0x0)) {
            revert SIGNATURE_ADDRESS_IS_ZERO();
        }

        // prepend "\x19Ethereum Signed Message:\n32" to the digest to create the signed message
        bytes32 message;
        assembly {
            mstore(0, "\x19Ethereum Signed Message:\n32")
            mstore(28, digest)
            message := keccak256(0, 60)
        }
        assembly {
            // There's a little trick we can pull. We expect `signature` to be a byte array, of length 0x60, with
            // 'v', 'r' and 's' located linearly in memory. Preceeding this is the length parameter of `signature`.
            // We *replace* the length param with the signature msg to get a memory block formatted for the precompile
            // load length as a temporary variable
            // N.B. we mutate the signature by re-ordering r, s, and v!
            let byteLength := mload(signature)

            // store the signature digest
            mstore(signature, message)

            // load 'v' - we need it for a condition check
            // add 0x60 to jump over 3 words - length of bytes array, r and s
            let v := mload(add(signature, 0x60))
            let s := mload(add(signature, 0x40))

            /**
             * Original memory map for input to precompile
             *
             * signature : signature + 0x20            message
             * signature + 0x20 : signature + 0x40     r
             * signature + 0x40 : signature + 0x60     s
             * signature + 0x60 : signature + 0x80     v
             * Desired memory map for input to precompile
             *
             * signature : signature + 0x20            message
             * signature + 0x20 : signature + 0x40     v
             * signature + 0x40 : signature + 0x60     r
             * signature + 0x60 : signature + 0x80     s
             */

            // move s to v position
            mstore(add(signature, 0x60), s)
            // move r to s position
            mstore(add(signature, 0x40), mload(add(signature, 0x20)))
            // move v to r position
            mstore(add(signature, 0x20), v)
            result :=
                and(
                    and(
                        // validate s is in lower half order
                        lt(s, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1),
                        and(
                            // validate signature length == 0x60 (unpacked)
                            eq(byteLength, 0x60),
                            // validate v == 27 or v == 28
                            or(eq(v, 27), eq(v, 28))
                        )
                    ),
                    // validate call to ecrecover precompile succeeds
                    staticcall(gas(), 0x01, signature, 0x80, signature, 0x20)
                )

            // save the recoveredSigner only if the first word in signature is not `message` anymore
            switch eq(message, mload(signature))
            case 0 { recoveredSigner := mload(signature) }
            mstore(signature, byteLength) // and put the byte length back where it belongs

            // validate that recoveredSigner is not address(0x00)
            result := and(result, not(iszero(recoveredSigner)))
        }
        if (!result) {
            revert SIGNATURE_RECOVERY_FAILED();
        }
        if (recoveredSigner != signer) {
            revert INVALID_SIGNATURE();
        }
    }

    /**
     * Convert a bytes32 into an ASCII encoded hex string
     * @param input bytes32 variable
     * @return result hex-encoded string
     */
    function toHexString(bytes32 input) internal pure returns (string memory result) {
        if (uint256(input) == 0x00) {
            assembly {
                result := mload(0x40)
                mstore(result, 0x40)
                mstore(add(result, 0x20), 0x3030303030303030303030303030303030303030303030303030303030303030)
                mstore(add(result, 0x40), 0x3030303030303030303030303030303030303030303030303030303030303030)
                mstore(0x40, add(result, 0x60))
            }
            return result;
        }
        assembly {
            result := mload(0x40)
            let table := add(result, 0x60)

            // Store lookup table that maps an integer from 0 to 99 into a 2-byte ASCII equivalent
            // Store lookup table that maps an integer from 0 to ff into a 2-byte ASCII equivalent
            mstore(add(table, 0x1e), 0x3030303130323033303430353036303730383039306130623063306430653066)
            mstore(add(table, 0x3e), 0x3130313131323133313431353136313731383139316131623163316431653166)
            mstore(add(table, 0x5e), 0x3230323132323233323432353236323732383239326132623263326432653266)
            mstore(add(table, 0x7e), 0x3330333133323333333433353336333733383339336133623363336433653366)
            mstore(add(table, 0x9e), 0x3430343134323433343434353436343734383439346134623463346434653466)
            mstore(add(table, 0xbe), 0x3530353135323533353435353536353735383539356135623563356435653566)
            mstore(add(table, 0xde), 0x3630363136323633363436353636363736383639366136623663366436653666)
            mstore(add(table, 0xfe), 0x3730373137323733373437353736373737383739376137623763376437653766)
            mstore(add(table, 0x11e), 0x3830383138323833383438353836383738383839386138623863386438653866)
            mstore(add(table, 0x13e), 0x3930393139323933393439353936393739383939396139623963396439653966)
            mstore(add(table, 0x15e), 0x6130613161326133613461356136613761386139616161626163616461656166)
            mstore(add(table, 0x17e), 0x6230623162326233623462356236623762386239626162626263626462656266)
            mstore(add(table, 0x19e), 0x6330633163326333633463356336633763386339636163626363636463656366)
            mstore(add(table, 0x1be), 0x6430643164326433643464356436643764386439646164626463646464656466)
            mstore(add(table, 0x1de), 0x6530653165326533653465356536653765386539656165626563656465656566)
            mstore(add(table, 0x1fe), 0x6630663166326633663466356636663766386639666166626663666466656666)
            /**
             * Convert `input` into ASCII.
             *
             * Slice 2 base-10  digits off of the input, use to index the ASCII lookup table.
             *
             * We start from the least significant digits, write results into mem backwards,
             * this prevents us from overwriting memory despite the fact that each mload
             * only contains 2 byteso f useful data.
             *
             */

            let base := input
            function slice(v, tableptr) {
                mstore(0x1e, mload(add(tableptr, shl(1, and(v, 0xff)))))
                mstore(0x1c, mload(add(tableptr, shl(1, and(shr(8, v), 0xff)))))
                mstore(0x1a, mload(add(tableptr, shl(1, and(shr(16, v), 0xff)))))
                mstore(0x18, mload(add(tableptr, shl(1, and(shr(24, v), 0xff)))))
                mstore(0x16, mload(add(tableptr, shl(1, and(shr(32, v), 0xff)))))
                mstore(0x14, mload(add(tableptr, shl(1, and(shr(40, v), 0xff)))))
                mstore(0x12, mload(add(tableptr, shl(1, and(shr(48, v), 0xff)))))
                mstore(0x10, mload(add(tableptr, shl(1, and(shr(56, v), 0xff)))))
                mstore(0x0e, mload(add(tableptr, shl(1, and(shr(64, v), 0xff)))))
                mstore(0x0c, mload(add(tableptr, shl(1, and(shr(72, v), 0xff)))))
                mstore(0x0a, mload(add(tableptr, shl(1, and(shr(80, v), 0xff)))))
                mstore(0x08, mload(add(tableptr, shl(1, and(shr(88, v), 0xff)))))
                mstore(0x06, mload(add(tableptr, shl(1, and(shr(96, v), 0xff)))))
                mstore(0x04, mload(add(tableptr, shl(1, and(shr(104, v), 0xff)))))
                mstore(0x02, mload(add(tableptr, shl(1, and(shr(112, v), 0xff)))))
                mstore(0x00, mload(add(tableptr, shl(1, and(shr(120, v), 0xff)))))
            }

            mstore(result, 0x40)
            slice(base, table)
            mstore(add(result, 0x40), mload(0x1e))
            base := shr(128, base)
            slice(base, table)
            mstore(add(result, 0x20), mload(0x1e))
            mstore(0x40, add(result, 0x60))
        }
    }

    function getSignedMessageForTxId(bytes32 txId) internal pure returns (bytes32 hashedMessage) {
        // we know this string length is 64 bytes
        string memory txIdHexString = toHexString(txId);

        assembly {
            let mPtr := mload(0x40)
            mstore(add(mPtr, 32), "\x19Ethereum Signed Message:\n210")
            mstore(add(mPtr, 61), "Signing this message will allow ")
            mstore(add(mPtr, 93), "your pending funds to be spent i")
            mstore(add(mPtr, 125), "n Aztec transaction:\n\n0x")
            mstore(add(mPtr, 149), mload(add(txIdHexString, 0x20)))
            mstore(add(mPtr, 181), mload(add(txIdHexString, 0x40)))
            mstore(add(mPtr, 213), "\n\nIMPORTANT: Only sign the messa")
            mstore(add(mPtr, 245), "ge if you trust the client")
            hashedMessage := keccak256(add(mPtr, 32), 239)
        }
    }
}


// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)


/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)



/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initialized`
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initializing`
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}


/**
 * ----------------------------------------
 *  PROOF DATA SPECIFICATION
 * ----------------------------------------
 * Our input "proof data" is represented as a single byte array - we use custom encoding to encode the
 * data associated with a rollup block. The encoded structure is as follows (excluding the length param of the bytes type):
 *
 *    | byte range      | num bytes        | name                             | description |
 *    | ---             | ---              | ---                              | ---         |
 *    | 0x00  - 0x20    | 32               | rollupId                         | Unique rollup block identifier. Equivalent to block number |
 *    | 0x20  - 0x40    | 32               | rollupSize                       | Max number of transactions in the block |
 *    | 0x40  - 0x60    | 32               | dataStartIndex                   | Position of the next empty slot in the Aztec data tree |
 *    | 0x60  - 0x80    | 32               | oldDataRoot                      | Root of the data tree prior to rollup block's state updates |
 *    | 0x80  - 0xa0    | 32               | newDataRoot                      | Root of the data tree after rollup block's state updates |
 *    | 0xa0  - 0xc0    | 32               | oldNullRoot                      | Root of the nullifier tree prior to rollup block's state updates |
 *    | 0xc0  - 0xe0    | 32               | newNullRoot                      | Root of the nullifier tree after rollup block's state updates |
 *    | 0xe0  - 0x100   | 32               | oldDataRootsRoot                 | Root of the tree of data tree roots prior to rollup block's state updates |
 *    | 0x100 - 0x120   | 32               | newDataRootsRoot                 | Root of the tree of data tree roots after rollup block's state updates |
 *    | 0x120 - 0x140   | 32               | oldDefiRoot                      | Root of the defi tree prior to rollup block's state updates |
 *    | 0x140 - 0x160   | 32               | newDefiRoot                      | Root of the defi tree after rollup block's state updates |
 *    | 0x160 - 0x560   | 1024             | encodedBridgeCallDatas[NUMBER_OF_BRIDGE_CALLS]   | Size-32 array of encodedBridgeCallDatas for bridges being called in this block. If encodedBridgeCallData == 0, no bridge is called |
 *    | 0x560 - 0x960   | 1024             | depositSums[NUMBER_OF_BRIDGE_CALLS] | Size-32 array of deposit values being sent to bridges which are called in this block |
 *    | 0x960 - 0xb60   | 512              | assetIds[NUMBER_OF_ASSETS]         | Size-16 array of assetIds which correspond to assets being used to pay fees in this block |
 *    | 0xb60 - 0xd60   | 512              | txFees[NUMBER_OF_ASSETS]           | Size-16 array of transaction fees paid to the rollup beneficiary, denominated in each assetId |
 *    | 0xd60 - 0x1160  | 1024             | interactionNotes[NUMBER_OF_BRIDGE_CALLS] | Size-32 array of defi interaction result commitments that must be inserted into the defi tree at this rollup block |
 *    | 0x1160 - 0x1180 | 32               | prevDefiInteractionHash          | A SHA256 hash of the data used to create each interaction result commitment. Used to validate correctness of interactionNotes |
 *    | 0x1180 - 0x11a0 | 32               | rollupBeneficiary                | The address that the fees from this rollup block should be sent to. Prevents a rollup proof being taken from the transaction pool and having its fees redirected |
 *    | 0x11a0 - 0x11c0 | 32               | numRollupTxs                     | Number of "inner rollup" proofs used to create the block proof. "inner rollup" circuits process 3-28 user txns, the outer rollup circuit processes 1-28 inner rollup proofs. |
 *    | 0x11c0 - 0x11c4 | 4                | numRealTxs                       | Number of transactions in the rollup excluding right-padded padding proofs |
 *    | 0x11c4 - 0x11c8 | 4                | encodedInnerTxData.length        | Number of bytes of encodedInnerTxData |
 *    | 0x11c8 - end    | encodedInnerTxData.length | encodedInnerTxData      | Encoded inner transaction data. Contains encoded form of the broadcasted data associated with each tx in the rollup block |
 *
 */

/**
 * --------------------------------------------
 *  DETERMINING THE NUMBER OF REAL TRANSACTIONS
 * --------------------------------------------
 * The `rollupSize` parameter describes the MAX number of txns in a block.
 * However the block may not be full.
 * Incomplete blocks will be padded with "padding" transactions that represent empty txns.
 *
 * The amount of end padding is not explicitly defined in `proofData`. It is derived.
 * The encodedInnerTxData does not include tx data for the txns associated with this end padding.
 * (it does include any padding transactions that are not part of the end padding, which can sometimes happen)
 * When decoded, the transaction data for each transaction is a fixed size (256 bytes)
 * Number of real transactions = rollupSize - (decoded tx data size / 256)
 *
 * The decoded transaction data associated with padding transactions is 256 zero bytes.
 *
 */

/**
 * @title Decoder
 * @dev contains functions for decoding/extracting the encoded proof data passed in as calldata,
 * as well as computing the SHA256 hash of the decoded data (publicInputsHash).
 * The publicInputsHash is used to ensure the data passed in as calldata matches the data used within the rollup circuit
 */
contract Decoder {
    /*----------------------------------------
      CONSTANTS
      ----------------------------------------*/
    uint256 internal constant NUMBER_OF_ASSETS = 16; // max number of assets in a block
    uint256 internal constant NUMBER_OF_BRIDGE_CALLS = 32; // max number of bridge calls in a block
    uint256 internal constant NUMBER_OF_BRIDGE_BYTES = 1024; // NUMBER_OF_BRIDGE_CALLS * 32
    uint256 internal constant NUMBER_OF_PUBLIC_INPUTS_PER_TX = 8; // number of ZK-SNARK "public inputs" per join-split/account/claim transaction
    uint256 internal constant TX_PUBLIC_INPUT_LENGTH = 256; // byte-length of NUMBER_OF_PUBLIC_INPUTS_PER_TX. NUMBER_OF_PUBLIC_INPUTS_PER_TX * 32;
    uint256 internal constant ROLLUP_NUM_HEADER_INPUTS = 142; // 58; // number of ZK-SNARK "public inputs" that make up the rollup header 14 + (NUMBER_OF_BRIDGE_CALLS * 3) + (NUMBER_OF_ASSETS * 2);
    uint256 internal constant ROLLUP_HEADER_LENGTH = 4544; // 1856; // ROLLUP_NUM_HEADER_INPUTS * 32;

    // ENCODED_PROOF_DATA_LENGTH_OFFSET = byte offset into the rollup header such that `numRealTransactions` occupies
    // the least significant 4 bytes of the 32-byte word being pointed to.
    // i.e. ROLLUP_HEADER_LENGTH - 28
    uint256 internal constant NUM_REAL_TRANSACTIONS_OFFSET = 4516;

    // ENCODED_PROOF_DATA_LENGTH_OFFSET = byte offset into the rollup header such that `encodedInnerProofData.length` occupies
    // the least significant 4 bytes of the 32-byte word being pointed to.
    // i.e. ROLLUP_HEADER_LENGTH - 24
    uint256 internal constant ENCODED_PROOF_DATA_LENGTH_OFFSET = 4520;

    // offset we add to `proofData` to point to the encodedBridgeCallDatas
    uint256 internal constant BRIDGE_CALL_DATAS_OFFSET = 0x180;

    // offset we add to `proofData` to point to prevDefiInteractionhash
    uint256 internal constant PREVIOUS_DEFI_INTERACTION_HASH_OFFSET = 4480; // ROLLUP_HEADER_LENGTH - 0x40

    // offset we add to `proofData` to point to rollupBeneficiary
    uint256 internal constant ROLLUP_BENEFICIARY_OFFSET = 4512; // ROLLUP_HEADER_LENGTH - 0x20

    // CIRCUIT_MODULUS = group order of the BN254 elliptic curve. All arithmetic gates in our ZK-SNARK circuits are evaluated modulo this prime.
    // Is used when computing the public inputs hash - our SHA256 hash outputs are reduced modulo CIRCUIT_MODULUS
    uint256 internal constant CIRCUIT_MODULUS =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    // SHA256 hashes
    uint256 internal constant PADDING_ROLLUP_HASH_SIZE_1 =
        0x22dd983f8337d97d56071f7986209ab2ee6039a422242e89126701c6ee005af0;
    uint256 internal constant PADDING_ROLLUP_HASH_SIZE_2 =
        0x076a27c79e5ace2a3d47f9dd2e83e4ff6ea8872b3c2218f66c92b89b55f36560;
    uint256 internal constant PADDING_ROLLUP_HASH_SIZE_4 =
        0x2f0c70a5bf5460465e9902f9c96be324e8064e762a5de52589fdb97cbce3c6ee;
    uint256 internal constant PADDING_ROLLUP_HASH_SIZE_8 =
        0x240ed0de145447ff0ceff2aa477f43e0e2ed7f3543ee3d8832f158ec76b183a9;
    uint256 internal constant PADDING_ROLLUP_HASH_SIZE_16 =
        0x1c52c159b4dae66c3dcf33b44d4d61ead6bc4d260f882ac6ba34dccf78892ca4;
    uint256 internal constant PADDING_ROLLUP_HASH_SIZE_32 =
        0x0df0e06ab8a02ce2ff08babd7144ab23ca2e99ddf318080cf88602eeb8913d44;
    uint256 internal constant PADDING_ROLLUP_HASH_SIZE_64 =
        0x1f83672815ac9b3ca31732d641784035834e96b269eaf6a2e759bf4fcc8e5bfd;

    uint256 internal constant ADDRESS_MASK = 0x00_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff;

    /*----------------------------------------
      ERROR TAGS
      ----------------------------------------*/
    error ENCODING_BYTE_INVALID();
    error INVALID_ROLLUP_TOPOLOGY();

    /*----------------------------------------
      DECODING FUNCTIONS
      ----------------------------------------*/
    /**
     * In `bytes proofData`, transaction data is appended after the rollup header data
     * Each transaction is described by 8 'public inputs' used to create a user transaction's ZK-SNARK proof
     * (i.e. there are 8 public inputs for each of the "join-split", "account" and "claim" circuits)
     * The public inputs are represented in calldata according to the following specification:
     *
     * | public input idx | calldata size (bytes) | variable description                         |
     * | 0                | 1                     | proofId - transaction type identifier        |
     * | 1                | 32                    | encrypted form of 1st output note            |
     * | 2                | 32                    | encrypted form of 2nd output note            |
     * | 3                | 32                    | nullifier of 1st input note                  |
     * | 4                | 32                    | nullifier of 2nd input note                  |
     * | 5                | 32                    | amount being deposited or withdrawn          |
     * | 6                | 20                    | address of depositor or withdraw destination |
     * | 7                | 4                     | assetId used in transaction                  |
     *
     * The following table maps proofId values to transaction types
     *
     *
     * | proofId | tx type     | description |
     * | ---     | ---         | ---         |
     * | 0       | padding     | empty transaction. Rollup blocks have a fixed number of txns. If number of real txns is less than block size, padding txns make up the difference |
     * | 1       | deposit     | deposit Eth/tokens into Aztec in exchange for encrypted Aztec notes |
     * | 2       | withdraw    | exchange encrypted Aztec notes for Eth/tokens sent to a public address |
     * | 3       | send        | private send |
     * | 4       | account     | creates an Aztec account |
     * | 5       | defiDeposit | deposit Eth/tokens into a L1 smart contract via a Defi bridge contract |
     * | 6       | defiClaim   | convert proceeds of defiDeposit tx back into encrypted Aztec notes |
     *
     * Most of the above transaction types do not use the full set of 8 public inputs (i.e. some are zero).
     * To save on calldata costs, we encode each transaction into the smallest payload possible.
     * In `decodeProof`, the encoded transaction data is decoded and written into memory
     *
     * As part of the decoding algorithms we must convert the 20-byte `publicOwner` and 4-byte `assetId` fields
     * into 32-byte EVM words
     *
     * The following functions perform transaction-specific decoding. The `proofId` field is decoded prior to calling these functions
     */

    /**
     * @notice Decodes a padding tx
     * @param _inPtr location in calldata of the encoded transaction
     * @return - a location in calldata of the next encoded transaction
     *
     * @dev Encoded padding tx consists of 1 byte, the `proofId`
     *      The `proofId` has been written into memory before we called this function so there is nothing to copy
     *      Advance the calldatapointer by 1 byte to move to the next transaction
     */
    function paddingTx(uint256 _inPtr, uint256) internal pure returns (uint256) {
        unchecked {
            return (_inPtr + 0x1);
        }
    }

    /**
     * @notice Decodes a deposit or a withdraw tx
     * @param _inPtr location in calldata of the encoded transaction
     * @param _outPtr location in memory to write the decoded transaction to
     * @return - location in calldata of the next encoded transaction
     *
     * @dev The deposit tx uses all 8 public inputs. All calldata is copied into memory.
     */
    function depositOrWithdrawTx(uint256 _inPtr, uint256 _outPtr) internal pure returns (uint256) {
        // Copy deposit calldata into memory
        assembly {
            // start copying into `outPtr + 0x20`, as `outPtr` points to `proofId`, which has already been written into memory
            calldatacopy(add(_outPtr, 0x20), add(_inPtr, 0x20), 0xa0) // noteCommitment{1, 2}, nullifier{1,2}, publicValue; 32*5 bytes
            calldatacopy(add(_outPtr, 0xcc), add(_inPtr, 0xc0), 0x14) // convert 20-byte `publicOwner` calldata variable into 32-byte EVM word
            calldatacopy(add(_outPtr, 0xfc), add(_inPtr, 0xd4), 0x4) // convert 4-byte `assetId` variable into 32-byte EVM word
        }
        // advance calldata ptr by 185 bytes
        unchecked {
            return (_inPtr + 0xb9);
        }
    }

    /**
     * @notice Decodes a send-type tx
     * @param _inPtr location in calldata of the encoded transaction
     * @param _outPtr location in memory to write the decoded transaction to
     * @return - location in calldata of the next encoded transaction
     *
     * @dev The send tx has 0-values for `publicValue`, `publicOwner` and `assetId`
     *      No need to copy anything into memory for these fields as memory defaults to 0
     */
    function sendTx(uint256 _inPtr, uint256 _outPtr) internal pure returns (uint256) {
        assembly {
            calldatacopy(add(_outPtr, 0x20), add(_inPtr, 0x20), 0x80) // noteCommitment{1, 2}, nullifier{1,2}; 32*4 bytes
        }
        unchecked {
            return (_inPtr + 0x81);
        }
    }

    /**
     * @notice Decodes an account creation tx
     * @param _inPtr location in calldata of the encoded transaction
     * @param _outPtr location in memory to write the decoded transaction to
     * @return - location in calldata of the next encoded transaction
     *
     * @dev The account tx has 0-values for `nullifier2`, `publicValue`, `publicOwner` and `assetId`
     *      No need to copy anything into memory for these fields as memory defaults to 0
     */
    function accountTx(uint256 _inPtr, uint256 _outPtr) internal pure returns (uint256) {
        assembly {
            calldatacopy(add(_outPtr, 0x20), add(_inPtr, 0x20), 0x80) // noteCommitment{1, 2}, nullifier{1,2}; 32*4 bytes
        }
        unchecked {
            return (_inPtr + 0x81);
        }
    }

    /**
     * @notice Decodes a defi deposit or claim tx
     * @param _inPtr location in calldata of the encoded transaction
     * @param _outPtr location in memory to write the decoded transaction to
     * @return - location in calldata of the next encoded transaction
     *
     * @dev The defi deposit/claim tx has 0-values for `publicValue`, `publicOwner` and `assetId`
     *      No need to copy anything into memory for these fields as memory defaults to 0
     */
    function defiDepositOrClaimTx(uint256 _inPtr, uint256 _outPtr) internal pure returns (uint256) {
        assembly {
            calldatacopy(add(_outPtr, 0x20), add(_inPtr, 0x20), 0x80) // noteCommitment{1, 2}, nullifier{1,2}; 32*4 bytes
        }
        unchecked {
            return (_inPtr + 0x81);
        }
    }

    /**
     * @notice Throws an error and reverts.
     * @dev If we hit this, there is a transaction whose proofId is invalid (i.e. not 0 to 7).
     */
    function invalidTx(uint256, uint256) internal pure returns (uint256) {
        revert ENCODING_BYTE_INVALID();
    }

    /**
     * @notice Decodes the rollup block's proof data
     * @dev This function converts the proof data into a representation we can work with in memory
     *      In particular, encoded transaction calldata is decoded and written into memory
     *      The rollup header is copied from calldata into memory as well
     * @return proofData a memory pointer to the decoded proof data
     * @return numTxs number of transactions in the rollup, excluding end-padding transactions
     * @return publicInputsHash sha256 hash of the public inputs
     *
     * @dev The `publicInputsHash` is a sha256 hash of the public inputs associated with each transaction in the rollup.
     *      It is used to validate the correctness of the data being fed into the rollup circuit.
     *
     *      (There is a bit of nomenclature abuse here. Processing a public input in the verifier algorithm costs 150 gas,
     *      which adds up very quickly. Instead of this, we sha256 hash what used to be the "public" inputs and only set
     *      the hash to be public. We then make the old "public" inputs private in the rollup circuit, and validate their
     *      correctness by checking that their sha256 hash matches what we compute in the decodeProof function!
     */
    function decodeProof() internal view returns (bytes memory proofData, uint256 numTxs, uint256 publicInputsHash) {
        // declare some variables that will be set inside asm blocks
        uint256 dataSize; // size of our decoded transaction data, in bytes
        uint256 outPtr; // memory pointer to where we will write our decoded transaction data
        uint256 inPtr; // calldata pointer into our proof data
        uint256 rollupSize; // max number of transactions in the rollup block
        uint256 decodedTxDataStart;

        {
            uint256 tailInPtr; // calldata pointer to the end of our proof data

            /**
             * Let's build a function table!
             *
             * To decode our tx data, we need to iterate over every encoded transaction and call its
             * associated decoding function. If we did this via a `switch` statement this would be VERY expensive,
             * due to the large number of JUMPI instructions that would be called.
             *
             * Instead, we use function pointers.
             * The `proofId` field in our encoded proof data is an integer from 0-6,
             * we can use `proofId` to index a table of function pointers for our respective decoding functions.
             * This is much faster as there is no conditional branching!
             */
            function(uint256, uint256) pure returns (uint256) callfunc; // we're going to use `callfunc` as a function pointer
            // `functionTable` is a pointer to a table in memory, containing function pointers
            // Step 1: reserve memory for functionTable
            uint256 functionTable;
            assembly {
                functionTable := mload(0x40)
                mstore(0x40, add(functionTable, 0x100)) // reserve 256 bytes for function pointers
            }
            {
                // Step 2: copy function pointers into local variables so that inline asm code can access them
                function(uint256, uint256) pure returns (uint256) t0 = paddingTx;
                function(uint256, uint256) pure returns (uint256) t1 = depositOrWithdrawTx;
                function(uint256, uint256) pure returns (uint256) t3 = sendTx;
                function(uint256, uint256) pure returns (uint256) t4 = accountTx;
                function(uint256, uint256) pure returns (uint256) t5 = defiDepositOrClaimTx;
                function(uint256, uint256) pure returns (uint256) t7 = invalidTx;

                // Step 3: write function pointers into the table!
                assembly {
                    mstore(functionTable, t0)
                    mstore(add(functionTable, 0x20), t1)
                    mstore(add(functionTable, 0x40), t1)
                    mstore(add(functionTable, 0x60), t3)
                    mstore(add(functionTable, 0x80), t4)
                    mstore(add(functionTable, 0xa0), t5)
                    mstore(add(functionTable, 0xc0), t5)
                    mstore(add(functionTable, 0xe0), t7) // a proofId of 7 is not a valid transaction type, set to invalidTx
                }
            }
            uint256 decodedTransactionDataSize;
            assembly {
                // Add encoded proof data size to dataSize, minus the 4 bytes of encodedInnerProofData.length.
                // Set inPtr to point to the length parameter of `bytes calldata proofData`
                inPtr := add(calldataload(0x04), 0x4) // `proofData = first input parameter. Calldata offset to proofData will be at 0x04. Add 0x04 to account for function signature.

                // Advance inPtr to point to the start of `proofData`
                inPtr := add(inPtr, 0x20)

                numTxs := and(calldataload(add(inPtr, NUM_REAL_TRANSACTIONS_OFFSET)), 0xffffffff)
                // Get encoded inner proof data size.
                // Add ENCODED_PROOF_DATA_LENGTH_OFFSET to inPtr to point to the correct variable in our header block,
                // mask off all but 4 least significant bytes as this is a packed 32-bit variable.
                let encodedInnerDataSize := and(calldataload(add(inPtr, ENCODED_PROOF_DATA_LENGTH_OFFSET)), 0xffffffff)

                // Load up the rollup size from `proofData`
                rollupSize := calldataload(add(inPtr, 0x20))

                // Compute the number of bytes our decoded proof data will take up.
                // i.e. num total txns in the rollup (including padding) * number of public inputs per transaction
                let decodedInnerDataSize := mul(rollupSize, TX_PUBLIC_INPUT_LENGTH)

                // We want `dataSize` to equal: rollup header length + decoded tx length (excluding padding blocks)
                let numInnerRollups := calldataload(add(inPtr, sub(ROLLUP_HEADER_LENGTH, 0x20)))
                let numTxsPerRollup := div(rollupSize, numInnerRollups)

                let numFilledBlocks := div(numTxs, numTxsPerRollup)
                numFilledBlocks := add(numFilledBlocks, iszero(eq(mul(numFilledBlocks, numTxsPerRollup), numTxs)))

                decodedTransactionDataSize := mul(mul(numFilledBlocks, numTxsPerRollup), TX_PUBLIC_INPUT_LENGTH)
                dataSize := add(ROLLUP_HEADER_LENGTH, decodedTransactionDataSize)

                // Allocate memory for `proofData`.
                proofData := mload(0x40)
                // Set free mem ptr to `dataSize` + 0x20 (to account for the 0x20 bytes for the length param of proofData)
                // This allocates memory whose size is equal to the rollup header size, plus the data required for
                // each transaction's decoded tx data (256 bytes * number of non-padding blocks).
                // Only reserve memory for blocks that contain non-padding proofs. These "padding" blocks don't need to be
                // stored in memory as we don't need their data for any computations.
                mstore(0x40, add(proofData, add(dataSize, 0x20)))

                // Set `outPtr` to point to the `proofData` length parameter
                outPtr := proofData
                // Write `dataSize` into `proofData.length`
                mstore(outPtr, dataSize)
                // Advance `outPtr` to point to start of `proofData`
                outPtr := add(outPtr, 0x20)

                // Copy rollup header data to `proofData`.
                calldatacopy(outPtr, inPtr, ROLLUP_HEADER_LENGTH)
                // Advance `outPtr` to point to the end of the header data (i.e. the start of the decoded inner transaction data)
                outPtr := add(outPtr, ROLLUP_HEADER_LENGTH)

                // Advance `inPtr` to point to the start of our encoded inner transaction data.
                // Add (ROLLUP_HEADER_LENGTH + 0x08) to skip over the packed (numRealTransactions, encodedProofData.length) parameters
                inPtr := add(inPtr, add(ROLLUP_HEADER_LENGTH, 0x08))

                // Set `tailInPtr` to point to the end of our encoded transaction data
                tailInPtr := add(inPtr, encodedInnerDataSize)
                // Set `decodedTxDataStart` pointer
                decodedTxDataStart := outPtr
            }
            /**
             * Start of decoding algorithm
             *
             * Iterate over every encoded transaction, load out the first byte (`proofId`) and use it to
             * jump to the relevant transaction's decoding function
             */
            assembly {
                // Subtract 31 bytes off of `inPtr`, so that the first byte of the encoded transaction data
                // is located at the least significant byte of calldataload(inPtr)
                // also adjust `tailInPtr` as we compare `inPtr` against `tailInPtr`
                inPtr := sub(inPtr, 0x1f)
                tailInPtr := sub(tailInPtr, 0x1f)
            }
            unchecked {
                for (; tailInPtr > inPtr;) {
                    assembly {
                        // For each tx, the encoding byte determines how we decode the tx calldata
                        // The encoding byte can take values from 0 to 7; we want to turn these into offsets that can index our function table.
                        // 1. Access encoding byte via `calldataload(inPtr)`. The least significant byte is our encoding byte. Mask off all but the 3 least sig bits
                        // 2. Shift left by 5 bits. This is equivalent to multiplying the encoding byte by 32.
                        // 3. The result will be 1 of 8 offset values (0x00, 0x20, ..., 0xe0) which we can use to retrieve the relevant function pointer from `functionTable`
                        let encoding := and(calldataload(inPtr), 7)
                        // Store `proofId` at `outPtr`.
                        mstore(outPtr, encoding) // proofId

                        // Use `proofId` to extract the relevant function pointer from `functionTable`
                        callfunc := mload(add(functionTable, shl(5, encoding)))
                    }
                    // Call the decoding function. Return value will be next required value of inPtr
                    inPtr = callfunc(inPtr, outPtr);
                    // advance outPtr by the size of a decoded transaction
                    outPtr += TX_PUBLIC_INPUT_LENGTH;
                }
            }
        }

        /**
         * Compute the public inputs hash
         *
         * We need to take our decoded proof data and compute its SHA256 hash.
         * This hash is fed into our rollup proof as a public input.
         * If the hash does not match the SHA256 hash computed within the rollup circuit
         * on the equivalent parameters, the proof will reject.
         * This check ensures that the transaction data present in calldata are equal to
         * the transaction data values present in the rollup ZK-SNARK circuit.
         *
         * One complication is the structure of the SHA256 hash.
         * We slice transactions into chunks equal to the number of transactions in the "inner rollup" circuit
         * (a rollup circuit verifies multiple "inner rollup" circuits, which each verify 3-28 private user transactions.
         *  This tree structure helps parallelise proof construction)
         * We then SHA256 hash each transaction *chunk*
         * Finally we SHA256 hash the above SHA256 hashes to get our public input hash!
         *
         * We do the above instead of a straight hash of all of the transaction data,
         * because it's faster to parallelise proof construction if the majority of the SHA256 hashes are computed in
         * the "inner rollup" circuit and not the main rollup circuit.
         */
        // Step 1: compute the hashes that constitute the inner proofs data
        bool invalidRollupTopology;
        assembly {
            // We need to figure out how many rollup proofs are in this tx and how many user transactions are in each rollup
            let numRollupTxs := mload(add(proofData, ROLLUP_HEADER_LENGTH))
            let numJoinSplitsPerRollup := div(rollupSize, numRollupTxs)
            let rollupDataSize := mul(mul(numJoinSplitsPerRollup, NUMBER_OF_PUBLIC_INPUTS_PER_TX), 32)

            // Compute the number of inner rollups that don't contain padding proofs
            let numNotEmptyInnerRollups := div(numTxs, numJoinSplitsPerRollup)
            numNotEmptyInnerRollups :=
                add(numNotEmptyInnerRollups, iszero(eq(mul(numNotEmptyInnerRollups, numJoinSplitsPerRollup), numTxs)))
            // Compute the number of inner rollups that only contain padding proofs!
            // For these "empty" inner rollups, we don't need to compute their public inputs hash directly,
            // we can use a precomputed value
            let numEmptyInnerRollups := sub(numRollupTxs, numNotEmptyInnerRollups)

            let proofdataHashPtr := mload(0x40)
            // Copy the header data into the `proofdataHash`
            // Header start is at calldataload(0x04) + 0x24 (+0x04 to skip over func signature, +0x20 to skip over byte array length param)
            calldatacopy(proofdataHashPtr, add(calldataload(0x04), 0x24), ROLLUP_HEADER_LENGTH)

            // Update pointer
            proofdataHashPtr := add(proofdataHashPtr, ROLLUP_HEADER_LENGTH)

            // Compute the endpoint for the `proofdataHashPtr` (used as a loop boundary condition)
            let endPtr := add(proofdataHashPtr, mul(numNotEmptyInnerRollups, 0x20))
            // Iterate over the public inputs of each inner rollup proof and compute their SHA256 hash

            // better solution here is ... iterate over number of non-padding rollup blocks
            // and hash those
            // for padding rollup blocks...just append the zero hash
            for {} lt(proofdataHashPtr, endPtr) { proofdataHashPtr := add(proofdataHashPtr, 0x20) } {
                // address(0x02) is the SHA256 precompile address
                if iszero(staticcall(gas(), 0x02, decodedTxDataStart, rollupDataSize, 0x00, 0x20)) {
                    revert(0x00, 0x00)
                }

                mstore(proofdataHashPtr, mod(mload(0x00), CIRCUIT_MODULUS))
                decodedTxDataStart := add(decodedTxDataStart, rollupDataSize)
            }

            // If there are empty inner rollups, we can use a precomputed hash
            // of their public inputs instead of computing it directly.
            if iszero(iszero(numEmptyInnerRollups)) {
                let zeroHash
                switch numJoinSplitsPerRollup
                case 32 { zeroHash := PADDING_ROLLUP_HASH_SIZE_32 }
                case 16 { zeroHash := PADDING_ROLLUP_HASH_SIZE_16 }
                case 64 { zeroHash := PADDING_ROLLUP_HASH_SIZE_64 }
                case 1 { zeroHash := PADDING_ROLLUP_HASH_SIZE_1 }
                case 2 { zeroHash := PADDING_ROLLUP_HASH_SIZE_2 }
                case 4 { zeroHash := PADDING_ROLLUP_HASH_SIZE_4 }
                case 8 { zeroHash := PADDING_ROLLUP_HASH_SIZE_8 }
                default { invalidRollupTopology := true }

                endPtr := add(endPtr, mul(numEmptyInnerRollups, 0x20))
                for {} lt(proofdataHashPtr, endPtr) { proofdataHashPtr := add(proofdataHashPtr, 0x20) } {
                    mstore(proofdataHashPtr, zeroHash)
                }
            }
            // Compute SHA256 hash of header data + inner public input hashes
            let startPtr := mload(0x40)
            if iszero(staticcall(gas(), 0x02, startPtr, sub(proofdataHashPtr, startPtr), 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            publicInputsHash := mod(mload(0x00), CIRCUIT_MODULUS)
        }
        if (invalidRollupTopology) {
            revert INVALID_ROLLUP_TOPOLOGY();
        }
    }

    /**
     * @notice Extracts the `rollupId` param from the decoded proof data
     * @dev This represents the rollupId of the next valid rollup block
     * @param _proofData the decoded proof data
     * @return nextRollupId the expected id of the next rollup block
     */
    function getRollupId(bytes memory _proofData) internal pure returns (uint256 nextRollupId) {
        assembly {
            nextRollupId := mload(add(_proofData, 0x20))
        }
    }

    /**
     * @notice Decodes the input merkle roots of `proofData` and computes rollupId && sha3 hash of roots && dataStartIndex
     * @dev The rollup's state is uniquely defined by the following variables:
     *          * The next empty location in the data root tree (rollupId + 1)
     *          * The next empty location in the data tree (dataStartIndex + rollupSize)
     *          * The root of the data tree
     *          * The root of the nullifier set
     *          * The root of the data root tree (tree containing all previous roots of the data tree)
     *          * The root of the defi tree
     *      Instead of storing all of these variables in storage (expensive!), we store a keccak256 hash of them.
     *      To validate the correctness of a block's state transition, we must perform the following:
     *          * Use proof broadcasted inputs to reconstruct the "old" state hash
     *          * Use proof broadcasted inputs to reconstruct the "new" state hash
     *          * Validate that the old state hash matches what is in storage
     *          * Set the old state hash to the new state hash
     *      N.B. we still store `dataSize` as a separate storage var as `proofData does not contain all
     *           neccessary information to reconstruct its old value.
     * @param _proofData cryptographic proofData associated with a rollup
     * @return rollupId
     * @return oldStateHash
     * @return newStateHash
     * @return numDataLeaves
     * @return dataStartIndex
     */
    function computeRootHashes(bytes memory _proofData)
        internal
        pure
        returns (
            uint256 rollupId,
            bytes32 oldStateHash,
            bytes32 newStateHash,
            uint32 numDataLeaves,
            uint32 dataStartIndex
        )
    {
        assembly {
            let dataStart := add(_proofData, 0x20) // jump over first word, it's length of data
            numDataLeaves := shl(1, mload(add(dataStart, 0x20))) // rollupSize * 2 (2 notes per tx)
            dataStartIndex := mload(add(dataStart, 0x40))

            // validate numDataLeaves && dataStartIndex are uint32s
            if or(gt(numDataLeaves, 0xffffffff), gt(dataStartIndex, 0xffffffff)) { revert(0, 0) }
            rollupId := mload(dataStart)

            let mPtr := mload(0x40)

            mstore(mPtr, rollupId) // old nextRollupId
            mstore(add(mPtr, 0x20), mload(add(dataStart, 0x60))) // oldDataRoot
            mstore(add(mPtr, 0x40), mload(add(dataStart, 0xa0))) // oldNullRoot
            mstore(add(mPtr, 0x60), mload(add(dataStart, 0xe0))) // oldRootRoot
            mstore(add(mPtr, 0x80), mload(add(dataStart, 0x120))) // oldDefiRoot
            oldStateHash := keccak256(mPtr, 0xa0)

            mstore(mPtr, add(rollupId, 0x01)) // new nextRollupId
            mstore(add(mPtr, 0x20), mload(add(dataStart, 0x80))) // newDataRoot
            mstore(add(mPtr, 0x40), mload(add(dataStart, 0xc0))) // newNullRoot
            mstore(add(mPtr, 0x60), mload(add(dataStart, 0x100))) // newRootRoot
            mstore(add(mPtr, 0x80), mload(add(dataStart, 0x140))) // newDefiRoot
            newStateHash := keccak256(mPtr, 0xa0)
        }
    }

    /**
     * @notice Extract the `prevDefiInteractionHash` from the proofData's rollup header
     * @param _proofData decoded rollup proof data
     * @return prevDefiInteractionHash the defiInteractionHash of the previous rollup block
     */
    function extractPrevDefiInteractionHash(bytes memory _proofData)
        internal
        pure
        returns (bytes32 prevDefiInteractionHash)
    {
        assembly {
            prevDefiInteractionHash := mload(add(_proofData, PREVIOUS_DEFI_INTERACTION_HASH_OFFSET))
        }
    }

    /**
     * @notice Extracts the address we pay the rollup fee to from the proofData's rollup header
     * @dev Rollup beneficiary address is included as part of the ZK-SNARK circuit data, so that the rollup provider
     *      can explicitly define who should get the fee when they are generating the ZK-SNARK proof (instead of
     *      simply sending the fee to msg.sender).
     *      This prevents front-running attacks where an attacker can take somebody else's rollup proof from out of
     *      the tx pool and replay it, stealing the fee.
     * @param _proofData byte array of our input proof data
     * @return rollupBeneficiary the address we pay this rollup block's fee to
     */
    function extractRollupBeneficiary(bytes memory _proofData) internal pure returns (address rollupBeneficiary) {
        assembly {
            rollupBeneficiary := mload(add(_proofData, ROLLUP_BENEFICIARY_OFFSET))
            // Validate `rollupBeneficiary` is an address
            if gt(rollupBeneficiary, ADDRESS_MASK) { revert(0, 0) }
        }
    }

    /**
     * @notice Extracts an `assetId` in which a fee is going to be paid from a rollup block
     * @dev The rollup block contains up to 16 different assets, which can be recovered from the rollup header data.
     * @param _proofData byte array of our input proof data
     * @param _idx index of the asset we want (assetId = header.assetIds[_idx])
     * @return assetId 30-bit identifier of an asset. The ERC20 token address is obtained via the mapping `supportedAssets[assetId]`,
     */
    function extractFeeAssetId(bytes memory _proofData, uint256 _idx) internal pure returns (uint256 assetId) {
        assembly {
            assetId :=
                mload(
                    add(add(add(_proofData, BRIDGE_CALL_DATAS_OFFSET), mul(0x40, NUMBER_OF_BRIDGE_CALLS)), mul(0x20, _idx))
                )
            // Validate `assetId` is a uint32!
            if gt(assetId, 0xffffffff) { revert(0, 0) }
        }
    }

    /**
     * @notice Extracts the transaction fee for a given asset which is to be paid to the rollup beneficiary
     * @dev The total fee is the sum of the individual fees paid by each transaction in the rollup block.
     *      This sum is computed directly in the rollup circuit, and is present in the rollup header data.
     * @param _proofData byte array of decoded rollup proof data
     * @param _idx The index of the asset the fee is denominated in
     * @return totalTxFee total rollup block transaction fee for a given asset
     */
    function extractTotalTxFee(bytes memory _proofData, uint256 _idx) internal pure returns (uint256 totalTxFee) {
        assembly {
            totalTxFee := mload(add(add(add(_proofData, 0x380), mul(0x40, NUMBER_OF_BRIDGE_CALLS)), mul(0x20, _idx)))
        }
    }
}


/**
 * @title Rollup Processor
 * @dev Smart contract responsible for processing Aztec zkRollups, relaying them to a verifier
 *      contract for validation and performing all the relevant ERC20 token transfers
 */
contract RollupProcessorV3 is Decoder, Initializable {
    using SafeCast for uint256;
    /*----------------------------------------
      ERROR TAGS
      ----------------------------------------*/

    error PAUSED();
    error LOCKED_NO_REENTER();
    error INSUFFICIENT_DEPOSIT();
    error INVALID_ADDRESS_NO_CODE();
    error INVALID_ASSET_ID();
    error INVALID_ASSET_ADDRESS();
    error INVALID_ESCAPE_BOUNDS();
    error INCONSISTENT_BRIDGE_CALL_DATA();
    error BRIDGE_WITH_IDENTICAL_INPUT_ASSETS(uint256 inputAssetId);
    error BRIDGE_WITH_IDENTICAL_OUTPUT_ASSETS(uint256 outputAssetId);
    error ZERO_TOTAL_INPUT_VALUE();
    error ARRAY_OVERFLOW();
    error WITHDRAW_TO_ZERO_ADDRESS();
    error INCORRECT_STATE_HASH(bytes32 oldStateHash, bytes32 newStateHash);
    error INCORRECT_DATA_START_INDEX(uint256 providedIndex, uint256 expectedIndex);
    error INCORRECT_PREVIOUS_DEFI_INTERACTION_HASH(
        bytes32 providedDefiInteractionHash, bytes32 expectedDefiInteractionHash
    );
    error PENDING_CAP_SURPASSED();
    error DAILY_CAP_SURPASSED();

    /*----------------------------------------
      EVENTS
      ----------------------------------------*/
    event RollupProcessed(uint256 indexed rollupId, bytes32[] nextExpectedDefiHashes, address sender);
    event DefiBridgeProcessed(
        uint256 indexed encodedBridgeCallData,
        uint256 indexed nonce,
        uint256 totalInputValue,
        uint256 totalOutputValueA,
        uint256 totalOutputValueB,
        bool result,
        bytes errorReason
    );
    event AsyncDefiBridgeProcessed(
        uint256 indexed encodedBridgeCallData, uint256 indexed nonce, uint256 totalInputValue
    );

    /*----------------------------------------
      STRUCTS
      ----------------------------------------*/

    // @dev ALLOW_ASYNC_REENTER lock is present to allow calling of `processAsyncDefiInteraction(...)` from within
    //      bridge's `convert(...)` method.
    enum Lock {
        UNLOCKED,
        ALLOW_ASYNC_REENTER,
        LOCKED
    }

    /**
     * @dev RollupState struct contains the following data:
     *
     * | bit offset   | num bits    | description |
     * | ---          | ---         | ---         |
     * | 0            | 160         | PLONK verifier contract address |
     * | 160          | 32          | datasize: number of filled entries in note tree |
     * | 192          | 16          | asyncDefiInteractionHashes.length : number of entries in asyncDefiInteractionHashes array |
     * | 208          | 16          | defiInteractionHashes.length : number of entries in defiInteractionHashes array |
     * | 224          | 8           | Lock enum used to guard against reentrancy attacks (minimum value to store in is uint8)
     * | 232          | 8           | pause flag, true if contract is paused, false otherwise
     * | 240          | 8           | capped flag, true if assets should check cap, false otherwise
     *
     * Note: (RollupState struct gets packed to 1 storage slot -> bit offset signifies location withing the 256 bit string)
     */
    struct RollupState {
        IVerifier verifier;
        uint32 datasize;
        uint16 numAsyncDefiInteractionHashes;
        uint16 numDefiInteractionHashes;
        Lock lock;
        bool paused;
        bool capped;
    }

    /**
     * @dev Contains information that describes a specific call to a bridge
     */
    struct FullBridgeCallData {
        uint256 bridgeAddressId;
        address bridgeAddress;
        uint256 inputAssetIdA;
        uint256 inputAssetIdB;
        uint256 outputAssetIdA;
        uint256 outputAssetIdB;
        uint256 auxData;
        bool firstInputVirtual;
        bool secondInputVirtual;
        bool firstOutputVirtual;
        bool secondOutputVirtual;
        bool secondInputInUse;
        bool secondOutputInUse;
        uint256 bridgeGasLimit;
    }

    /**
     * @dev Represents an asynchronous DeFi bridge interaction that has not been resolved
     * @param encodedBridgeCallData bit-string encoded bridge call data
     * @param totalInputValue number of tokens/wei sent to the bridge
     */
    struct PendingDefiBridgeInteraction {
        uint256 encodedBridgeCallData;
        uint256 totalInputValue;
    }

    /**
     * @dev Container for the results of a DeFi interaction
     * @param outputValueA amount of output asset A returned from the interaction
     * @param outputValueB amount of output asset B returned from the interaction (0 if asset B unused)
     * @param isAsync true if the interaction is asynchronous, false otherwise
     * @param success true if the call succeeded, false otherwise
     */
    struct BridgeResult {
        uint256 outputValueA;
        uint256 outputValueB;
        bool isAsync;
        bool success;
    }


    /**
     * @dev Container for asset cap restrictions
     * @dev Caps used to limit usefulness of using Aztec to "wash" larger hacks
     * @param available The amount of tokens that can be deposited, bounded by `dailyCap * 10 ** decimals`.
     * @param lastUpdatedTimestamp The timestamp of the last deposit with caps activated
     * @param pendingCap The cap for each individual pending deposit measured in whole tokens
     * @param dailyCap The cap for total amount that can be added to `available` in 24 hours, measured in whole tokens
     * @param precision The number of decimals in the precision for specific asset.
     */
    struct AssetCap {
        uint128 available;
        uint32 lastUpdatedTimestamp;
        uint32 pendingCap;
        uint32 dailyCap;
        uint8 precision;
    }

    /*----------------------------------------
      FUNCTION SELECTORS (PRECOMPUTED)
      ----------------------------------------*/
    // DEFI_BRIDGE_PROXY_CONVERT_SELECTOR = function signature of:
    //   function convert(
    //       address,
    //       AztecTypes.AztecAsset memory inputAssetA,
    //       AztecTypes.AztecAsset memory inputAssetB,
    //       AztecTypes.AztecAsset memory outputAssetA,
    //       AztecTypes.AztecAsset memory outputAssetB,
    //       uint256 totalInputValue,
    //       uint256 interactionNonce,
    //       uint256 auxData,
    //       uint256 ethPaymentsSlot
    //       address rollupBeneficary)
    // N.B. this is the selector of the 'convert' function of the DefiBridgeProxy contract.
    //      This has a different interface to the IDefiBridge.convert function
    bytes4 private constant DEFI_BRIDGE_PROXY_CONVERT_SELECTOR = 0x4bd947a8;

    bytes4 private constant INVALID_ADDRESS_NO_CODE_SELECTOR = 0x21409272; // bytes4(keccak256('INVALID_ADDRESS_NO_CODE()'));

    bytes4 private constant ARRAY_OVERFLOW_SELECTOR = 0x58a4ab0e; // bytes4(keccak256('ARRAY_OVERFLOW()'));

    /*----------------------------------------
      CONSTANT STATE VARIABLES
      ----------------------------------------*/
    uint256 private constant ETH_ASSET_ID = 0; // if assetId == ETH_ASSET_ID, treat as native ETH and not ERC20 token

    // starting root hash of the DeFi interaction result Merkle tree
    bytes32 private constant INIT_DEFI_ROOT = 0x2e4ab7889ab3139204945f9e722c7a8fdb84e66439d787bd066c3d896dba04ea;

    bytes32 private constant DEFI_BRIDGE_PROCESSED_SIGHASH =
        0x692cf5822a02f5edf084dc7249b3a06293621e069f11975ed70908ed10ed2e2c;

    bytes32 private constant ASYNC_BRIDGE_PROCESSED_SIGHASH =
        0x38ce48f4c2f3454bcf130721f25a4262b2ff2c8e36af937b30edf01ba481eb1d;

    // Bit offsets and bit masks used to extract values from `uint256 encodedBridgeCallData` to FullBridgeCallData struct
    uint256 private constant INPUT_ASSET_ID_A_SHIFT = 32;
    uint256 private constant INPUT_ASSET_ID_B_SHIFT = 62;
    uint256 private constant OUTPUT_ASSET_ID_A_SHIFT = 92;
    uint256 private constant OUTPUT_ASSET_ID_B_SHIFT = 122;
    uint256 private constant BITCONFIG_SHIFT = 152;
    uint256 private constant AUX_DATA_SHIFT = 184;
    uint256 private constant VIRTUAL_ASSET_ID_FLAG_SHIFT = 29;
    uint256 private constant VIRTUAL_ASSET_ID_FLAG = 0x2000_0000; // 2 ** 29
    uint256 private constant MASK_THIRTY_TWO_BITS = 0xffff_ffff;
    uint256 private constant MASK_THIRTY_BITS = 0x3fff_ffff;
    uint256 private constant MASK_SIXTY_FOUR_BITS = 0xffff_ffff_ffff_ffff;

    // Offsets and masks used to encode/decode the rollupState storage variable of RollupProcessor
    uint256 private constant DATASIZE_BIT_OFFSET = 160;
    uint256 private constant ASYNCDEFIINTERACTIONHASHES_BIT_OFFSET = 192;
    uint256 private constant DEFIINTERACTIONHASHES_BIT_OFFSET = 208;
    uint256 private constant ARRAY_LENGTH_MASK = 0x3ff; // 1023
    uint256 private constant DATASIZE_MASK = 0xffff_ffff;

    // the value of hashing a 'zeroed' DeFi interaction result
    bytes32 private constant DEFI_RESULT_ZERO_HASH = 0x2d25a1e3a51eb293004c4b56abe12ed0da6bca2b4a21936752a85d102593c1b4;


    // bounds used for escape hatch
    uint256 public immutable escapeBlockLowerBound;
    uint256 public immutable escapeBlockUpperBound;

    /*----------------------------------------
      STATE VARIABLES
      ----------------------------------------*/
    RollupState internal rollupState;

    // An array of addresses of supported ERC20 tokens
    address[] internal supportedAssets;

    // An array of addresses of supported bridges
    // @dev `bridgeAddressId` is an index of the bridge's address in this array incremented by 1
    address[] internal supportedBridges;

    // A mapping from index to async interaction hash (emulates an array)
    // @dev next index is stored in `RollupState.numAsyncDefiInteractionHashes`
    mapping(uint256 => bytes32) public asyncDefiInteractionHashes;

    // A mapping from index to interaction hash (emulates an array)
    // @dev next index is stored in the `RollupState.numDefiInteractionHashes`
    mapping(uint256 => bytes32) public defiInteractionHashes;

    // A mapping from assetId to a mapping of userAddress to the user's public pending balance
    mapping(uint256 => mapping(address => uint256)) public userPendingDeposits;

    // A mapping from user's address to a mapping of proof hashes to a boolean which indicates approval
    mapping(address => mapping(bytes32 => bool)) public depositProofApprovals;

    // A hash of the latest rollup state
    bytes32 public rollupStateHash;

    // An address of DefiBridgeProxy contract
    address public defiBridgeProxy;

    // A flag indicating whether addresses without a LISTER role can list assets and bridges
    // Note: will be set to true once Aztec Connect is no longer in BETA
    bool public allowThirdPartyContracts;

    // A mapping from an address to a boolean which indicates whether address is an approved rollup provider
    // @dev A rollup provider is an address which is allowed to call `processRollup(...)` out of escape hatch window.
    mapping(address => bool) public rollupProviders;

    // A mapping from interactionNonce to PendingDefiBridgeInteraction struct
    mapping(uint256 => PendingDefiBridgeInteraction) public pendingDefiInteractions;

    // A mapping from interactionNonce to ETH amount which was received for that interaction.
    // interaction
    mapping(uint256 => uint256) public ethPayments;

    // A mapping from an `assetId` to a gas limit
    mapping(uint256 => uint256) public assetGasLimits;

    // A mapping from a `bridgeAddressId` to a gas limit
    mapping(uint256 => uint256) public bridgeGasLimits;

    // A hash of hashes of pending DeFi interactions, the notes of which are expected to be added in the 'next' rollup
    bytes32 public prevDefiInteractionsHash;

    // The timestamp of the last rollup that was performed by a rollup provider
    uint32 public lastRollupTimeStamp;
    // The delay in seconds from `lastRollupTimeStamp` until the escape hatch can be used.
    uint32 public delayBeforeEscapeHatch;

    mapping(uint256 => AssetCap) public caps;

    /*----------------------------------------
      MODIFIERS
      ----------------------------------------*/

    /**
     * @notice A modifier reverting if this contract is paused
     */
    modifier whenNotPaused() {
        if (rollupState.paused) {
            revert PAUSED();
        }
        _;
    }


    /**
     * @notice A modifier reverting on any re-enter but allowing async to be called
     */
    modifier allowAsyncReenter() {
        if (rollupState.lock != Lock.UNLOCKED) {
            revert LOCKED_NO_REENTER();
        }
        rollupState.lock = Lock.ALLOW_ASYNC_REENTER;
        _;
        rollupState.lock = Lock.UNLOCKED;
    }


    /**
     * @notice A modifier which reverts if a given `_assetId` represents a virtual asset
     * @param _assetId 30-bit integer that describes the asset
     * @dev If _assetId's 29th bit is set, it represents a virtual asset with no ERC20 equivalent
     *      Virtual assets are used by the bridges to track non-token data. E.g. to represent a loan.
     *      If an _assetId is *not* a virtual asset, its ERC20 address can be recovered from
     *      `supportedAssets[_assetId]`
     */
    modifier validateAssetIdIsNotVirtual(uint256 _assetId) {
        if (_assetId > 0x1fffffff) {
            revert INVALID_ASSET_ID();
        }
        _;
    }

    /*----------------------------------------
      CONSTRUCTORS & INITIALIZERS
      ----------------------------------------*/
    /**
     * @notice Constructor sets escape hatch window and ensure that the implementation cannot be initialized
     * @param _escapeBlockLowerBound a block number which defines a start of the escape hatch window
     * @param _escapeBlockUpperBound a block number which defines an end of the escape hatch window
     */
    constructor(uint256 _escapeBlockLowerBound, uint256 _escapeBlockUpperBound) {
        if (_escapeBlockLowerBound == 0 || _escapeBlockLowerBound >= _escapeBlockUpperBound) {
            revert INVALID_ESCAPE_BOUNDS();
        }

        // Set storage in implementation.
        // Disable initializers to ensure no-one can call initialize on implementation directly
        // Pause to limit possibility for user error
        _disableInitializers();
        rollupState.paused = true;

        // Set immutables (part of code) so will be used in proxy calls as well
        escapeBlockLowerBound = _escapeBlockLowerBound;
        escapeBlockUpperBound = _escapeBlockUpperBound;
    }


    /**
     * @notice A function which processes a rollup
     * @dev Rollup processing consists of decoding a rollup, verifying the corresponding proof and updating relevant
     *      state variables
     * @dev The `encodedProofData` is unnamed param as we are reading it directly from calldata when decoding
     *      and creating the `proofData` in `Decoder::decodeProof()`.
     * @dev For the rollup to be processed `msg.sender` has to be an authorised rollup provider or escape hatch has
     *      to be open
     * @dev This function always transfers fees to the `rollupBeneficiary` encoded in the proof data
     *
     * @param - cryptographic proof data associated with a rollup
     * @param _signatures a byte array of secp256k1 ECDSA signatures, authorising a transfer of tokens from
     *                    the publicOwner for the particular inner proof in question
     *
     * Structure of each signature in the bytes array is:
     * 0x00 - 0x20 : r
     * 0x20 - 0x40 : s
     * 0x40 - 0x60 : v (in form: 0x0000....0001b for example)
     */
    function processRollup(bytes calldata, /* encodedProofData */ bytes calldata _signatures)
        external
        whenNotPaused
        allowAsyncReenter
    {
        (bytes memory proofData, uint256 numTxs, uint256 publicInputsHash) = decodeProof();
        address rollupBeneficiary = extractRollupBeneficiary(proofData);

        processRollupProof(proofData, _signatures, numTxs, publicInputsHash, rollupBeneficiary);

        transferFee(proofData, rollupBeneficiary);
    }

    /*----------------------------------------
      INTERNAL/PRIVATE MUTATING FUNCTIONS
      ----------------------------------------*/


    /**
     * @notice A function which decreases pending deposit amount in the `userPendingDeposits` mapping
     * @dev Implemented in assembly in order to reduce compiled bytecode size and improve gas costs
     * @param _assetId asset ID which was assigned during asset registration
     * @param _owner address that owns the pending deposit
     * @param _amount amount of tokens to decrease pending by
     */
    function decreasePendingDepositBalance(uint256 _assetId, address _owner, uint256 _amount)
        internal
        validateAssetIdIsNotVirtual(_assetId)
    {
        bool insufficientDeposit = false;
        assembly {
            // userPendingDeposit = userPendingDeposits[_assetId][_owner]
            mstore(0x00, _assetId)
            mstore(0x20, userPendingDeposits.slot)
            mstore(0x20, keccak256(0x00, 0x40))
            mstore(0x00, _owner)
            let userPendingDepositSlot := keccak256(0x00, 0x40)
            let userPendingDeposit := sload(userPendingDepositSlot)

            insufficientDeposit := lt(userPendingDeposit, _amount)

            let newDeposit := sub(userPendingDeposit, _amount)

            sstore(userPendingDepositSlot, newDeposit)
        }

        if (insufficientDeposit) {
            revert INSUFFICIENT_DEPOSIT();
        }
    }

    /**
     * @notice A function that processes a rollup proof
     * @dev Processing a rollup proof consists of:
     *          1) Verifying the proof's correctness,
     *          2) using the provided proof data to update rollup state + merkle roots,
     *          3) validate/enacting any deposits/withdrawals,
     *          4) processing bridge calls.
     * @param _proofData decoded rollup proof data
     * @param _signatures ECDSA signatures from users authorizing deposit transactions
     * @param _numTxs the number of transactions in the block
     * @param _publicInputsHash the SHA256 hash of the proof's public inputs
     * @param _rollupBeneficiary The address to be paid any subsidy for bridge calls and rollup fees
     */
    function processRollupProof(
        bytes memory _proofData,
        bytes memory _signatures,
        uint256 _numTxs,
        uint256 _publicInputsHash,
        address _rollupBeneficiary
    ) internal {
        uint256 rollupId = verifyProofAndUpdateState(_proofData, _publicInputsHash);
        processDepositsAndWithdrawals(_proofData, _numTxs, _signatures);
        bytes32[] memory nextDefiHashes = processBridgeCalls(_proofData, _rollupBeneficiary);
        emit RollupProcessed(rollupId, nextDefiHashes, msg.sender);
    }

    /**
     * @notice A function which verifies zk proof and updates the contract's state variables
     * @dev encodedProofData is read from calldata passed into the transaction and differs from `_proofData`
     * @param _proofData decoded rollup proof data
     * @param _publicInputsHash a hash of public inputs (computed by `Decoder.sol`)
     * @return rollupId id of the rollup which is being processed
     */
    function verifyProofAndUpdateState(bytes memory _proofData, uint256 _publicInputsHash)
        internal
        returns (uint256 rollupId)
    {
        // Verify the rollup proof.
        //
        // We manually call the verifier contract via assembly to save on gas costs and to reduce contract bytecode size
        assembly {
            /**
             * Validate correctness of zk proof.
             *
             * 1st Item is to format verifier calldata.
             *
             */

            // The `encodedProofData` (in calldata) contains the concatenation of
            // encoded 'broadcasted inputs' and the actual zk proof data.
            // (The `boadcasted inputs` is converted into a 32-byte SHA256 hash, which is
            // validated to equal the first public inputs of the zk proof. This is done in `Decoder.sol`).
            // We need to identify the location in calldata that points to the start of the zk proof data.

            // Step 1: compute size of zk proof data and its calldata pointer.
            /**
             * Data layout for `bytes encodedProofData`...
             *
             *             0x00 : 0x20 : length of array
             *             0x20 : 0x20 + header : root rollup header data
             *             0x20 + header : 0x24 + header : X, the length of encoded inner join-split public inputs
             *             0x24 + header : 0x24 + header + X : (inner join-split public inputs)
             *             0x24 + header + X : 0x28 + header + X : Y, the length of the zk proof data
             *             0x28 + header + X : 0x28 + haeder + X + Y : zk proof data
             *
             *             We need to recover the numeric value of `0x28 + header + X` and `Y`
             *
             */
            // Begin by getting length of encoded inner join-split public inputs.
            // `calldataload(0x04)` points to start of bytes array. Add 0x24 to skip over length param and function signature.
            // The calldata param 4 bytes *after* the header is the length of the pub inputs array. However it is a packed 4-byte param.
            // To extract it, we subtract 24 bytes from the calldata pointer and mask off all but the 4 least significant bytes.
            let encodedInnerDataSize :=
                and(calldataload(add(add(calldataload(0x04), 0x24), sub(ROLLUP_HEADER_LENGTH, 0x18))), 0xffffffff)

            // add 8 bytes to skip over the two packed params that follow the rollup header data
            // broadcastedDataSize = inner join-split pubinput size + header size
            let broadcastedDataSize := add(add(ROLLUP_HEADER_LENGTH, 8), encodedInnerDataSize)

            // Compute zk proof data size by subtracting broadcastedDataSize from overall length of bytes encodedProofsData
            let zkProofDataSize := sub(calldataload(add(calldataload(0x04), 0x04)), broadcastedDataSize)

            // Compute calldata pointer to start of zk proof data by adding calldata offset to broadcastedDataSize
            // (+0x24 skips over function signature and length param of bytes encodedProofData)
            let zkProofDataPtr := add(broadcastedDataSize, add(calldataload(0x04), 0x24))

            // Step 2: Format calldata for verifier contract call.

            // Get free memory pointer - we copy calldata into memory starting here
            let dataPtr := mload(0x40)

            // We call the function `verify(bytes,uint256)`
            // The function signature is 0xac318c5d
            // Calldata map is:
            // 0x00 - 0x04 : 0xac318c5d
            // 0x04 - 0x24 : 0x40 (number of bytes between 0x04 and the start of the `proofData` array at 0x44)
            // 0x24 - 0x44 : publicInputsHash
            // 0x44 - .... : proofData
            mstore8(dataPtr, 0xac)
            mstore8(add(dataPtr, 0x01), 0x31)
            mstore8(add(dataPtr, 0x02), 0x8c)
            mstore8(add(dataPtr, 0x03), 0x5d)
            mstore(add(dataPtr, 0x04), 0x40)
            mstore(add(dataPtr, 0x24), _publicInputsHash)
            mstore(add(dataPtr, 0x44), zkProofDataSize) // length of zkProofData bytes array
            calldatacopy(add(dataPtr, 0x64), zkProofDataPtr, zkProofDataSize) // copy the zk proof data into memory

            // Step 3: Call our verifier contract. It does not return any values, but will throw an error if the proof is not valid
            // i.e. verified == false if proof is not valid
            let verifierAddress := and(sload(rollupState.slot), ADDRESS_MASK)
            if iszero(extcodesize(verifierAddress)) {
                mstore(0, INVALID_ADDRESS_NO_CODE_SELECTOR)
                revert(0, 0x4)
            }
            let proof_verified := staticcall(gas(), verifierAddress, dataPtr, add(zkProofDataSize, 0x64), 0x00, 0x00)

            // Check the proof is valid!
            if iszero(proof_verified) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        // Validate and update state hash
        rollupId = validateAndUpdateMerkleRoots(_proofData);
    }

    /**
     * @notice Extracts roots from public inputs and validate that they are inline with current contract `rollupState`
     * @param _proofData decoded rollup proof data
     * @return rollup id
     * @dev To make the circuits happy, we want to only insert at the next subtree. The subtrees that we are using are
     *      28 leafs in size. They could be smaller but we just want them to be of same size for circuit related
     *      reasons.
     *          When we have the case that the `storedDataSize % numDataLeaves == 0`, we are perfectly dividing. This
     *      means that the incoming rollup matches perfectly with a boundry of the next subtree.
     *          When this is not the case, we have to compute an offset that we then apply so that the full state can
     *      be built with a bunch of same-sized trees (when the rollup is not full we insert a tree with some zero
     *      leaves). This offset can be computed as `numDataLeaves - (storedDataSize % numDataLeaves)` and is,
     *      essentially, how big a "space" we should leave so that the currently inserted subtree ends exactly at
     *      the subtree boundry. The value is always >= 0. In the function below we won’t hit the zero case, because
     *      that would be cought by the "if-branch".
     *
     *      Example: We have just had 32 rollups of size 28 (`storedDataSize = 896`). Now there is a small rollup with
     *      only 6 transactions. We are not perfectly dividing, hence we compute the offset as `6 - 896 % 6 = 4`.
     *      The start index is `896 + 4 = 900`. With the added leaves, the stored data size now becomes `906`.
     *          Now, comes another full rollup (28 txs). We compute `906 % 28 = 10`. The value is non-zero which means
     *      that we don’t perfectly divide and have to compute an offset `28 - 906 % 28 = 18`. The start index is
     *      `906 + 18 = 924`. Notice that `924 % 28 == 0`, so this will land us exactly at a location where everything
     *      in the past could have been subtrees of size 28.
     */
    function validateAndUpdateMerkleRoots(bytes memory _proofData) internal returns (uint256) {
        (uint256 rollupId, bytes32 oldStateHash, bytes32 newStateHash, uint32 numDataLeaves, uint32 dataStartIndex) =
            computeRootHashes(_proofData);

        if (oldStateHash != rollupStateHash) {
            revert INCORRECT_STATE_HASH(oldStateHash, newStateHash);
        }

        unchecked {
            uint32 storedDataSize = rollupState.datasize;
            // Ensure we are inserting at the next subtree boundary.
            if (storedDataSize % numDataLeaves == 0) {
                if (dataStartIndex != storedDataSize) {
                    revert INCORRECT_DATA_START_INDEX(dataStartIndex, storedDataSize);
                }
            } else {
                uint256 expected = storedDataSize + numDataLeaves - (storedDataSize % numDataLeaves);
                if (dataStartIndex != expected) {
                    revert INCORRECT_DATA_START_INDEX(dataStartIndex, expected);
                }
            }

            rollupStateHash = newStateHash;
            rollupState.datasize = dataStartIndex + numDataLeaves;
        }
        return rollupId;
    }

    /**
     * @notice A function which processes deposits and withdrawls
     * @param _proofData decoded rollup proof data
     * @param _numTxs number of transactions rolled up in the proof
     * @param _signatures byte array of secp256k1 ECDSA signatures, authorising a transfer of tokens
     */
    function processDepositsAndWithdrawals(bytes memory _proofData, uint256 _numTxs, bytes memory _signatures)
        internal
    {
        uint256 sigIndex = 0x00;
        uint256 proofDataPtr;
        uint256 end;
        assembly {
            // add 0x20 to skip over 1st member of the bytes type (the length field).
            // Also skip over the rollup header.
            proofDataPtr := add(ROLLUP_HEADER_LENGTH, add(_proofData, 0x20))

            // compute the position of proofDataPtr after we iterate through every transaction
            end := add(proofDataPtr, mul(_numTxs, TX_PUBLIC_INPUT_LENGTH))
        }

        // This is a bit of a hot loop, we iterate over every tx to determine whether to process deposits or withdrawals.
        while (proofDataPtr < end) {
            // extract the minimum information we need to determine whether to skip this iteration
            uint256 publicValue;
            assembly {
                publicValue := mload(add(proofDataPtr, 0xa0))
            }
            if (publicValue > 0) {
                uint256 proofId;
                uint256 assetId;
                address publicOwner;
                assembly {
                    proofId := mload(proofDataPtr)
                    assetId := mload(add(proofDataPtr, 0xe0))
                    publicOwner := mload(add(proofDataPtr, 0xc0))
                }

                if (proofId == 1) {
                    // validate user has approved deposit
                    bytes32 digest;
                    assembly {
                        // compute the tx id to check if user has approved tx
                        digest := keccak256(proofDataPtr, TX_PUBLIC_INPUT_LENGTH)
                    }
                    // check if there is an existing entry in depositProofApprovals
                    // if there is, no further work required.
                    // we don't need to clear `depositProofApprovals[publicOwner][digest]` because proofs cannot be re-used.
                    // A single proof describes the creation of 2 output notes and the addition of 2 input note nullifiers
                    // (both of these nullifiers can be categorised as "fake". They may not map to existing notes but are still inserted in the nullifier set)
                    // Replaying the proof will fail to satisfy the rollup circuit's non-membership check on the input nullifiers.
                    // We avoid resetting `depositProofApprovals` because that would cost additional gas post-London hard fork.
                    if (!depositProofApprovals[publicOwner][digest]) {
                        // extract and validate signature
                        // we can create a bytes memory container for the signature without allocating new memory,
                        // by overwriting the previous 32 bytes in the `signatures` array with the 'length' of our synthetic byte array (96)
                        // we store the memory we overwrite in `temp`, so that we can restore it
                        bytes memory signature;
                        uint256 temp;
                        assembly {
                            // set `signature` to point to 32 bytes less than the desired `r, s, v` values in `signatures`
                            signature := add(_signatures, sigIndex)
                            // cache the memory we're about to overwrite
                            temp := mload(signature)
                            // write in a 96-byte 'length' parameter into the `signature` bytes array
                            mstore(signature, 0x60)
                        }

                        bytes32 hashedMessage = RollupProcessorLibrary.getSignedMessageForTxId(digest);

                        RollupProcessorLibrary.validateShieldSignatureUnpacked(hashedMessage, signature, publicOwner);
                        // restore the memory we overwrote
                        assembly {
                            mstore(signature, temp)
                            sigIndex := add(sigIndex, 0x60)
                        }
                    }
                    decreasePendingDepositBalance(assetId, publicOwner, publicValue);
                }

                if (proofId == 2) {
                    withdraw(publicValue, publicOwner, assetId);
                }
            }
            // don't check for overflow, would take > 2^200 iterations of this loop for that to happen!
            unchecked {
                proofDataPtr += TX_PUBLIC_INPUT_LENGTH;
            }
        }
    }


    /**
     * @notice A function which transfers fees to the `_feeReceiver`
     * @dev Note: function will not revert if underlying transfers fails
     * @param _proofData decoded rollup proof data
     * @param _feeReceiver fee beneficiary as described by the rollup provider
     */
    function transferFee(bytes memory _proofData, address _feeReceiver) internal {
        for (uint256 i = 0; i < NUMBER_OF_ASSETS;) {
            uint256 txFee = extractTotalTxFee(_proofData, i);
            if (txFee > 0) {
                uint256 assetId = extractFeeAssetId(_proofData, i);
                if (assetId == ETH_ASSET_ID) {
                    // We explicitly do not throw if this call fails, as this opens up the possiblity of griefing
                    // attacks --> engineering a failed fee would invalidate an entire rollup block. As griefing could
                    // be done by consuming all gas in the `_feeReceiver` fallback only 50K gas is forwarded. We are
                    // forwarding a bit more gas than in the withdraw function because this code will only be hit
                    // at most once each rollup-block and we want to give the provider a bit more flexibility.
                    assembly {
                        pop(call(50000, _feeReceiver, txFee, 0, 0, 0, 0))
                    }
                } else {
                    address assetAddress = getSupportedAsset(assetId);
                    TokenTransfers.transferToDoNotBubbleErrors(
                        assetAddress, _feeReceiver, txFee, assetGasLimits[assetId]
                    );
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Internal utility function which withdraws funds from the contract to a receiver address
     * @param _withdrawValue - value being withdrawn from the contract
     * @param _receiver - address receiving public ERC20 tokens
     * @param _assetId - ID of the asset for which a withdrawal is being performed
     * @dev The function doesn't throw if the inner call fails, as this opens up the possiblity of griefing attacks
     *      -> engineering a failed withdrawal would invalidate an entire rollup block.
     *      A griefing attack could be done by consuming all gas in the `_receiver` fallback and for this reason we
     *      only forward 30K gas. This still allows the recipient to handle accounting if recipient is a contract.
     *      The user should ensure their withdrawal will succeed or they will lose the funds.
     */
    function withdraw(uint256 _withdrawValue, address _receiver, uint256 _assetId) internal {
        if (_receiver == address(0)) {
            revert WITHDRAW_TO_ZERO_ADDRESS();
        }
        if (_assetId == 0) {
            assembly {
                pop(call(30000, _receiver, _withdrawValue, 0, 0, 0, 0))
            }
            // payable(_receiver).call{gas: 30000, value: _withdrawValue}('');
        } else {
            address assetAddress = getSupportedAsset(_assetId);
            TokenTransfers.transferToDoNotBubbleErrors(
                assetAddress, _receiver, _withdrawValue, assetGasLimits[_assetId]
            );
        }
    }

    /**
     * @notice Gets the ERC20 token address of a supported asset for a given `_assetId`
     * @param _assetId identifier used to denote a particular asset
     * @return - the address of the matching asset
     */
    function getSupportedAsset(uint256 _assetId)
        internal
        view
        validateAssetIdIsNotVirtual(_assetId)
        returns (address)
    {
        // If assetId == ETH_ASSET_ID (i.e. 0), this represents native ETH.
        // ERC20 token asset id values start at 1
        if (_assetId == ETH_ASSET_ID) {
            return address(0x0);
        }
        address result = supportedAssets[_assetId - 1];
        if (result == address(0)) {
            revert INVALID_ASSET_ADDRESS();
        }
        return result;
    }


    /*----------------------------------------
      INTERNAL/PRIVATE NON-MUTATING FUNCTIONS
      ----------------------------------------*/

    /**
     * @notice A function which constructs a FullBridgeCallData struct based on values from `_encodedBridgeCallData`
     * @param _encodedBridgeCallData a bit-array that contains data describing a specific bridge call
     *
     * Structure of the bit array is as follows (starting at the least significant bit):
     * | bit range | parameter       | description |
     * | 0 - 32    | bridgeAddressId | The address ID. Bridge address = `supportedBridges[bridgeAddressId]` |
     * | 32 - 62   | inputAssetIdA   | First input asset ID. |
     * | 62 - 92   | inputAssetIdB   | Second input asset ID. Must be 0 if bridge does not have a 2nd input asset. |
     * | 92 - 122  | outputAssetIdA  | First output asset ID. |
     * | 122 - 152 | outputAssetIdB  | Second output asset ID. Must be 0 if bridge does not have a 2nd output asset. |
     * | 152 - 184 | bitConfig       | Bit-array that contains boolean bridge settings. |
     * | 184 - 248 | auxData         | 64 bits of custom data to be passed to the bridge contract. Structure of auxData
     *                                 is defined/checked by the bridge contract. |
     *
     * Structure of the `bitConfig` parameter is as follows
     * | bit | parameter               | description |
     * | 0   | secondInputInUse        | Does the bridge have a second input asset? |
     * | 1   | secondOutputInUse       | Does the bridge have a second output asset? |
     *
     * @dev Note: Virtual assets are assets that don't have an ERC20 token analogue and exist solely as notes within
     *            the Aztec network. They can be created/spent within bridge calls. They are used to enable bridges
     *            to track internally-defined data without having to mint a new token on-chain. An example use of
     *            a virtual asset would be a virtual loan asset that tracks an outstanding debt that must be repaid
     *            to recover a collateral deposited into the bridge.
     *
     * @return fullBridgeCallData a struct that contains information defining a specific bridge call
     */
    function getFullBridgeCallData(uint256 _encodedBridgeCallData)
        internal
        view
        returns (FullBridgeCallData memory fullBridgeCallData)
    {
        assembly {
            mstore(fullBridgeCallData, and(_encodedBridgeCallData, MASK_THIRTY_TWO_BITS)) // bridgeAddressId
            mstore(
                add(fullBridgeCallData, 0x40),
                and(shr(INPUT_ASSET_ID_A_SHIFT, _encodedBridgeCallData), MASK_THIRTY_BITS)
            ) // inputAssetIdA
            mstore(
                add(fullBridgeCallData, 0x60),
                and(shr(INPUT_ASSET_ID_B_SHIFT, _encodedBridgeCallData), MASK_THIRTY_BITS)
            ) // inputAssetIdB
            mstore(
                add(fullBridgeCallData, 0x80),
                and(shr(OUTPUT_ASSET_ID_A_SHIFT, _encodedBridgeCallData), MASK_THIRTY_BITS)
            ) // outputAssetIdA
            mstore(
                add(fullBridgeCallData, 0xa0),
                and(shr(OUTPUT_ASSET_ID_B_SHIFT, _encodedBridgeCallData), MASK_THIRTY_BITS)
            ) // outputAssetIdB
            mstore(
                add(fullBridgeCallData, 0xc0), and(shr(AUX_DATA_SHIFT, _encodedBridgeCallData), MASK_SIXTY_FOUR_BITS)
            ) // auxData

            mstore(
                add(fullBridgeCallData, 0xe0),
                and(shr(add(INPUT_ASSET_ID_A_SHIFT, VIRTUAL_ASSET_ID_FLAG_SHIFT), _encodedBridgeCallData), 1)
            ) // firstInputVirtual (30th bit of inputAssetIdA) == 1
            mstore(
                add(fullBridgeCallData, 0x100),
                and(shr(add(INPUT_ASSET_ID_B_SHIFT, VIRTUAL_ASSET_ID_FLAG_SHIFT), _encodedBridgeCallData), 1)
            ) // secondInputVirtual (30th bit of inputAssetIdB) == 1
            mstore(
                add(fullBridgeCallData, 0x120),
                and(shr(add(OUTPUT_ASSET_ID_A_SHIFT, VIRTUAL_ASSET_ID_FLAG_SHIFT), _encodedBridgeCallData), 1)
            ) // firstOutputVirtual (30th bit of outputAssetIdA) == 1
            mstore(
                add(fullBridgeCallData, 0x140),
                and(shr(add(OUTPUT_ASSET_ID_B_SHIFT, VIRTUAL_ASSET_ID_FLAG_SHIFT), _encodedBridgeCallData), 1)
            ) // secondOutputVirtual (30th bit of outputAssetIdB) == 1
            let bitConfig := and(shr(BITCONFIG_SHIFT, _encodedBridgeCallData), MASK_THIRTY_TWO_BITS)
            // bitConfig = bit mask that contains bridge ID settings
            // bit 0 = second input asset in use?
            // bit 1 = second output asset in use?
            mstore(add(fullBridgeCallData, 0x160), eq(and(bitConfig, 1), 1)) // secondInputInUse (bitConfig & 1) == 1
            mstore(add(fullBridgeCallData, 0x180), eq(and(shr(1, bitConfig), 1), 1)) // secondOutputInUse ((bitConfig >> 1) & 1) == 1
        }
        fullBridgeCallData.bridgeAddress = supportedBridges[fullBridgeCallData.bridgeAddressId - 1];
        fullBridgeCallData.bridgeGasLimit = bridgeGasLimits[fullBridgeCallData.bridgeAddressId];

        // potential conflicting states that are explicitly ruled out by circuit constraints:
        if (!fullBridgeCallData.secondInputInUse && fullBridgeCallData.inputAssetIdB > 0) {
            revert INCONSISTENT_BRIDGE_CALL_DATA();
        }
        if (!fullBridgeCallData.secondOutputInUse && fullBridgeCallData.outputAssetIdB > 0) {
            revert INCONSISTENT_BRIDGE_CALL_DATA();
        }
        if (
            fullBridgeCallData.secondInputInUse
                && (fullBridgeCallData.inputAssetIdA == fullBridgeCallData.inputAssetIdB)
        ) {
            revert BRIDGE_WITH_IDENTICAL_INPUT_ASSETS(fullBridgeCallData.inputAssetIdA);
        }
        // Outputs can both be virtual. In that case, their asset ids will both be 2 ** 29.
        bool secondOutputReal = fullBridgeCallData.secondOutputInUse && !fullBridgeCallData.secondOutputVirtual;
        if (secondOutputReal && fullBridgeCallData.outputAssetIdA == fullBridgeCallData.outputAssetIdB) {
            revert BRIDGE_WITH_IDENTICAL_OUTPUT_ASSETS(fullBridgeCallData.outputAssetIdA);
        }
    }

    /**
     * @notice Gets the four input/output assets associated with a specific bridge call
     * @param _fullBridgeCallData a struct that contains information defining a specific bridge call
     * @param _interactionNonce interaction nonce of a corresponding bridge call
     * @dev `_interactionNonce` param is here because it is used as an ID of output virtual asset
     *
     * @return inputAssetA the first input asset
     * @return inputAssetB the second input asset
     * @return outputAssetA the first output asset
     * @return outputAssetB the second output asset
     */
    function getAztecAssetTypes(FullBridgeCallData memory _fullBridgeCallData, uint256 _interactionNonce)
        internal
        view
        returns (
            AztecTypes.AztecAsset memory inputAssetA,
            AztecTypes.AztecAsset memory inputAssetB,
            AztecTypes.AztecAsset memory outputAssetA,
            AztecTypes.AztecAsset memory outputAssetB
        )
    {
        if (_fullBridgeCallData.firstInputVirtual) {
            // asset id is a nonce of the interaction in which the virtual asset was created
            inputAssetA.id = _fullBridgeCallData.inputAssetIdA - VIRTUAL_ASSET_ID_FLAG;
            inputAssetA.erc20Address = address(0x0);
            inputAssetA.assetType = AztecTypes.AztecAssetType.VIRTUAL;
        } else {
            inputAssetA.id = _fullBridgeCallData.inputAssetIdA;
            inputAssetA.erc20Address = getSupportedAsset(_fullBridgeCallData.inputAssetIdA);
            inputAssetA.assetType = inputAssetA.erc20Address == address(0x0)
                ? AztecTypes.AztecAssetType.ETH
                : AztecTypes.AztecAssetType.ERC20;
        }
        if (_fullBridgeCallData.firstOutputVirtual) {
            // use nonce as asset id.
            outputAssetA.id = _interactionNonce;
            outputAssetA.erc20Address = address(0x0);
            outputAssetA.assetType = AztecTypes.AztecAssetType.VIRTUAL;
        } else {
            outputAssetA.id = _fullBridgeCallData.outputAssetIdA;
            outputAssetA.erc20Address = getSupportedAsset(_fullBridgeCallData.outputAssetIdA);
            outputAssetA.assetType = outputAssetA.erc20Address == address(0x0)
                ? AztecTypes.AztecAssetType.ETH
                : AztecTypes.AztecAssetType.ERC20;
        }

        if (_fullBridgeCallData.secondInputVirtual) {
            // asset id is a nonce of the interaction in which the virtual asset was created
            inputAssetB.id = _fullBridgeCallData.inputAssetIdB - VIRTUAL_ASSET_ID_FLAG;
            inputAssetB.erc20Address = address(0x0);
            inputAssetB.assetType = AztecTypes.AztecAssetType.VIRTUAL;
        } else if (_fullBridgeCallData.secondInputInUse) {
            inputAssetB.id = _fullBridgeCallData.inputAssetIdB;
            inputAssetB.erc20Address = getSupportedAsset(_fullBridgeCallData.inputAssetIdB);
            inputAssetB.assetType = inputAssetB.erc20Address == address(0x0)
                ? AztecTypes.AztecAssetType.ETH
                : AztecTypes.AztecAssetType.ERC20;
        } else {
            inputAssetB.id = 0;
            inputAssetB.erc20Address = address(0x0);
            inputAssetB.assetType = AztecTypes.AztecAssetType.NOT_USED;
        }

        if (_fullBridgeCallData.secondOutputVirtual) {
            // use nonce as asset id.
            outputAssetB.id = _interactionNonce;
            outputAssetB.erc20Address = address(0x0);
            outputAssetB.assetType = AztecTypes.AztecAssetType.VIRTUAL;
        } else if (_fullBridgeCallData.secondOutputInUse) {
            outputAssetB.id = _fullBridgeCallData.outputAssetIdB;
            outputAssetB.erc20Address = getSupportedAsset(_fullBridgeCallData.outputAssetIdB);
            outputAssetB.assetType = outputAssetB.erc20Address == address(0x0)
                ? AztecTypes.AztecAssetType.ETH
                : AztecTypes.AztecAssetType.ERC20;
        } else {
            outputAssetB.id = 0;
            outputAssetB.erc20Address = address(0x0);
            outputAssetB.assetType = AztecTypes.AztecAssetType.NOT_USED;
        }
    }

    /**
     * @notice Gets the length of the defi interaction hashes array and the number of pending interactions
     *
     * @return defiInteractionHashesLength the complete length of the defi interaction array
     * @return numPendingInteractions the current number of pending defi interactions
     * @dev `numPendingInteractions` is capped at `NUMBER_OF_BRIDGE_CALLS`
     */
    function getDefiHashesLengthsAndNumPendingInteractions()
        internal
        view
        returns (uint256 defiInteractionHashesLength, uint256 numPendingInteractions)
    {
        assembly {
            // retrieve the total length of the defi interactions array and also the number of pending interactions to a maximum of NUMBER_OF_BRIDGE_CALLS
            let state := sload(rollupState.slot)
            {
                defiInteractionHashesLength := and(ARRAY_LENGTH_MASK, shr(DEFIINTERACTIONHASHES_BIT_OFFSET, state))
                numPendingInteractions := defiInteractionHashesLength
                if gt(numPendingInteractions, NUMBER_OF_BRIDGE_CALLS) {
                    numPendingInteractions := NUMBER_OF_BRIDGE_CALLS
                }
            }
        }
    }

    /**
     * @notice Gets the set of hashes that comprise the current pending interactions and nextExpectedHash
     *
     * @return hashes the set of valid (i.e. non-zero) hashes that comprise the pending interactions
     * @return nextExpectedHash the hash of all hashes (including zero hashes) that comprise the pending interactions
     */
    function getPendingAndNextExpectedHashes()
        internal
        view
        returns (bytes32[] memory hashes, bytes32 nextExpectedHash)
    {
        /**
         * ----------------------------------------
         * Compute nextExpectedHash
         * -----------------------------------------
         *
         * The `defiInteractionHashes` mapping emulates an array that represents the
         * set of defi interactions from previous blocks that have been resolved.
         *
         * We need to take the interaction result data from each of the above defi interactions,
         * and add that data into the Aztec L2 merkle tree that contains defi interaction results
         * (the "Defi Tree". Its merkle root is one of the inputs to the storage variable `rollupStateHash`)
         *
         * It is the rollup provider's responsibility to perform these additions.
         * In the current block being processed, the rollup provider must take these pending interaction results,
         * create commitments to each result and insert each commitment into the next empty leaf of the defi tree.
         *
         * The following code validates that this has happened! This is how:
         *
         * Part 1: What are we checking?
         *
         * The rollup circuit will receive, as a private input from the rollup provider, the pending defi interaction
         * results
         * (`encodedBridgeCallData`, `totalInputValue`, `totalOutputValueA`, `totalOutputValueB`, `result`)
         * The rollup circuit will compute the SHA256 hash of each interaction result (the defiInteractionHash)
         * Finally the SHA256 hash of `NUMBER_OF_BRIDGE_CALLS` of these defiInteractionHash values is computed.
         * (if there are fewer than `NUMBER_OF_BRIDGE_CALLS` pending defi interaction results, the SHA256 hash of
         * an empty defi interaction result is used instead. i.e. all variable values are set to 0)
         * The computed SHA256 hash, the `pendingDefiInteractionHash`, is one of the broadcasted values that forms
         * the `publicInputsHash` public input to the rollup circuit.
         * When verifying a rollup proof, this smart contract will compute `publicInputsHash` from the input calldata.
         * The PLONK Verifier smart contract will then validate that our computed value for `publicInputHash` matches
         * the value used when generating the rollup proof.
         *
         * TLDR of the above: our proof data contains a variable called `pendingDefiInteractionHash`, which is
         * the CLAIMED VALUE of SHA256 hashing the SHA256 hashes of the defi interactions that have resolved but whose
         * data has not yet been added into the defi tree.
         *
         * Part 2: How do we check `pendingDefiInteractionHash` is correct???
         *
         * This contract will call `DefiBridgeProxy.convert` (via delegatecall) on every new defi interaction present
         * in the block. The return values from the bridge proxy contract are used to construct a defi interaction
         * result. Its hash is then computed and stored in `defiInteractionHashes`.
         *
         * N.B. It's very important that DefiBridgeProxy does not call selfdestruct, or makes a delegatecall out to
         *      a contract that can selfdestruct :o
         *
         * Similarly, when async defi interactions resolve, the interaction result is stored in
         * `asyncDefiInteractionHashes`. At the end of the processBridgeCalls function, the contents of the async array
         * is copied into `defiInteractionHashes` (i.e. async interaction results are delayed by 1 rollup block.
         * This is to prevent griefing attacks where the rollup state changes between the time taken for a rollup tx
         * to be constructed and the rollup tx to be mined)
         *
         * We use the contents of `defiInteractionHashes` to reconstruct `pendingDefiInteractionHash`, and validate it
         * matches the value present in calldata and therefore the value used in the rollup circuit when this block's
         * rollup proof was constructed. This validates that all of the required defi interaction results were added
         * into the defi tree by the rollup provider (the circuit logic enforces this, we just need to check the rollup
         * provider used the correct inputs)
         */
        (uint256 defiInteractionHashesLength, uint256 numPendingInteractions) =
            getDefiHashesLengthsAndNumPendingInteractions();
        uint256 offset = defiInteractionHashesLength - numPendingInteractions;
        assembly {
            // allocate the output array of hashes
            hashes := mload(0x40)
            let hashData := add(hashes, 0x20)
            // update the free memory pointer to point past the end of our array
            // our array will consume 32 bytes for the length field plus NUMBER_OF_BRIDGE_BYTES for all of the hashes
            mstore(0x40, add(hashes, add(NUMBER_OF_BRIDGE_BYTES, 0x20)))
            // set the length of hashes to only include the non-zero hash values
            // although this function will write all of the hashes into our allocated memory, we only want to return the non-zero hashes
            mstore(hashes, numPendingInteractions)

            // Prepare the reusable part of the defi interaction hashes slot computation
            mstore(0x20, defiInteractionHashes.slot)
            let i := 0

            // Iterate over numPendingInteractions (will be between 0 and NUMBER_OF_BRIDGE_CALLS)
            // Load defiInteractionHashes[offset + i] and store in memory
            // in order to compute SHA2 hash (nextExpectedHash)
            for {} lt(i, numPendingInteractions) { i := add(i, 0x01) } {
                // hashData[i] = defiInteractionHashes[offset + i]
                mstore(0x00, add(offset, i))
                mstore(add(hashData, mul(i, 0x20)), sload(keccak256(0x00, 0x40)))
            }

            // If numPendingInteractions < NUMBER_OF_BRIDGE_CALLS, continue iterating up to NUMBER_OF_BRIDGE_CALLS, this time
            // inserting the "zero hash", the result of sha256(emptyDefiInteractionResult)
            for {} lt(i, NUMBER_OF_BRIDGE_CALLS) { i := add(i, 0x01) } {
                // hashData[i] = DEFI_RESULT_ZERO_HASH
                mstore(add(hashData, mul(i, 0x20)), DEFI_RESULT_ZERO_HASH)
            }
            pop(staticcall(gas(), 0x2, hashData, NUMBER_OF_BRIDGE_BYTES, 0x00, 0x20))
            nextExpectedHash := mod(mload(0x00), CIRCUIT_MODULUS)
        }
    }

    /**
     * @notice A function that processes bridge calls.
     * @dev 1. pop NUMBER_OF_BRIDGE_CALLS (if available) interaction hashes off of `defiInteractionHashes`,
     *         validate their hash (calculated at the end of the previous rollup and stored as
     *         nextExpectedDefiInteractionsHash) equals `numPendingInteractions` (this validates that rollup block
     *         has added these interaction results into the L2 data tree)
     *      2. iterate over rollup block's new defi interactions (up to NUMBER_OF_BRIDGE_CALLS). Trigger interactions
     *         by calling DefiBridgeProxy contract. Record results in either `defiInteractionHashes` (for synchrohnous
     *         txns) or, for async txns, the `pendingDefiInteractions` mapping
     *      3. copy the contents of `asyncInteractionHashes` into `defiInteractionHashes` && clear
     *         `asyncInteractionHashes`
     *      4. calculate the next value of nextExpectedDefiInteractionsHash from the new set of defiInteractionHashes
     * @param _proofData decoded rollup proof data
     * @param _rollupBeneficiary the address that should be paid any subsidy for processing a bridge call
     * @return nextExpectedHashes the set of non-zero hashes that comprise the current pending defi interactions
     */
    function processBridgeCalls(bytes memory _proofData, address _rollupBeneficiary)
        internal
        returns (bytes32[] memory nextExpectedHashes)
    {
        uint256 defiInteractionHashesLength;
        // Verify that nextExpectedDefiInteractionsHash equals the value given in the rollup
        // Then remove the set of pending hashes
        {
            // Extract the claimed value of previousDefiInteractionHash present in the proof data
            bytes32 providedDefiInteractionsHash = extractPrevDefiInteractionHash(_proofData);

            // Validate the stored interactionHash matches the value used when making the rollup proof!
            if (providedDefiInteractionsHash != prevDefiInteractionsHash) {
                revert INCORRECT_PREVIOUS_DEFI_INTERACTION_HASH(providedDefiInteractionsHash, prevDefiInteractionsHash);
            }
            uint256 numPendingInteractions;
            (defiInteractionHashesLength, numPendingInteractions) = getDefiHashesLengthsAndNumPendingInteractions();
            // numPendingInteraction equals the number of interactions expected to be in the given rollup
            // this is the length of the defiInteractionHashes array, capped at the NUM_BRIDGE_CALLS as per the following
            // numPendingInteractions = min(defiInteractionsHashesLength, numberOfBridgeCalls)

            // Reduce DefiInteractionHashes.length by numPendingInteractions
            defiInteractionHashesLength -= numPendingInteractions;

            assembly {
                // Update DefiInteractionHashes.length in storage
                let state := sload(rollupState.slot)
                let oldState := and(not(shl(DEFIINTERACTIONHASHES_BIT_OFFSET, ARRAY_LENGTH_MASK)), state)
                let newState := or(oldState, shl(DEFIINTERACTIONHASHES_BIT_OFFSET, defiInteractionHashesLength))
                sstore(rollupState.slot, newState)
            }
        }
        uint256 interactionNonce = getRollupId(_proofData) * NUMBER_OF_BRIDGE_CALLS;

        // ### Process bridge calls
        uint256 proofDataPtr;
        assembly {
            proofDataPtr := add(_proofData, BRIDGE_CALL_DATAS_OFFSET)
        }
        BridgeResult memory bridgeResult;
        assembly {
            bridgeResult := mload(0x40)
            mstore(0x40, add(bridgeResult, 0x80))
        }
        for (uint256 i = 0; i < NUMBER_OF_BRIDGE_CALLS;) {
            uint256 encodedBridgeCallData;
            assembly {
                encodedBridgeCallData := mload(proofDataPtr)
            }
            if (encodedBridgeCallData == 0) {
                // no more bridges to call
                break;
            }
            uint256 totalInputValue;
            assembly {
                totalInputValue := mload(add(proofDataPtr, mul(0x20, NUMBER_OF_BRIDGE_CALLS)))
            }
            if (totalInputValue == 0) {
                revert ZERO_TOTAL_INPUT_VALUE();
            }

            FullBridgeCallData memory fullBridgeCallData = getFullBridgeCallData(encodedBridgeCallData);

            (
                AztecTypes.AztecAsset memory inputAssetA,
                AztecTypes.AztecAsset memory inputAssetB,
                AztecTypes.AztecAsset memory outputAssetA,
                AztecTypes.AztecAsset memory outputAssetB
            ) = getAztecAssetTypes(fullBridgeCallData, interactionNonce);
            assembly {
                // call the following function of DefiBridgeProxy via delegatecall...
                //     function convert(
                //          address bridgeAddress,
                //          AztecTypes.AztecAsset calldata inputAssetA,
                //          AztecTypes.AztecAsset calldata inputAssetB,
                //          AztecTypes.AztecAsset calldata outputAssetA,
                //          AztecTypes.AztecAsset calldata outputAssetB,
                //          uint256 totalInputValue,
                //          uint256 interactionNonce,
                //          uint256 auxInputData,
                //          uint256 ethPaymentsSlot,
                //          address rollupBeneficary
                //     )

                // Construct the calldata we send to DefiBridgeProxy
                // mPtr = memory pointer. Set to free memory location (0x40)
                let mPtr := mload(0x40)
                // first 4 bytes is the function signature
                mstore(mPtr, DEFI_BRIDGE_PROXY_CONVERT_SELECTOR)
                mPtr := add(mPtr, 0x04)

                let bridgeAddress := mload(add(fullBridgeCallData, 0x20))
                mstore(mPtr, bridgeAddress)
                mstore(add(mPtr, 0x20), mload(inputAssetA))
                mstore(add(mPtr, 0x40), mload(add(inputAssetA, 0x20)))
                mstore(add(mPtr, 0x60), mload(add(inputAssetA, 0x40)))
                mstore(add(mPtr, 0x80), mload(inputAssetB))
                mstore(add(mPtr, 0xa0), mload(add(inputAssetB, 0x20)))
                mstore(add(mPtr, 0xc0), mload(add(inputAssetB, 0x40)))
                mstore(add(mPtr, 0xe0), mload(outputAssetA))
                mstore(add(mPtr, 0x100), mload(add(outputAssetA, 0x20)))
                mstore(add(mPtr, 0x120), mload(add(outputAssetA, 0x40)))
                mstore(add(mPtr, 0x140), mload(outputAssetB))
                mstore(add(mPtr, 0x160), mload(add(outputAssetB, 0x20)))
                mstore(add(mPtr, 0x180), mload(add(outputAssetB, 0x40)))
                mstore(add(mPtr, 0x1a0), totalInputValue)
                mstore(add(mPtr, 0x1c0), interactionNonce)

                let auxData := mload(add(fullBridgeCallData, 0xc0))
                mstore(add(mPtr, 0x1e0), auxData)
                mstore(add(mPtr, 0x200), ethPayments.slot)
                mstore(add(mPtr, 0x220), _rollupBeneficiary)

                // Call the bridge proxy via delegatecall!
                // We want the proxy to share state with the rollup processor, as the proxy is the entity
                // sending/recovering tokens from the bridge contracts. We wrap this logic in a delegatecall so that
                // if the call fails (i.e. the bridge interaction fails), we can unwind bridge-interaction specific
                // state changes without reverting the entire transaction.
                let bridgeProxy := sload(defiBridgeProxy.slot)
                if iszero(extcodesize(bridgeProxy)) {
                    mstore(0, INVALID_ADDRESS_NO_CODE_SELECTOR)
                    revert(0, 0x4)
                }
                let success :=
                    delegatecall(
                        mload(add(fullBridgeCallData, 0x1a0)), // fullBridgeCallData.bridgeGasLimit
                        bridgeProxy,
                        sub(mPtr, 0x04),
                        0x244,
                        0,
                        0
                    )
                returndatacopy(mPtr, 0, returndatasize())

                switch success
                case 1 {
                    mstore(bridgeResult, mload(mPtr)) // outputValueA
                    mstore(add(bridgeResult, 0x20), mload(add(mPtr, 0x20))) // outputValueB
                    mstore(add(bridgeResult, 0x40), mload(add(mPtr, 0x40))) // isAsync
                    mstore(add(bridgeResult, 0x60), 1) // success
                }
                default {
                    // If the call failed, mark this interaction as failed. No tokens have been exchanged, users can
                    // use the "claim" circuit to recover the initial tokens they sent to the bridge
                    mstore(bridgeResult, 0) // outputValueA
                    mstore(add(bridgeResult, 0x20), 0) // outputValueB
                    mstore(add(bridgeResult, 0x40), 0) // isAsync
                    mstore(add(bridgeResult, 0x60), 0) // success
                }
            }

            if (!fullBridgeCallData.secondOutputInUse) {
                bridgeResult.outputValueB = 0;
            }

            // emit events and update state
            assembly {
                // if interaction is Async, update pendingDefiInteractions
                // if interaction is synchronous, compute the interaction hash and add to defiInteractionHashes
                switch mload(add(bridgeResult, 0x40))
                // switch isAsync
                case 1 {
                    let mPtr := mload(0x40)
                    // emit AsyncDefiBridgeProcessed(indexed encodedBridgeCallData, indexed interactionNonce, totalInputValue)
                    {
                        mstore(mPtr, totalInputValue)
                        log3(mPtr, 0x20, ASYNC_BRIDGE_PROCESSED_SIGHASH, encodedBridgeCallData, interactionNonce)
                    }
                    // pendingDefiInteractions[interactionNonce] = PendingDefiBridgeInteraction(encodedBridgeCallData, totalInputValue)
                    mstore(0x00, interactionNonce)
                    mstore(0x20, pendingDefiInteractions.slot)
                    let pendingDefiInteractionsSlotBase := keccak256(0x00, 0x40)

                    sstore(pendingDefiInteractionsSlotBase, encodedBridgeCallData)
                    sstore(add(pendingDefiInteractionsSlotBase, 0x01), totalInputValue)
                }
                default {
                    let mPtr := mload(0x40)
                    // prepare the data required to publish the DefiBridgeProcessed event, we will only publish it if
                    // isAsync == false
                    // async interactions that have failed, have their isAsync property modified to false above
                    // emit DefiBridgeProcessed(indexed encodedBridgeCallData, indexed interactionNonce, totalInputValue, outputValueA, outputValueB, success)

                    {
                        mstore(mPtr, totalInputValue)
                        mstore(add(mPtr, 0x20), mload(bridgeResult)) // outputValueA
                        mstore(add(mPtr, 0x40), mload(add(bridgeResult, 0x20))) // outputValueB
                        mstore(add(mPtr, 0x60), mload(add(bridgeResult, 0x60))) // success
                        mstore(add(mPtr, 0x80), 0xa0) // position in event data block of `bytes` object

                        if mload(add(bridgeResult, 0x60)) {
                            mstore(add(mPtr, 0xa0), 0)
                            log3(mPtr, 0xc0, DEFI_BRIDGE_PROCESSED_SIGHASH, encodedBridgeCallData, interactionNonce)
                        }
                        if iszero(mload(add(bridgeResult, 0x60))) {
                            mstore(add(mPtr, 0xa0), returndatasize())
                            let size := returndatasize()
                            let remainder := mul(iszero(iszero(size)), sub(32, mod(size, 32)))
                            returndatacopy(add(mPtr, 0xc0), 0, size)
                            mstore(add(mPtr, add(0xc0, size)), 0)
                            log3(
                                mPtr,
                                add(0xc0, add(size, remainder)),
                                DEFI_BRIDGE_PROCESSED_SIGHASH,
                                encodedBridgeCallData,
                                interactionNonce
                            )
                        }
                    }
                    // compute defiInteractionnHash
                    mstore(mPtr, encodedBridgeCallData)
                    mstore(add(mPtr, 0x20), interactionNonce)
                    mstore(add(mPtr, 0x40), totalInputValue)
                    mstore(add(mPtr, 0x60), mload(bridgeResult)) // outputValueA
                    mstore(add(mPtr, 0x80), mload(add(bridgeResult, 0x20))) // outputValueB
                    mstore(add(mPtr, 0xa0), mload(add(bridgeResult, 0x60))) // success
                    pop(staticcall(gas(), 0x2, mPtr, 0xc0, 0x00, 0x20))
                    let defiInteractionHash := mod(mload(0x00), CIRCUIT_MODULUS)

                    // defiInteractionHashes[defiInteractionHashesLength] = defiInteractionHash;
                    mstore(0x00, defiInteractionHashesLength)
                    mstore(0x20, defiInteractionHashes.slot)
                    sstore(keccak256(0x00, 0x40), defiInteractionHash)

                    // Increase the length of defiInteractionHashes by 1
                    defiInteractionHashesLength := add(defiInteractionHashesLength, 0x01)
                }

                // advance interactionNonce and proofDataPtr
                interactionNonce := add(interactionNonce, 0x01)
                proofDataPtr := add(proofDataPtr, 0x20)
            }
            unchecked {
                ++i;
            }
        }

        assembly {
            /**
             * Cleanup
             *
             * 1. Copy asyncDefiInteractionHashes into defiInteractionHashes
             * 2. Update defiInteractionHashes.length
             * 2. Clear asyncDefiInteractionHashes.length
             */
            let state := sload(rollupState.slot)

            let asyncDefiInteractionHashesLength :=
                and(ARRAY_LENGTH_MASK, shr(ASYNCDEFIINTERACTIONHASHES_BIT_OFFSET, state))

            // Validate we are not overflowing our 1024 array size
            let arrayOverflow :=
                gt(add(asyncDefiInteractionHashesLength, defiInteractionHashesLength), ARRAY_LENGTH_MASK)

            // Throw an error if defiInteractionHashesLength > ARRAY_LENGTH_MASK (i.e. is >= 1024)
            // should never hit this! If block `i` generates synchronous txns,
            // block 'i + 1' must process them.
            // Only way this array size hits 1024 is if we produce a glut of async interaction results
            // between blocks. HOWEVER we ensure that async interaction callbacks fail if they would increase
            // defiInteractionHashes length to be >= 512
            // Still, can't hurt to check...
            if arrayOverflow {
                mstore(0, ARRAY_OVERFLOW_SELECTOR)
                revert(0, 0x4)
            }

            // Now, copy async hashes into defiInteractionHashes

            // Cache the free memory pointer
            let freePtr := mload(0x40)

            // Prepare the reusable parts of slot computation
            mstore(0x20, defiInteractionHashes.slot)
            mstore(0x60, asyncDefiInteractionHashes.slot)
            for { let i := 0 } lt(i, asyncDefiInteractionHashesLength) { i := add(i, 1) } {
                // defiInteractionHashesLength[defiInteractionHashesLength + i] = asyncDefiInteractionHashes[i]
                mstore(0x00, add(defiInteractionHashesLength, i))
                mstore(0x40, i)
                sstore(keccak256(0x00, 0x40), sload(keccak256(0x40, 0x40)))
            }
            // Restore the free memory pointer
            mstore(0x40, freePtr)

            // clear defiInteractionHashesLength in state
            state := and(not(shl(DEFIINTERACTIONHASHES_BIT_OFFSET, ARRAY_LENGTH_MASK)), state)

            // write new defiInteractionHashesLength in state
            state :=
                or(
                    shl(
                        DEFIINTERACTIONHASHES_BIT_OFFSET, add(asyncDefiInteractionHashesLength, defiInteractionHashesLength)
                    ),
                    state
                )

            // clear asyncDefiInteractionHashesLength in state
            state := and(not(shl(ASYNCDEFIINTERACTIONHASHES_BIT_OFFSET, ARRAY_LENGTH_MASK)), state)

            // write new state
            sstore(rollupState.slot, state)
        }

        // now we want to extract the next set of pending defi interaction hashes and calculate their hash to store
        // for the next rollup
        (bytes32[] memory hashes, bytes32 nextExpectedHash) = getPendingAndNextExpectedHashes();
        nextExpectedHashes = hashes;
        prevDefiInteractionsHash = nextExpectedHash;
    }
}
