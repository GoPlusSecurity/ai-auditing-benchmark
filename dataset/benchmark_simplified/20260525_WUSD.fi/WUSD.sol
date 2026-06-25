// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;


struct Snapshot
{
  uint32 epoch;
  uint112 last;
  uint112 cumulative;
}


interface IERC20
{
  function name () external view returns (string memory);

  function symbol () external view returns (string memory);

  function decimals () external view returns (uint8);

  function totalSupply () external view returns (uint256);

  function balanceOf (address account) external view returns (uint256);


  function allowance (address owner, address spender) external view returns (uint256);

  function approve (address spender, uint256 amount) external returns (bool);


  function transfer (address to, uint256 amount) external returns (bool);

  function transferFrom (address from, address to, uint256 amount) external returns (bool);


  function mint (address account, uint256 amount) external;

  function burn (address account, uint256 amount) external;
}


interface IGlove
{
  function balanceOf (address account) external view returns (uint256);


  function creditOf (address account) external view returns (uint256);

  function creditlessOf (address account) external view returns (uint256);


  function transfer (address to, uint256 amount) external returns (bool);

  function transferFrom (address from, address to, uint256 amount) external returns (bool);

  function transferCreditless (address to, uint256 amount) external returns (bool);


  function mint (address account, uint256 amount) external;

  function mintCreditless (address account, uint256 amount) external;

  function creditize (address account, uint256 credits) external returns (bool);


  function burn (address account, uint256 amount) external;

  function decreditize (address account, uint256 credits) external returns (bool);
}


interface IRegistry
{
  function get (string calldata name) external view returns (address);


  function provisioner () external view returns (address);

  function frontender () external view returns (address);

  function collector () external view returns (address);
}


interface IFrontender
{
  function isRegistered (address account) external view returns (bool);

  function refer (address account, uint256 amount, address referrer) external;
}


interface IUniswapV3SwapCallback
{
  function uniswapV3SwapCallback (int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}


interface ISwapRouter is IUniswapV3SwapCallback
{
  struct ExactInputSingleParams
  {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
  }

  function exactInputSingle (ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

  struct ExactInputParams
  {
    bytes path;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
  }

  function exactInput (ExactInputParams calldata params) external payable returns (uint256 amountOut);

  struct ExactOutputSingleParams
  {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountOut;
    uint256 amountInMaximum;
    uint160 sqrtPriceLimitX96;
  }

  function exactOutputSingle (ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

  struct ExactOutputParams
  {
    bytes path;
    address recipient;
    uint256 deadline;
    uint256 amountOut;
    uint256 amountInMaximum;
  }

  function exactOutput (ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}


library Math
{
  enum Rounding
  {
    Down,
    Up,
    Zero
  }

  function max (uint256 a, uint256 b) internal pure returns (uint256)
  {
    return a > b ? a : b;
  }

  function min (uint256 a, uint256 b) internal pure returns (uint256)
  {
    return a < b ? a : b;
  }

  function average (uint256 a, uint256 b) internal pure returns (uint256)
  {
    return (a & b) + (a ^ b) / 2;
  }

  function ceilDiv (uint256 a, uint256 b) internal pure returns (uint256)
  {
    return a == 0 ? 0 : (a - 1) / b + 1;
  }

  function mulDiv (uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result)
  {
    unchecked
    {
      uint256 prod0;
      uint256 prod1;

      assembly
      {
        let mm := mulmod(x, y, not(0))
        prod0 := mul(x, y)
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
      }

      if (prod1 == 0)
      {
        return prod0 / denominator;
      }

      require(denominator > prod1);

      uint256 remainder;

      assembly
      {
        remainder := mulmod(x, y, denominator)
        prod1 := sub(prod1, gt(remainder, prod0))
        prod0 := sub(prod0, remainder)
      }

      uint256 twos = denominator & (~denominator + 1);

      assembly
      {
        denominator := div(denominator, twos)
        prod0 := div(prod0, twos)
        twos := add(div(sub(0, twos), twos), 1)
      }

      prod0 |= prod1 * twos;

      uint256 inverse = (3 * denominator) ^ 2;

      inverse *= 2 - denominator * inverse;
      inverse *= 2 - denominator * inverse;
      inverse *= 2 - denominator * inverse;
      inverse *= 2 - denominator * inverse;
      inverse *= 2 - denominator * inverse;
      inverse *= 2 - denominator * inverse;

      result = prod0 * inverse;

      return result;
    }
  }

  function mulDiv (uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256)
  {
    uint256 result = mulDiv(x, y, denominator);

    if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0)
    {
      result += 1;
    }

    return result;
  }

  function sqrt (uint256 a) internal pure returns (uint256)
  {
    if (a == 0)
    {
      return 0;
    }

    uint256 result = 1 << (log2(a) >> 1);

    unchecked
    {
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;

      return min(result, a / result);
    }
  }

  function sqrt (uint256 a, Rounding rounding) internal pure returns (uint256)
  {
    unchecked
    {
      uint256 result = sqrt(a);

      return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
    }
  }

  function log2 (uint256 value) internal pure returns (uint256)
  {
    uint256 result = 0;

    unchecked
    {
      if (value >> 128 > 0)
      {
        value >>= 128;
        result += 128;
      }

      if (value >> 64 > 0)
      {
        value >>= 64;
        result += 64;
      }

      if (value >> 32 > 0)
      {
        value >>= 32;
        result += 32;
      }

      if (value >> 16 > 0)
      {
        value >>= 16;
        result += 16;
      }

      if (value >> 8 > 0)
      {
        value >>= 8;
        result += 8;
      }

      if (value >> 4 > 0)
      {
        value >>= 4;
        result += 4;
      }

      if (value >> 2 > 0)
      {
        value >>= 2;
        result += 2;
      }

      if (value >> 1 > 0)
      {
        result += 1;
      }
    }

    return result;
  }

  function log2 (uint256 value, Rounding rounding) internal pure returns (uint256)
  {
    unchecked
    {
      uint256 result = log2(value);

      return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
    }
  }

  function log10 (uint256 value) internal pure returns (uint256)
  {
    uint256 result = 0;

    unchecked
    {
      if (value >= 10**64)
      {
        value /= 10**64;
        result += 64;
      }

      if (value >= 10**32)
      {
        value /= 10**32;
        result += 32;
      }

      if (value >= 10**16)
      {
        value /= 10**16;
        result += 16;
      }

      if (value >= 10**8)
      {
        value /= 10**8;
        result += 8;
      }

      if (value >= 10**4)
      {
        value /= 10**4;
        result += 4;
      }

      if (value >= 10**2)
      {
        value /= 10**2;
        result += 2;
      }

      if (value >= 10**1)
      {
        result += 1;
      }
    }

    return result;
  }

  function log10 (uint256 value, Rounding rounding) internal pure returns (uint256)
  {
    unchecked
    {
      uint256 result = log10(value);

      return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
    }
  }

  function log256 (uint256 value) internal pure returns (uint256)
  {
    uint256 result = 0;

    unchecked
    {
      if (value >> 128 > 0)
      {
        value >>= 128;
        result += 16;
      }

      if (value >> 64 > 0)
      {
        value >>= 64;
        result += 8;
      }

      if (value >> 32 > 0)
      {
        value >>= 32;
        result += 4;
      }

      if (value >> 16 > 0)
      {
        value >>= 16;
        result += 2;
      }

      if (value >> 8 > 0)
      {
        result += 1;
      }
    }

    return result;
  }

  function log256 (uint256 value, Rounding rounding) internal pure returns (uint256)
  {
    unchecked
    {
      uint256 result = log256(value);

      return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
    }
  }
}


library EnumerableSet
{
  struct Set
  {
    bytes32[] _values;
    mapping(bytes32 => uint256) _indexes;
  }

  function _add (Set storage set, bytes32 value) private returns (bool)
  {
    if (!_contains(set, value))
    {
      set._values.push(value);
      set._indexes[value] = set._values.length;

      return true;
    }

    return false;
  }

  function _remove (Set storage set, bytes32 value) private returns (bool)
  {
    uint256 valueIndex = set._indexes[value];

    if (valueIndex != 0)
    {
      uint256 toDeleteIndex = valueIndex - 1;
      uint256 lastIndex = set._values.length - 1;

      if (lastIndex != toDeleteIndex)
      {
        bytes32 lastValue = set._values[lastIndex];

        set._values[toDeleteIndex] = lastValue;
        set._indexes[lastValue] = valueIndex;
      }

      set._values.pop();
      delete set._indexes[value];

      return true;
    }

    return false;
  }

  function _contains (Set storage set, bytes32 value) private view returns (bool)
  {
    return set._indexes[value] != 0;
  }

  function _length (Set storage set) private view returns (uint256)
  {
    return set._values.length;
  }

  function _at (Set storage set, uint256 index) private view returns (bytes32)
  {
    return set._values[index];
  }

  function _values (Set storage set) private view returns (bytes32[] memory)
  {
    return set._values;
  }

  struct Bytes32Set
  {
    Set _inner;
  }

  function add (Bytes32Set storage set, bytes32 value) internal returns (bool)
  {
    return _add(set._inner, value);
  }

  function remove (Bytes32Set storage set, bytes32 value) internal returns (bool)
  {
    return _remove(set._inner, value);
  }

  function contains (Bytes32Set storage set, bytes32 value) internal view returns (bool)
  {
    return _contains(set._inner, value);
  }

  function length (Bytes32Set storage set) internal view returns (uint256)
  {
    return _length(set._inner);
  }

  function at (Bytes32Set storage set, uint256 index) internal view returns (bytes32)
  {
    return _at(set._inner, index);
  }

  function values (Bytes32Set storage set) internal view returns (bytes32[] memory)
  {
    bytes32[] memory store = _values(set._inner);
    bytes32[] memory result;

    assembly
    {
      result := store
    }

    return result;
  }

  struct AddressSet
  {
    Set _inner;
  }

  function add (AddressSet storage set, address value) internal returns (bool)
  {
    return _add(set._inner, bytes32(uint256(uint160(value))));
  }

  function remove (AddressSet storage set, address value) internal returns (bool)
  {
    return _remove(set._inner, bytes32(uint256(uint160(value))));
  }

  function contains (AddressSet storage set, address value) internal view returns (bool)
  {
    return _contains(set._inner, bytes32(uint256(uint160(value))));
  }

  function length (AddressSet storage set) internal view returns (uint256)
  {
    return _length(set._inner);
  }

  function at (AddressSet storage set, uint256 index) internal view returns (address)
  {
    return address(uint160(uint256(_at(set._inner, index))));
  }

  function values (AddressSet storage set) internal view returns (address[] memory)
  {
    bytes32[] memory store = _values(set._inner);
    address[] memory result;

    assembly
    {
      result := store
    }

    return result;
  }

  struct UintSet
  {
    Set _inner;
  }

  function add (UintSet storage set, uint256 value) internal returns (bool)
  {
    return _add(set._inner, bytes32(value));
  }

  function remove (UintSet storage set, uint256 value) internal returns (bool)
  {
    return _remove(set._inner, bytes32(value));
  }

  function contains (UintSet storage set, uint256 value) internal view returns (bool)
  {
    return _contains(set._inner, bytes32(value));
  }

  function length (UintSet storage set) internal view returns (uint256)
  {
    return _length(set._inner);
  }

  function at (UintSet storage set, uint256 index) internal view returns (uint256)
  {
    return uint256(_at(set._inner, index));
  }

  function values (UintSet storage set) internal view returns (uint256[] memory)
  {
    bytes32[] memory store = _values(set._inner);
    uint256[] memory result;

    assembly
    {
      result := store
    }

    return result;
  }
}


library SafeToken
{
  function _getRevertErr (bytes memory data, string memory message) private pure returns (string memory)
  {
    if (data.length < 68)
    {
      return message;
    }


    assembly
    {
      data := add(data, 0x04)
    }


    return abi.decode(data, (string));
  }


  function _call (address token, bytes memory encoded, string memory message) private
  {
    (bool success, bytes memory data) = token.call(encoded);


    require(success && (data.length == 0 || abi.decode(data, (bool))), _getRevertErr(data, message));
  }

  function safeApprove (IERC20 token, address spender, uint256 amount) internal
  {
    _call(address(token), abi.encodeWithSelector(IERC20.approve.selector, spender, amount), "!sa");
  }

  function safeTransfer (IERC20 token, address to, uint256 amount) internal
  {
    _call(address(token), abi.encodeWithSelector(IERC20.transfer.selector, to, amount), "!st");
  }

  function safeTransferFrom (IERC20 token, address from, address to, uint256 amount) internal
  {
    _call(address(token), abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount), "!stf");
  }
}


abstract contract ReentrancyGuard
{
  uint256 private _status = 1;


  modifier nonReentrant ()
  {
    require(_status == 1, "reentrance");


    _status = 2;

    _;

    _status = 1;
  }
}


contract WUSD is ReentrancyGuard
{
  using SafeToken for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;


  ISwapRouter private constant _ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

  IRegistry private constant _REGISTRY = IRegistry(0x4E23524aA15c689F2d100D49E27F28f8E5088C0D);

  address private constant _GLOVE = 0x70c5f366dB60A2a0C59C4C24754803Ee47Ed7284;
  address private constant _USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address private constant _USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  uint256 private constant _MIN_GLOVABLE = 100e18;
  uint256 private constant _MID_GLOVE = 0.01e18;
  uint256 private constant _MAX_GLOVE = 2e18;
  uint256 private constant _EPOCH = 100_000e18;

  uint24 private constant _ROUTE = 500;


  Snapshot private _snapshot;
  EnumerableSet.AddressSet private _fiatcoins;


  uint256 private _totalSupply;

  mapping(address => uint256) private _epoch;
  mapping(address => uint256) private _decimal;

  mapping(address => uint256) private _balance;


  event Transfer(address indexed from, address indexed to, uint256 value);

  event Wrap(address indexed account, address fiatcoin, uint256 amount, address referrer);


  constructor (address[] memory fiatcoins)
  {
    uint256 decimal;
    address fiatcoin;

    for (uint256 i; i < fiatcoins.length;)
    {
      fiatcoin = fiatcoins[i];
      decimal = IERC20(fiatcoin).decimals();

      _fiatcoins.add(fiatcoin);
      _decimal[fiatcoin] = decimal;

      IERC20(fiatcoin).safeApprove(address(_ROUTER), type(uint128).max);


      unchecked { i++; }
    }


    _snapshot = Snapshot({ epoch: 1, last: 0, cumulative: 0 });
  }


  function _percent (uint256 amount, uint256 percent) internal pure returns (uint256)
  {
    return (amount * percent) / 100_00;
  }

  function _normalize (uint256 amount, uint256 decimal) internal pure returns (uint256)
  {
    return (amount * 1e18) / (10 ** decimal);
  }

  function _denormalize (uint256 amount, uint256 decimal) internal pure returns (uint256)
  {
    return (amount * (10 ** decimal)) / 1e18;
  }


  function _isFiatcoin (address token) internal view
  {
    require(_fiatcoins.contains(token), "WUSD: !fiatcoin");
  }


  function _snap (uint256 wrapping) internal
  {
    Snapshot memory snap = _snapshot;


    if ((snap.cumulative - snap.last) >= _EPOCH)
    {
      _snapshot.epoch = snap.epoch + 1;
      _snapshot.last = snap.cumulative;
    }

    if (wrapping >= _MIN_GLOVABLE || _epoch[msg.sender] > 0)
    {
      _epoch[msg.sender] = _snapshot.epoch;
    }


    _snapshot.cumulative = snap.cumulative + uint112(wrapping);
  }

  function _englove (uint256 wrapping) internal
  {
    uint256 gloves = IGlove(_GLOVE).balanceOf(msg.sender);


    if (wrapping >= _MIN_GLOVABLE && gloves < _MAX_GLOVE)
    {
      IGlove(_GLOVE).mintCreditless(msg.sender, Math.min(_MAX_GLOVE - gloves, wrapping > 1_000e18 ? ((_MAX_GLOVE * wrapping) / _EPOCH) : ((_MID_GLOVE * wrapping) / 1_000e18)));
    }
  }

  function _mint (address account, uint256 amount) internal
  {
    require(account != address(0), "WUSD: mint to 0 addr");


    _totalSupply += amount;


    unchecked
    {
      _balance[account] += amount;
    }


    emit Transfer(address(0), account, amount);
  }

  function _parse (uint256 amount, uint256 decimal) internal pure returns (uint256, uint256)
  {
    return (Math.max(10 ** decimal, _percent(amount, 1_00)), _normalize(amount, decimal));
  }

  function wrap (address fiatcoin, uint256 amount, address referrer) external nonReentrant
  {
    _isFiatcoin(fiatcoin);
    require(amount > 0, "WUSD: wrap(0)");


    (uint256 fee, uint256 wrapping) = _parse(amount, _decimal[fiatcoin]);


    _snap(wrapping);
    _mint(msg.sender, wrapping);

    _englove(wrapping);
    IERC20(fiatcoin).safeTransferFrom(msg.sender, address(this), amount + fee);


    if (fiatcoin != _USDT && fiatcoin != _USDC)
    {
      _ROUTER.exactInputSingle(ISwapRouter.ExactInputSingleParams
      ({
        tokenIn: fiatcoin,
        tokenOut: _USDC,
        fee: fiatcoin != 0x0000000000085d4780B73119b644AE5ecd22b376 ? _ROUTE : 100,
        recipient: _REGISTRY.collector(),
        deadline: block.timestamp,
        amountIn: fee,
        amountOutMinimum: _percent(_denormalize(_normalize(fee, _decimal[fiatcoin]), 6), 95_00),
        sqrtPriceLimitX96: 0
      }));
    }
    else
    {
      IERC20(fiatcoin).safeTransfer(_REGISTRY.collector(), fee);
    }


    if (referrer != address(0))
    {
      IFrontender(_REGISTRY.frontender()).refer(msg.sender, wrapping, referrer);
    }


    emit Wrap(msg.sender, fiatcoin, amount, referrer);
  }
}
