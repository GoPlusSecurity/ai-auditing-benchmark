# Palkeoramix decompiler. 

const decimals = ext_call.return_data
const unknownb81e03b8 = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48

def storage:
  stor1 is uint32 at storage 1
  owner is addr at storage 1
  stor1 is uint256 at storage 1
  balanceOf is mapping of uint256 at storage 2
  allowance is mapping of uint256 at storage 3
  totalSupply is uint256 at storage 4
  stor7 is array of struct at storage 7
  stor8 is array of struct at storage 8
  unknown4be4e91f is array of addr at storage 9
  unknowna622ee7c is mapping of struct at storage 10
  totalWeight is uint256 at storage 11
  isInit is uint8 at storage 12
  stor12 is addr at storage 12
  unknowne822eb32Address is addr at storage 12 offset 8
  feeCollectorAddress is addr at storage 13
  unknownbce896f6 is uint256 at storage 14
  unknown1ba2b2e8 is uint256 at storage 15

def totalSupply() payable: 
  return totalSupply

def unknown1ba2b2e8() payable: 
  return unknown1ba2b2e8

def unknown4be4e91f(uint256 _param1) payable: 
  require calldata.size - 4 >=ΓÇ▓ 32
  require _param1 < unknown4be4e91f.length
  return unknown4be4e91f[_param1]

def balanceOf(address _owner) payable: 
  require calldata.size - 4 >=ΓÇ▓ 32
  require _owner == _owner
  return balanceOf[addr(_owner)]

def unknown82af54c9() payable: 
  return unknown4be4e91f.length

def owner() payable: 
  return addr(owner)

def totalWeight() payable: 
  return totalWeight

def unknowna622ee7c(uint256 _param1) payable: 
  require calldata.size - 4 >=ΓÇ▓ 32
  require _param1 == addr(_param1)
  return bool(unknowna622ee7c[_param1].field_0), 
         unknowna622ee7c[_param1].field_0,
         unknowna622ee7c[_param1].field_256,
         unknowna622ee7c[_param1].field_512

def isInit() payable: 
  return bool(isInit)

def unknownbce896f6() payable: 
  return unknownbce896f6

def feeCollector() payable: 
  return feeCollectorAddress

def allowance(address _owner, address _spender) payable: 
  require calldata.size - 4 >=ΓÇ▓ 64
  require _owner == _owner
  require _spender == _spender
  return allowance[addr(_owner)][addr(_spender)]

def unknowne822eb32() payable: 
  return unknowne822eb32Address

#
#  Regular functions
#

def _fallback() payable: # default function
  revert

def renounceOwnership() payable: 
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  addr(owner) = 0
  log OwnershipTransferred(
        address previousOwner=addr(owner),
        address newOwner=0)

def setFeeCollector(address _addr) payable: 
  require calldata.size - 4 >=ΓÇ▓ 32
  require _addr == _addr
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  feeCollectorAddress = _addr
  unknown1ba2b2e8 = block.timestamp

def transferOwnership(address _newOwner) payable: 
  require calldata.size - 4 >=ΓÇ▓ 32
  require _newOwner == _newOwner
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  if not _newOwner:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'Ownable: new owner is the zero address'
  addr(owner) = _newOwner
  log OwnershipTransferred(
        address previousOwner=addr(owner),
        address newOwner=_newOwner)

def sync(address _owner) payable: 
  require calldata.size - 4 >=ΓÇ▓ 32
  require _owner == _owner
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  require ext_code.size(_owner)
  static call _owner.balanceOf(address tokenOwner) with:
          gas gas_remaining wei
         args this.address
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 32
  unknowna622ee7c[addr(_owner)].field_256 = ext_call.return_data[0]

def approve(address _spender, uint256 _value) payable: 
  require calldata.size - 4 >=ΓÇ▓ 64
  require _spender == _spender
  if not caller:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: approve from the zero address'
  if not _spender:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: approve to the zero address'
  allowance[caller][addr(_spender)] = _value
  log Approval(
        address tokenOwner=_value,
        address spender=caller,
        uint256 tokens=_spender)
  return 1

def unknown0a5c36b3(uint256 _param1) payable: 
  require calldata.size - 4 >=ΓÇ▓ 32
  require _param1 == addr(_param1)
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  require ext_code.size(addr(_param1))
  static call addr(_param1).getLendingPool() with:
          gas gas_remaining wei
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 32
  require ext_call.return_data == ext_call.return_data[12 len 20]
  unknowne822eb32Address = ext_call.return_data[12 len 20]
  log 0x1d0743ee: ext_call.return_data

def transfer(address _to, uint256 _value) payable: 
  require calldata.size - 4 >=ΓÇ▓ 64
  require _to == _to
  if not caller:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: transfer from the zero address'
  if not _to:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: transfer to the zero address'
  if balanceOf[caller] < _value:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: transfer amount exceeds balance'
  balanceOf[caller] -= _value
  if balanceOf[_to] > !_value:
      revert with 0, 17
  balanceOf[_to] += _value
  log Transfer(
        address from=_value,
        address to=caller,
        uint256 tokens=_to)
  return 1

def increaseAllowance(address _spender, uint256 _addedValue) payable: 
  require calldata.size - 4 >=ΓÇ▓ 64
  require _spender == _spender
  if allowance[caller][addr(_spender)] > !_addedValue:
      revert with 0, 17
  if not caller:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: approve from the zero address'
  if not _spender:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: approve to the zero address'
  allowance[caller][addr(_spender)] = allowance[caller][addr(_spender)] + _addedValue
  log Approval(
        address tokenOwner=(allowance[caller][addr(_spender)] + _addedValue),
        address spender=caller,
        uint256 tokens=_spender)
  return 1

def decreaseAllowance(address _spender, uint256 _subtractedValue) payable: 
  require calldata.size - 4 >=ΓÇ▓ 64
  require _spender == _spender
  if allowance[caller][addr(_spender)] < _subtractedValue:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: decreased allowance below zero'
  if not caller:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: approve from the zero address'
  if not _spender:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: approve to the zero address'
  allowance[caller][addr(_spender)] = allowance[caller][addr(_spender)] - _subtractedValue
  log Approval(
        address tokenOwner=(allowance[caller][addr(_spender)] - _subtractedValue),
        address spender=caller,
        uint256 tokens=_spender)
  return 1

def unknownd1580e20(uint256 _param1, uint256 _param2) payable: 
  require calldata.size - 4 >=ΓÇ▓ 64
  require _param1 == addr(_param1)
  require _param2 == uint64(_param2)
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  if bool(unknowna622ee7c[addr(_param1)].field_0) != 1:
      revert with 0, 'vault invalid'
  if totalWeight < unknowna622ee7c[addr(_param1)].field_8:
      revert with 0, 17
  totalWeight -= unknowna622ee7c[addr(_param1)].field_8
  unknowna622ee7c[addr(_param1)].field_8 = uint64(_param2)
  if totalWeight > !uint64(_param2):
      revert with 0, 17
  totalWeight += uint64(_param2)
  log 0x6cf9dfa0: addr(_param1), uint64(_param2)

def unknown9e689393(uint256 _param1, uint256 _param2) payable: 
  require calldata.size - 4 >=ΓÇ▓ 64
  require _param1 == addr(_param1)
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  require ext_code.size(unknowne822eb32Address)
  call unknowne822eb32Address.withdraw(address token, uint256 amount, address destination) with:
       gas gas_remaining wei
      args addr(_param1), _param2, this.address
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 32
  if ext_call.return_data > unknowna622ee7c[addr(_param1)].field_512:
      unknowna622ee7c[addr(_param1)].field_512 = 0
  else:
      if unknowna622ee7c[addr(_param1)].field_512 < ext_call.return_data[0]:
          revert with 0, 17
      unknowna622ee7c[addr(_param1)].field_512 -= ext_call.return_data[0]

def unknown46e00843(uint256 _param1, uint256 _param2) payable: 
  require calldata.size - 4 >=ΓÇ▓ 64
  require _param1 == addr(_param1)
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  require ext_code.size(addr(_param1))
  call addr(_param1).approve(address spender, uint256 tokens) with:
       gas gas_remaining wei
      args stor12, _param2
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 32
  require ext_call.return_data == bool(ext_call.return_data[0])
  require ext_code.size(unknowne822eb32Address)
  call unknowne822eb32Address.0xe8eda9df with:
       gas gas_remaining wei
      args addr(_param1), _param2, this.address, 0
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  if unknowna622ee7c[addr(_param1)].field_512 > !_param2:
      revert with 0, 17
  unknowna622ee7c[addr(_param1)].field_512 += _param2

def unknown166d21fa(uint256 _param1, uint256 _param2) payable: 
  require calldata.size - 4 >=ΓÇ▓ 64
  require _param1 == addr(_param1)
  require _param2 == uint64(_param2)
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  if unknowna622ee7c[addr(_param1)].field_0:
      revert with 0, 'Duplicate _init LP'
  require ext_code.size(addr(_param1))
  call addr(_param1).0xb81e03b8 with:
       gas gas_remaining wei
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 32
  require ext_call.return_data == ext_call.return_data[12 len 20]
  if ext_call.return_data[12 len 20] != 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48:
      revert with 0, 'LP collat mismatch vault collat'
  unknown4be4e91f.length++
  unknown4be4e91f[unknown4be4e91f.length] = addr(_param1)
  unknowna622ee7c[addr(_param1)].field_0 = 1
  unknowna622ee7c[addr(_param1)].field_8 = uint64(_param2)
  unknowna622ee7c[addr(_param1)].field_72 = 0
  unknowna622ee7c[addr(_param1)].field_256 = 0
  unknowna622ee7c[addr(_param1)].field_512 = 0
  if totalWeight > !uint64(_param2):
      revert with 0, 17
  totalWeight += uint64(_param2)
  log 0x4e306b5b: addr(_param1), uint64(_param2)

def transferFrom(address _from, address _to, uint256 _value) payable: 
  require calldata.size - 4 >=ΓÇ▓ 96
  require _from == _from
  require _to == _to
  if allowance[addr(_from)][caller] < _value:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: transfer amount exceeds allowance'
  if not _from:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: approve from the zero address'
  if not caller:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: approve to the zero address'
  allowance[addr(_from)][caller] = allowance[addr(_from)][caller] - _value
  log Approval(
        address tokenOwner=(allowance[addr(_from)][caller] - _value),
        address spender=_from,
        uint256 tokens=caller)
  if not _from:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: transfer from the zero address'
  if not _to:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: transfer to the zero address'
  if balanceOf[addr(_from)] < _value:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: transfer amount exceeds balance'
  balanceOf[addr(_from)] -= _value
  if balanceOf[_to] > !_value:
      revert with 0, 17
  balanceOf[_to] += _value
  log Transfer(
        address from=_value,
        address to=_from,
        uint256 tokens=_to)
  return 1

def mintFee() payable: 
  if feeCollectorAddress:
      if block.timestamp < unknown1ba2b2e8:
          revert with 0, 17
      if block.timestamp - unknown1ba2b2e8 >= 24 * 3600:
          if totalSupply and unknownbce896f6 > -1 / totalSupply:
              revert with 0, 17
          if totalSupply * unknownbce896f6 and block.timestamp - unknown1ba2b2e8 > -1 / totalSupply * unknownbce896f6:
              revert with 0, 17
          unknown1ba2b2e8 = block.timestamp
          if not feeCollectorAddress:
              revert with 0, 'ERC20: mint to the zero address'
          if totalSupply > !((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600):
              revert with 0, 17
          totalSupply += (block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600
          if balanceOf[stor13] > !((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600):
              revert with 0, 17
          balanceOf[stor13] += (block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600
          log Transfer(
                address from=((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600),
                address to=0,
                uint256 tokens=feeCollectorAddress)

def unknownceb68c23(uint256 _param1) payable: 
  require calldata.size - 4 >=ΓÇ▓ 32
  require _param1 == addr(_param1)
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  if bool(unknowna622ee7c[addr(_param1)].field_0) != 1:
      revert with 0, 'LP not added'
  require ext_code.size(addr(_param1))
  static call addr(_param1).balanceOf(address tokenOwner) with:
          gas gas_remaining wei
         args this.address
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 32
  if ext_call.return_data[0]:
      revert with 0, 'LP still in vault'
  if unknowna622ee7c[addr(_param1)].field_8:
      revert with 0, 'LP still has weight'
  idx = 0
  while idx < unknown4be4e91f.length:
      mem[0] = 9
      if unknown4be4e91f[idx] != addr(_param1):
          if idx == -1:
              revert with 0, 17
          idx = idx + 1
          continue 
      if unknown4be4e91f.length < 1:
          revert with 0, 17
      if unknown4be4e91f.length - 1 >= unknown4be4e91f.length:
          revert with 0, 50
      if idx >= unknown4be4e91f.length:
          revert with 0, 50
      unknown4be4e91f[idx] = unknown4be4e91f[unknown4be4e91f.length]
      if not unknown4be4e91f.length:
          revert with 0, 49
      unknown4be4e91f[unknown4be4e91f.length] = 0
      unknown4be4e91f.length--
      unknowna622ee7c[addr(_param1)].field_0 = 0
      log 0xe71f3a50: addr(_param1)
      stop

def unknownbd82c560(uint256 _param1) payable: 
  require calldata.size - 4 >=ΓÇ▓ 32
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  if _param1 > 20000:
      revert with 0, 'Fee too high'
  if feeCollectorAddress:
      if block.timestamp < unknown1ba2b2e8:
          revert with 0, 17
      if block.timestamp - unknown1ba2b2e8 >= 24 * 3600:
          if totalSupply and unknownbce896f6 > -1 / totalSupply:
              revert with 0, 17
          if totalSupply * unknownbce896f6 and block.timestamp - unknown1ba2b2e8 > -1 / totalSupply * unknownbce896f6:
              revert with 0, 17
          unknown1ba2b2e8 = block.timestamp
          if not feeCollectorAddress:
              revert with 0, 'ERC20: mint to the zero address'
          if totalSupply > !((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600):
              revert with 0, 17
          totalSupply += (block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600
          if balanceOf[stor13] > !((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600):
              revert with 0, 17
          balanceOf[stor13] += (block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600
          log Transfer(
                address from=((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600),
                address to=0,
                uint256 tokens=feeCollectorAddress)
  unknownbce896f6 = _param1
  log 0x1062b5f8: _param1

def emergencyWithdraw(address _param1) payable: 
  require calldata.size - 4 >=ΓÇ▓ 32
  require _param1 == _param1
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  mem[100] = this.address
  require ext_code.size(_param1)
  static call _param1.balanceOf(address tokenOwner) with:
          gas gas_remaining wei
         args this.address
  mem[96] = ext_call.return_data[0]
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 32
  mem[ceil32(return_data.size) + 132] = addr(owner)
  mem[ceil32(return_data.size) + 164] = ext_call.return_data[0]
  mem[ceil32(return_data.size) + 96] = 68
  mem[ceil32(return_data.size) + 132 len 28] = Mask(224, 0, stor1)
  mem[ceil32(return_data.size) + 128 len 4] = transfer(address to, uint256 tokens)
  mem[ceil32(return_data.size) + 196] = 32
  mem[ceil32(return_data.size) + 228] = 'SafeERC20: low-level call failed'
  if eth.balance(this.address) < 0:
      revert with 0, 'Address: insufficient balance for call'
  if not ext_code.size(_param1):
      revert with 0, 'Address: call to non-contract'
  mem[ceil32(return_data.size) + 260 len 96] = transfer(address to, uint256 tokens), Mask(224, 0, stor1), uint32(stor1), ext_call.return_data[0], 0
  mem[ceil32(return_data.size) + 328] = 0
  call _param1 with:
     funct Mask(32, 224, transfer(address to, uint256 tokens), Mask(224, 0, stor1), uint32(stor1), ext_call.return_data >> 224
       gas gas_remaining wei
      args (Mask(512, -288, transfer(address to, uint256 tokens), Mask(224, 0, stor1), uint32(stor1), ext_call.return_data << 288)
  if not return_data.size:
      if not ext_call.success:
          if ext_call.return_data[0]:
              revert with memory
                from 128
                 len ext_call.return_data[0]
          revert with 0, 'SafeERC20: low-level call failed'
      if ext_call.return_data[0]:
          require ext_call.return_data >=ΓÇ▓ 32
          require uint32(this.address), mem[132 len 28] == bool(uint32(this.address), mem[132 len 28])
          if not uint32(this.address), mem[132 len 28]:
              revert with 0, 'SafeERC20: ERC20 operation did not succeed'
  else:
      mem[ceil32(return_data.size) + 292 len return_data.size] = ext_call.return_data[0 len return_data.size]
      if not ext_call.success:
          if return_data.size:
              revert with ext_call.return_data[0 len return_data.size]
          revert with 0, 'SafeERC20: low-level call failed'
      if return_data.size:
          require return_data.size >=ΓÇ▓ 32
          require mem[ceil32(return_data.size) + 292] == bool(mem[ceil32(return_data.size) + 292])
          if not mem[ceil32(return_data.size) + 292]:
              revert with 0, 'SafeERC20: ERC20 operation did not succeed'

def name() payable: 
  if bool(stor7.length):
      if bool(stor7.length) == uint255(stor7.length) * 0.5 < 32:
          revert with 0, 34
      if bool(stor7.length):
          if bool(stor7.length) == uint255(stor7.length) * 0.5 < 32:
              revert with 0, 34
          if Mask(256, -1, stor7.length):
              if 31 < uint255(stor7.length) * 0.5:
                  mem[128] = uint256(stor7.field_0)
                  idx = 128
                  s = 0
                  while (uint255(stor7.length) * 0.5) + 96 > idx:
                      mem[idx + 32] = stor7[s].field_256
                      idx = idx + 32
                      s = s + 1
                      continue 
                  return Array(len=2 * Mask(256, -1, stor7.length), data=mem[128 len ceil32(uint255(stor7.length) * 0.5)])
              mem[128] = 256 * stor7.length.field_8
      else:
          if bool(stor7.length) == stor7.length.field_1 < 32:
              revert with 0, 34
          if stor7.length.field_1:
              if 31 < stor7.length.field_1:
                  mem[128] = uint256(stor7.field_0)
                  idx = 128
                  s = 0
                  while stor7.length.field_1 + 96 > idx:
                      mem[idx + 32] = stor7[s].field_256
                      idx = idx + 32
                      s = s + 1
                      continue 
                  return Array(len=2 * Mask(256, -1, stor7.length), data=mem[128 len ceil32(uint255(stor7.length) * 0.5)])
              mem[128] = 256 * stor7.length.field_8
      mem[ceil32(uint255(stor7.length) * 0.5) + 192 len ceil32(uint255(stor7.length) * 0.5)] = mem[128 len ceil32(uint255(stor7.length) * 0.5)]
      if ceil32(uint255(stor7.length) * 0.5) > uint255(stor7.length) * 0.5:
          mem[(uint255(stor7.length) * 0.5) + ceil32(uint255(stor7.length) * 0.5) + 192] = 0
      return Array(len=2 * Mask(256, -1, stor7.length), data=mem[128 len ceil32(uint255(stor7.length) * 0.5)], mem[(2 * ceil32(uint255(stor7.length) * 0.5)) + 192 len 2 * ceil32(uint255(stor7.length) * 0.5)]), 
  if bool(stor7.length) == stor7.length.field_1 < 32:
      revert with 0, 34
  if bool(stor7.length):
      if bool(stor7.length) == uint255(stor7.length) * 0.5 < 32:
          revert with 0, 34
      if Mask(256, -1, stor7.length):
          if 31 < uint255(stor7.length) * 0.5:
              mem[128] = uint256(stor7.field_0)
              idx = 128
              s = 0
              while (uint255(stor7.length) * 0.5) + 96 > idx:
                  mem[idx + 32] = stor7[s].field_256
                  idx = idx + 32
                  s = s + 1
                  continue 
              return Array(len=stor7.length % 128, data=mem[128 len ceil32(stor7.length.field_1)])
          mem[128] = 256 * stor7.length.field_8
  else:
      if bool(stor7.length) == stor7.length.field_1 < 32:
          revert with 0, 34
      if stor7.length.field_1:
          if 31 < stor7.length.field_1:
              mem[128] = uint256(stor7.field_0)
              idx = 128
              s = 0
              while stor7.length.field_1 + 96 > idx:
                  mem[idx + 32] = stor7[s].field_256
                  idx = idx + 32
                  s = s + 1
                  continue 
              return Array(len=stor7.length % 128, data=mem[128 len ceil32(stor7.length.field_1)])
          mem[128] = 256 * stor7.length.field_8
  mem[ceil32(stor7.length.field_1) + 192 len ceil32(stor7.length.field_1)] = mem[128 len ceil32(stor7.length.field_1)]
  if ceil32(stor7.length.field_1) > stor7.length.field_1:
      mem[stor7.length.field_1 + ceil32(stor7.length.field_1) + 192] = 0
  return Array(len=stor7.length % 128, data=mem[128 len ceil32(stor7.length.field_1)], mem[(2 * ceil32(stor7.length.field_1)) + 192 len 2 * ceil32(stor7.length.field_1)]), 

def symbol() payable: 
  if bool(stor8.length):
      if bool(stor8.length) == uint255(stor8.length) * 0.5 < 32:
          revert with 0, 34
      if bool(stor8.length):
          if bool(stor8.length) == uint255(stor8.length) * 0.5 < 32:
              revert with 0, 34
          if Mask(256, -1, stor8.length):
              if 31 < uint255(stor8.length) * 0.5:
                  mem[128] = uint256(stor8.field_0)
                  idx = 128
                  s = 0
                  while (uint255(stor8.length) * 0.5) + 96 > idx:
                      mem[idx + 32] = stor8[s].field_256
                      idx = idx + 32
                      s = s + 1
                      continue 
                  return Array(len=2 * Mask(256, -1, stor8.length), data=mem[128 len ceil32(uint255(stor8.length) * 0.5)])
              mem[128] = 256 * stor8.length.field_8
      else:
          if bool(stor8.length) == stor8.length.field_1 < 32:
              revert with 0, 34
          if stor8.length.field_1:
              if 31 < stor8.length.field_1:
                  mem[128] = uint256(stor8.field_0)
                  idx = 128
                  s = 0
                  while stor8.length.field_1 + 96 > idx:
                      mem[idx + 32] = stor8[s].field_256
                      idx = idx + 32
                      s = s + 1
                      continue 
                  return Array(len=2 * Mask(256, -1, stor8.length), data=mem[128 len ceil32(uint255(stor8.length) * 0.5)])
              mem[128] = 256 * stor8.length.field_8
      mem[ceil32(uint255(stor8.length) * 0.5) + 192 len ceil32(uint255(stor8.length) * 0.5)] = mem[128 len ceil32(uint255(stor8.length) * 0.5)]
      if ceil32(uint255(stor8.length) * 0.5) > uint255(stor8.length) * 0.5:
          mem[(uint255(stor8.length) * 0.5) + ceil32(uint255(stor8.length) * 0.5) + 192] = 0
      return Array(len=2 * Mask(256, -1, stor8.length), data=mem[128 len ceil32(uint255(stor8.length) * 0.5)], mem[(2 * ceil32(uint255(stor8.length) * 0.5)) + 192 len 2 * ceil32(uint255(stor8.length) * 0.5)]), 
  if bool(stor8.length) == stor8.length.field_1 < 32:
      revert with 0, 34
  if bool(stor8.length):
      if bool(stor8.length) == uint255(stor8.length) * 0.5 < 32:
          revert with 0, 34
      if Mask(256, -1, stor8.length):
          if 31 < uint255(stor8.length) * 0.5:
              mem[128] = uint256(stor8.field_0)
              idx = 128
              s = 0
              while (uint255(stor8.length) * 0.5) + 96 > idx:
                  mem[idx + 32] = stor8[s].field_256
                  idx = idx + 32
                  s = s + 1
                  continue 
              return Array(len=stor8.length % 128, data=mem[128 len ceil32(stor8.length.field_1)])
          mem[128] = 256 * stor8.length.field_8
  else:
      if bool(stor8.length) == stor8.length.field_1 < 32:
          revert with 0, 34
      if stor8.length.field_1:
          if 31 < stor8.length.field_1:
              mem[128] = uint256(stor8.field_0)
              idx = 128
              s = 0
              while stor8.length.field_1 + 96 > idx:
                  mem[idx + 32] = stor8[s].field_256
                  idx = idx + 32
                  s = s + 1
                  continue 
              return Array(len=stor8.length % 128, data=mem[128 len ceil32(stor8.length.field_1)])
          mem[128] = 256 * stor8.length.field_8
  mem[ceil32(stor8.length.field_1) + 192 len ceil32(stor8.length.field_1)] = mem[128 len ceil32(stor8.length.field_1)]
  if ceil32(stor8.length.field_1) > stor8.length.field_1:
      mem[stor8.length.field_1 + ceil32(stor8.length.field_1) + 192] = 0
  return Array(len=stor8.length % 128, data=mem[128 len ceil32(stor8.length.field_1)], mem[(2 * ceil32(stor8.length.field_1)) + 192 len 2 * ceil32(stor8.length.field_1)]), 

def rebalance(address _fromExchange, address _toExchange, uint256 _fromPercent) payable: 
  require calldata.size - 4 >=ΓÇ▓ 96
  require _fromExchange == _fromExchange
  require _toExchange == _toExchange
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  if bool(unknowna622ee7c[addr(_toExchange)].field_0) != 1:
      revert with 0, 'tgt vault invalid'
  mem[100] = _fromPercent
  require ext_code.size(_fromExchange)
  call _fromExchange.0xaa15017c with:
       gas gas_remaining wei
      args _fromPercent
  mem[96] = ext_call.return_data[0]
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 32
  if ext_call.return_data <= 0:
      revert with 0, 'src not ready!'
  if unknowna622ee7c[addr(_fromExchange)].field_256 < _fromPercent:
      revert with 0, 17
  unknowna622ee7c[addr(_fromExchange)].field_256 -= _fromPercent
  mem[ceil32(return_data.size) + 100] = _toExchange
  mem[ceil32(return_data.size) + 132] = ext_call.return_data[0]
  require ext_code.size(0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48)
  call 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.approve(address spender, uint256 tokens) with:
       gas gas_remaining wei
      args addr(_toExchange), ext_call.return_data[0]
  mem[ceil32(return_data.size) + 96] = ext_call.return_data[0]
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 32
  require ext_call.return_data == bool(ext_call.return_data[0])
  mem[(2 * ceil32(return_data.size)) + 100] = ext_call.return_data[0]
  require ext_code.size(_toExchange)
  call _toExchange.deposit(uint256 amount) with:
       gas gas_remaining wei
      args ext_call.return_data[0]
  mem[(2 * ceil32(return_data.size)) + 96] = ext_call.return_data[0]
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  mem[64] = (4 * ceil32(return_data.size)) + 96
  require return_data.size >=ΓÇ▓ 32
  mem[0] = _toExchange
  mem[32] = 10
  if unknowna622ee7c[addr(_toExchange)].field_256 > !ext_call.return_data[0]:
      revert with 0, 17
  unknowna622ee7c[addr(_toExchange)].field_256 += ext_call.return_data[0]
  idx = 0
  s = 0
  t = 0
  u = 0
  while idx < unknown4be4e91f.length:
      mem[0] = unknown4be4e91f[idx]
      mem[32] = 10
      require ext_code.size(unknown4be4e91f[idx])
      call unknown4be4e91f[idx].epoch() with:
           gas gas_remaining wei
      mem[mem[64]] = ext_call.return_data[0]
      if not ext_call.success:
          revert with ext_call.return_data[0 len return_data.size]
      _39 = mem[64]
      mem[64] = mem[64] + ceil32(return_data.size)
      require return_data.size >=ΓÇ▓ 32
      _40 = mem[_39]
      mem[mem[64] + 4] = mem[_39]
      require ext_code.size(unknown4be4e91f[idx])
      call unknown4be4e91f[idx].0x37033791 with:
           gas gas_remaining wei
          args _40
      mem[mem[64]] = ext_call.return_data[0]
      if not ext_call.success:
          revert with ext_call.return_data[0 len return_data.size]
      _46 = mem[64]
      mem[64] = mem[64] + ceil32(return_data.size)
      require return_data.size >=ΓÇ▓ 32
      if mem[_46] and unknowna622ee7c[stor9[idx]].field_256 > -1 / mem[_46]:
          revert with 0, 17
      if u > !(mem[_46] * unknowna622ee7c[stor9[idx]].field_256 / 10^18):
          revert with 0, 17
      if idx == -1:
          revert with 0, 17
      if unknown4be4e91f[idx] != _fromExchange:
          if unknown4be4e91f[idx] != _toExchange:
              idx = idx + 1
              s = s
              t = t
              u = u + (mem[_46] * unknowna622ee7c[stor9[idx]].field_256 / 10^18)
              continue 
          idx = idx + 1
          s = mem[_46] * unknowna622ee7c[stor9[idx]].field_256 / 10^18
          t = t
          u = u + (mem[_46] * unknowna622ee7c[stor9[idx]].field_256 / 10^18)
          continue 
      if unknown4be4e91f[idx] != _toExchange:
          idx = idx + 1
          s = s
          t = mem[_46] * unknowna622ee7c[stor9[idx]].field_256 / 10^18
          u = u + (mem[_46] * unknowna622ee7c[stor9[idx]].field_256 / 10^18)
          continue 
      idx = idx + 1
      s = mem[_46] * unknowna622ee7c[stor9[idx]].field_256 / 10^18
      t = mem[_46] * unknowna622ee7c[stor9[idx]].field_256 / 10^18
      u = u + (mem[_46] * unknowna622ee7c[stor9[idx]].field_256 / 10^18)
      continue 
  if u and unknowna622ee7c[addr(_fromExchange)].field_8 > -1 / u:
      revert with 0, 17
  if t and totalWeight > -1 / t:
      revert with 0, 17
  if t * totalWeight < u * unknowna622ee7c[addr(_fromExchange)].field_8:
      revert with 0, 'src vault underweight'
  if u and unknowna622ee7c[addr(_toExchange)].field_8 > -1 / u:
      revert with 0, 17
  if s and totalWeight > -1 / s:
      revert with 0, 17
  if s * totalWeight > u * unknowna622ee7c[addr(_toExchange)].field_8:
      revert with 0, 'tgt vault overweight'

def unknowna3039c8b() payable: 
  require calldata.size - 4 >=ΓÇ▓ 96
  require cd <= 18446744073709551615
  require cd <ΓÇ▓ calldata.size
  if ('cd', 4).length > 18446744073709551615:
      revert with 0, 65
  if ceil32(32 * ('cd', 4).length) + 97 < 96 or ceil32(32 * ('cd', 4).length) + 97 > 18446744073709551615:
      revert with 0, 65
  mem[96] = ('cd', 4).length
  require cd * ('cd', 4).length) + 36 <= calldata.size
  s = 128
  idx = cd[4] + 36
  while idx < cd * ('cd', 4).length) + 36:
      require cd[idx] == addr(cd[idx])
      mem[s] = cd[idx]
      s = s + 32
      idx = idx + 32
      continue 
  require cd <= 18446744073709551615
  require cd <ΓÇ▓ calldata.size
  if ('cd', 36).length > 18446744073709551615:
      revert with 0, 65
  if ceil32(32 * ('cd', 36).length) + 98 < 97 or ceil32(32 * ('cd', 4).length) + ceil32(32 * ('cd', 36).length) + 98 > 18446744073709551615:
      revert with 0, 65
  mem[ceil32(32 * ('cd', 4).length) + 97] = ('cd', 36).length
  require cd * ('cd', 36).length) + 36 <= calldata.size
  idx = cd[36] + 36
  s = ceil32(32 * ('cd', 4).length) + 129
  while idx < cd * ('cd', 36).length) + 36:
      mem[s] = cd[idx]
      idx = idx + 32
      s = s + 32
      continue 
  require cd <= 18446744073709551615
  require cd <ΓÇ▓ calldata.size
  if ('cd', 68).length > 18446744073709551615:
      revert with 0, 65
  if ceil32(32 * ('cd', 68).length) + 99 < 98 or ceil32(32 * ('cd', 4).length) + ceil32(32 * ('cd', 36).length) + ceil32(32 * ('cd', 68).length) + 99 > 18446744073709551615:
      revert with 0, 65
  mem[64] = ceil32(32 * ('cd', 4).length) + ceil32(32 * ('cd', 36).length) + ceil32(32 * ('cd', 68).length) + 99
  mem[ceil32(32 * ('cd', 4).length) + ceil32(32 * ('cd', 36).length) + 98] = ('cd', 68).length
  require cd * ('cd', 68).length) + 36 <= calldata.size
  idx = cd[68] + 36
  s = ceil32(32 * ('cd', 4).length) + ceil32(32 * ('cd', 36).length) + 130
  while idx < cd * ('cd', 68).length) + 36:
      require cd[idx] == uint64(cd[idx])
      mem[s] = cd[idx]
      idx = idx + 32
      s = s + 32
      continue 
  if addr(owner) != caller:
      revert with 0, 'Ownable: caller is not the owner'
  if isInit:
      revert with 0, 'Already init'
  if ('cd', 4).length <= 0:
      revert with 0, '_lp.len == 0'
  if ('cd', 4).length != ('cd', 36).length:
      revert with 0, '_lp.len != _initAmt.len'
  if ('cd', 4).length != ('cd', 68).length:
      revert with 0, '_lp.len != _initWgt.len'
  idx = 0
  s = 0
  while idx < ('cd', 4).length:
      if idx >= mem[96]:
          revert with 0, 50
      _509 = mem[(32 * idx) + 128]
      if idx >= mem[ceil32(32 * ('cd', 4).length) + ceil32(32 * ('cd', 36).length) + 98]:
          revert with 0, 50
      _512 = mem[(32 * idx) + ceil32(32 * ('cd', 4).length) + ceil32(32 * ('cd', 36).length) + 130]
      if idx >= mem[ceil32(32 * ('cd', 4).length) + 97]:
          revert with 0, 50
      _515 = mem[(32 * idx) + ceil32(32 * ('cd', 4).length) + 129]
      mem[0] = mem[(32 * idx) + 140 len 20]
      mem[32] = 10
      if unknowna622ee7c[mem[(32 * idx) + 140 len 20]].field_0:
          revert with 0, 'Duplicate _init LP'
      require ext_code.size(mem[(32 * idx) + 140 len 20])
      call mem[(32 * idx) + 140 len 20].0xb81e03b8 with:
           gas gas_remaining wei
      mem[mem[64]] = ext_call.return_data[0]
      if not ext_call.success:
          revert with ext_call.return_data[0 len return_data.size]
      _522 = mem[64]
      mem[64] = mem[64] + ceil32(return_data.size)
      require return_data.size >=ΓÇ▓ 32
      require mem[_522] == mem[_522 + 12 len 20]
      if mem[_522 + 12 len 20] != 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48:
          revert with 0, 'LP collat mismatch vault collat'
      unknown4be4e91f.length++
      unknown4be4e91f[unknown4be4e91f.length] = addr(_509)
      _526 = mem[64]
      mem[64] = mem[64] + 128
      mem[_526] = 1
      mem[_526 + 32] = uint64(_512)
      mem[_526 + 64] = _515
      mem[_526 + 96] = 0
      mem[0] = addr(_509)
      mem[32] = 10
      unknowna622ee7c[addr(_509)].field_0 = 1
      unknowna622ee7c[addr(_509)].field_8 = uint64(_512)
      unknowna622ee7c[addr(_509)].field_72 = 0
      unknowna622ee7c[addr(_509)].field_256 = _515
      unknowna622ee7c[addr(_509)].field_512 = 0
      if totalWeight > !uint64(_512):
          revert with 0, 17
      totalWeight += uint64(_512)
      mem[mem[64]] = addr(_509)
      mem[mem[64] + 32] = uint64(_512)
      log 0x4e306b5b: addr(_509), uint64(_512)
      if idx >= mem[ceil32(32 * ('cd', 4).length) + 97]:
          revert with 0, 50
      _537 = mem[(32 * idx) + ceil32(32 * ('cd', 4).length) + 129]
      if idx >= mem[96]:
          revert with 0, 50
      _539 = mem[(32 * idx) + 128]
      if idx >= mem[96]:
          revert with 0, 50
      require ext_code.size(mem[(32 * idx) + 140 len 20])
      call mem[(32 * idx) + 140 len 20].epoch() with:
           gas gas_remaining wei
      mem[mem[64]] = ext_call.return_data[0]
      if not ext_call.success:
          revert with ext_call.return_data[0 len return_data.size]
      _544 = mem[64]
      mem[64] = mem[64] + ceil32(return_data.size)
      require return_data.size >=ΓÇ▓ 32
      _545 = mem[_544]
      mem[mem[64] + 4] = mem[_544]
      require ext_code.size(addr(_539))
      call addr(_539).0x37033791 with:
           gas gas_remaining wei
          args _545
      mem[mem[64]] = ext_call.return_data[0]
      if not ext_call.success:
          revert with ext_call.return_data[0 len return_data.size]
      _548 = mem[64]
      mem[64] = mem[64] + ceil32(return_data.size)
      require return_data.size >=ΓÇ▓ 32
      _549 = mem[_548]
      if mem[_548] and _537 > -1 / mem[_548]:
          revert with 0, 17
      if s > !(mem[_548] * _537 / 10^18):
          revert with 0, 17
      if idx >= mem[ceil32(32 * ('cd', 4).length) + 97]:
          revert with 0, 50
      _551 = mem[(32 * idx) + ceil32(32 * ('cd', 4).length) + 129]
      if idx >= mem[96]:
          revert with 0, 50
      _553 = mem[(32 * idx) + 128]
      _554 = mem[64]
      mem[mem[64] + 36] = caller
      mem[mem[64] + 68] = this.address
      mem[mem[64] + 100] = _551
      _555 = mem[64]
      mem[mem[64]] = 100
      mem[64] = mem[64] + 132
      mem[_555 + 32] = 0x23b872dd00000000000000000000000000000000000000000000000000000000 or mem[_555 + 36 len 28]
      mem[64] = _554 + 196
      mem[_554 + 132] = 32
      mem[_554 + 164] = 'SafeERC20: low-level call failed'
      if eth.balance(this.address) < 0:
          revert with 0, 'Address: insufficient balance for call'
      if not ext_code.size(addr(_553)):
          revert with 0, 'Address: call to non-contract'
      _562 = mem[_555]
      t = 0
      while t < _562:
          mem[t + _554 + 196] = mem[t + _555 + 32]
          t = t + 32
          continue 
      if ceil32(_562) > _562:
          mem[_562 + _554 + 196] = 0
      call addr(_553).mem[_554 + 196 len 4] with:
           gas gas_remaining wei
          args mem[_554 + 200 len _562 - 4]
      if not return_data.size:
          if not ext_call.success:
              if mem[96]:
                  revert with memory
                    from 128
                     len mem[96]
              mem[_554 + 196] = 0x8c379a000000000000000000000000000000000000000000000000000000000
              mem[_554 + 200] = 32
              idx = 0
              while idx < 32:
                  mem[idx + _554 + 264] = mem[idx + _554 + 164]
                  idx = idx + 32
                  continue 
              revert with 0, 32, 32, mem[_554 + 264]
          if mem[96]:
              require mem[96] >=ΓÇ▓ 32
              require mem[128] == bool(mem[128])
              if not mem[128]:
                  revert with 0, 'SafeERC20: ERC20 operation did not succeed'
      else:
          mem[64] = _554 + ceil32(return_data.size) + 197
          mem[_554 + 196] = return_data.size
          mem[_554 + 228 len return_data.size] = ext_call.return_data[0 len return_data.size]
          if not ext_call.success:
              if return_data.size:
                  revert with ext_call.return_data[0 len return_data.size]
              mem[_554 + ceil32(return_data.size) + 197] = 0x8c379a000000000000000000000000000000000000000000000000000000000
              mem[_554 + ceil32(return_data.size) + 201] = 32
              idx = 0
              while idx < 32:
                  mem[idx + _554 + ceil32(return_data.size) + 265] = mem[idx + _554 + 164]
                  idx = idx + 32
                  continue 
              revert with 0, 32, 32, mem[_554 + ceil32(return_data.size) + 265]
          if return_data.size:
              require return_data.size >=ΓÇ▓ 32
              require mem[_554 + 228] == bool(mem[_554 + 228])
              if not mem[_554 + 228]:
                  revert with 0, 'SafeERC20: ERC20 operation did not succeed'
      if idx == -1:
          revert with 0, 17
      idx = idx + 1
      s = s + (_549 * _537 / 10^18)
      continue 
  isInit = 1
  if not caller:
      revert with 0, 'ERC20: mint to the zero address'
  if totalSupply > !s:
      revert with 0, 17
  totalSupply += s
  if balanceOf[caller] > !s:
      revert with 0, 17
  balanceOf[caller] += s
  log Transfer(
        address from=s,
        address to=0,
        uint256 tokens=caller)

def mint(uint256 _wad) payable: 
  mem[64] = 96
  require calldata.size - 4 >=ΓÇ▓ 32
  if not isInit:
      revert with 0, 'Not init'
  if not feeCollectorAddress:
      idx = 0
      while idx < unknown4be4e91f.length:
          mem[0] = unknown4be4e91f[idx]
          mem[32] = 10
          if unknowna622ee7c[stor9[idx]].field_256 and _wad > -1 / unknowna622ee7c[stor9[idx]].field_256:
              revert with 0, 17
          if not totalSupply:
              revert with 0, 18
          _265 = mem[64]
          mem[mem[64] + 36] = caller
          mem[mem[64] + 68] = this.address
          mem[mem[64] + 100] = unknowna622ee7c[stor9[idx]].field_256 * _wad / totalSupply
          _270 = mem[64]
          mem[mem[64]] = 100
          mem[64] = mem[64] + 132
          mem[_270 + 32] = 0x23b872dd00000000000000000000000000000000000000000000000000000000 or mem[_270 + 36 len 28]
          mem[64] = _265 + 196
          mem[_265 + 132] = 32
          mem[_265 + 164] = 'SafeERC20: low-level call failed'
          if eth.balance(this.address) < 0:
              revert with 0, 'Address: insufficient balance for call'
          if not ext_code.size(unknown4be4e91f[idx]):
              revert with 0, 'Address: call to non-contract'
          _291 = mem[_270]
          s = 0
          while s < _291:
              mem[s + _265 + 196] = mem[s + _270 + 32]
              s = s + 32
              continue 
          if ceil32(_291) > _291:
              mem[_291 + _265 + 196] = 0
          call unknown4be4e91f[idx].mem[_265 + 196 len 4] with:
               gas gas_remaining wei
              args mem[_265 + 200 len _291 - 4]
          if not return_data.size:
              if not ext_call.success:
                  if mem[96]:
                      revert with memory
                        from 128
                         len mem[96]
                  mem[_265 + 196] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                  mem[_265 + 200] = 32
                  idx = 0
                  while idx < 32:
                      mem[idx + _265 + 264] = mem[idx + _265 + 164]
                      idx = idx + 32
                      continue 
                  revert with 0, 32, 32, mem[_265 + 264]
              if mem[96]:
                  require mem[96] >=ΓÇ▓ 32
                  require mem[128] == bool(mem[128])
                  if not mem[128]:
                      revert with 0, 'SafeERC20: ERC20 operation did not succeed'
          else:
              mem[64] = _265 + ceil32(return_data.size) + 197
              mem[_265 + 196] = return_data.size
              mem[_265 + 228 len return_data.size] = ext_call.return_data[0 len return_data.size]
              if not ext_call.success:
                  if return_data.size:
                      revert with ext_call.return_data[0 len return_data.size]
                  mem[_265 + ceil32(return_data.size) + 197] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                  mem[_265 + ceil32(return_data.size) + 201] = 32
                  idx = 0
                  while idx < 32:
                      mem[idx + _265 + ceil32(return_data.size) + 265] = mem[idx + _265 + 164]
                      idx = idx + 32
                      continue 
                  revert with 0, 32, 32, mem[_265 + ceil32(return_data.size) + 265]
              if return_data.size:
                  require return_data.size >=ΓÇ▓ 32
                  require mem[_265 + 228] == bool(mem[_265 + 228])
                  if not mem[_265 + 228]:
                      revert with 0, 'SafeERC20: ERC20 operation did not succeed'
          mem[0] = unknown4be4e91f[idx]
          mem[32] = 10
          if unknowna622ee7c[stor9[idx]].field_256 > !(unknowna622ee7c[stor9[idx]].field_256 * _wad / totalSupply):
              revert with 0, 17
          unknowna622ee7c[stor9[idx]].field_256 += unknowna622ee7c[stor9[idx]].field_256 * _wad / totalSupply
          if idx == -1:
              revert with 0, 17
          idx = idx + 1
          continue 
  else:
      if block.timestamp < unknown1ba2b2e8:
          revert with 0, 17
      if block.timestamp - unknown1ba2b2e8 < 24 * 3600:
          idx = 0
          while idx < unknown4be4e91f.length:
              mem[0] = unknown4be4e91f[idx]
              mem[32] = 10
              if unknowna622ee7c[stor9[idx]].field_256 and _wad > -1 / unknowna622ee7c[stor9[idx]].field_256:
                  revert with 0, 17
              if not totalSupply:
                  revert with 0, 18
              _264 = mem[64]
              mem[mem[64] + 36] = caller
              mem[mem[64] + 68] = this.address
              mem[mem[64] + 100] = unknowna622ee7c[stor9[idx]].field_256 * _wad / totalSupply
              _268 = mem[64]
              mem[mem[64]] = 100
              mem[64] = mem[64] + 132
              mem[_268 + 32] = 0x23b872dd00000000000000000000000000000000000000000000000000000000 or mem[_268 + 36 len 28]
              mem[64] = _264 + 196
              mem[_264 + 132] = 32
              mem[_264 + 164] = 'SafeERC20: low-level call failed'
              if eth.balance(this.address) < 0:
                  revert with 0, 'Address: insufficient balance for call'
              if not ext_code.size(unknown4be4e91f[idx]):
                  revert with 0, 'Address: call to non-contract'
              _289 = mem[_268]
              s = 0
              while s < _289:
                  mem[s + _264 + 196] = mem[s + _268 + 32]
                  s = s + 32
                  continue 
              if ceil32(_289) > _289:
                  mem[_289 + _264 + 196] = 0
              call unknown4be4e91f[idx].mem[_264 + 196 len 4] with:
                   gas gas_remaining wei
                  args mem[_264 + 200 len _289 - 4]
              if not return_data.size:
                  if not ext_call.success:
                      if mem[96]:
                          revert with memory
                            from 128
                             len mem[96]
                      mem[_264 + 196] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                      mem[_264 + 200] = 32
                      idx = 0
                      while idx < 32:
                          mem[idx + _264 + 264] = mem[idx + _264 + 164]
                          idx = idx + 32
                          continue 
                      revert with 0, 32, 32, mem[_264 + 264]
                  if mem[96]:
                      require mem[96] >=ΓÇ▓ 32
                      require mem[128] == bool(mem[128])
                      if not mem[128]:
                          revert with 0, 'SafeERC20: ERC20 operation did not succeed'
              else:
                  mem[64] = _264 + ceil32(return_data.size) + 197
                  mem[_264 + 196] = return_data.size
                  mem[_264 + 228 len return_data.size] = ext_call.return_data[0 len return_data.size]
                  if not ext_call.success:
                      if return_data.size:
                          revert with ext_call.return_data[0 len return_data.size]
                      mem[_264 + ceil32(return_data.size) + 197] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                      mem[_264 + ceil32(return_data.size) + 201] = 32
                      idx = 0
                      while idx < 32:
                          mem[idx + _264 + ceil32(return_data.size) + 265] = mem[idx + _264 + 164]
                          idx = idx + 32
                          continue 
                      revert with 0, 32, 32, mem[_264 + ceil32(return_data.size) + 265]
                  if return_data.size:
                      require return_data.size >=ΓÇ▓ 32
                      require mem[_264 + 228] == bool(mem[_264 + 228])
                      if not mem[_264 + 228]:
                          revert with 0, 'SafeERC20: ERC20 operation did not succeed'
              mem[0] = unknown4be4e91f[idx]
              mem[32] = 10
              if unknowna622ee7c[stor9[idx]].field_256 > !(unknowna622ee7c[stor9[idx]].field_256 * _wad / totalSupply):
                  revert with 0, 17
              unknowna622ee7c[stor9[idx]].field_256 += unknowna622ee7c[stor9[idx]].field_256 * _wad / totalSupply
              if idx == -1:
                  revert with 0, 17
              idx = idx + 1
              continue 
      else:
          if totalSupply and unknownbce896f6 > -1 / totalSupply:
              revert with 0, 17
          if totalSupply * unknownbce896f6 and block.timestamp - unknown1ba2b2e8 > -1 / totalSupply * unknownbce896f6:
              revert with 0, 17
          unknown1ba2b2e8 = block.timestamp
          if not feeCollectorAddress:
              revert with 0, 'ERC20: mint to the zero address'
          if totalSupply > !((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600):
              revert with 0, 17
          totalSupply += (block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600
          mem[0] = feeCollectorAddress
          mem[32] = 2
          if balanceOf[stor13] > !((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600):
              revert with 0, 17
          balanceOf[stor13] += (block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600
          mem[96] = (block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600
          log Transfer(
                address from=((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600),
                address to=0,
                uint256 tokens=feeCollectorAddress)
          idx = 0
          while idx < unknown4be4e91f.length:
              mem[0] = unknown4be4e91f[idx]
              mem[32] = 10
              if unknowna622ee7c[stor9[idx]].field_256 and _wad > -1 / unknowna622ee7c[stor9[idx]].field_256:
                  revert with 0, 17
              if not totalSupply:
                  revert with 0, 18
              _263 = mem[64]
              mem[mem[64] + 36] = caller
              mem[mem[64] + 68] = this.address
              mem[mem[64] + 100] = unknowna622ee7c[stor9[idx]].field_256 * _wad / totalSupply
              _266 = mem[64]
              mem[mem[64]] = 100
              mem[64] = mem[64] + 132
              mem[_266 + 32] = 0x23b872dd00000000000000000000000000000000000000000000000000000000 or mem[_266 + 36 len 28]
              mem[64] = _263 + 196
              mem[_263 + 132] = 32
              mem[_263 + 164] = 'SafeERC20: low-level call failed'
              if eth.balance(this.address) < 0:
                  revert with 0, 'Address: insufficient balance for call'
              if not ext_code.size(unknown4be4e91f[idx]):
                  revert with 0, 'Address: call to non-contract'
              _287 = mem[_266]
              s = 0
              while s < _287:
                  mem[s + _263 + 196] = mem[s + _266 + 32]
                  s = s + 32
                  continue 
              if ceil32(_287) > _287:
                  mem[_287 + _263 + 196] = 0
              call unknown4be4e91f[idx].mem[_263 + 196 len 4] with:
                   gas gas_remaining wei
                  args mem[_263 + 200 len _287 - 4]
              if not return_data.size:
                  if not ext_call.success:
                      if mem[96]:
                          revert with memory
                            from 128
                             len mem[96]
                      mem[_263 + 196] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                      mem[_263 + 200] = 32
                      idx = 0
                      while idx < 32:
                          mem[idx + _263 + 264] = mem[idx + _263 + 164]
                          idx = idx + 32
                          continue 
                      revert with 0, 32, 32, mem[_263 + 264]
                  if mem[96]:
                      require mem[96] >=ΓÇ▓ 32
                      require mem[128] == bool(mem[128])
                      if not mem[128]:
                          revert with 0, 'SafeERC20: ERC20 operation did not succeed'
              else:
                  mem[64] = _263 + ceil32(return_data.size) + 197
                  mem[_263 + 196] = return_data.size
                  mem[_263 + 228 len return_data.size] = ext_call.return_data[0 len return_data.size]
                  if not ext_call.success:
                      if return_data.size:
                          revert with ext_call.return_data[0 len return_data.size]
                      mem[_263 + ceil32(return_data.size) + 197] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                      mem[_263 + ceil32(return_data.size) + 201] = 32
                      idx = 0
                      while idx < 32:
                          mem[idx + _263 + ceil32(return_data.size) + 265] = mem[idx + _263 + 164]
                          idx = idx + 32
                          continue 
                      revert with 0, 32, 32, mem[_263 + ceil32(return_data.size) + 265]
                  if return_data.size:
                      require return_data.size >=ΓÇ▓ 32
                      require mem[_263 + 228] == bool(mem[_263 + 228])
                      if not mem[_263 + 228]:
                          revert with 0, 'SafeERC20: ERC20 operation did not succeed'
              mem[0] = unknown4be4e91f[idx]
              mem[32] = 10
              if unknowna622ee7c[stor9[idx]].field_256 > !(unknowna622ee7c[stor9[idx]].field_256 * _wad / totalSupply):
                  revert with 0, 17
              unknowna622ee7c[stor9[idx]].field_256 += unknowna622ee7c[stor9[idx]].field_256 * _wad / totalSupply
              if idx == -1:
                  revert with 0, 17
              idx = idx + 1
              continue 
  if not caller:
      revert with 0, 'ERC20: mint to the zero address'
  if totalSupply > !_wad:
      revert with 0, 17
  totalSupply += _wad
  if balanceOf[caller] > !_wad:
      revert with 0, 17
  balanceOf[caller] += _wad
  log Transfer(
        address from=_wad,
        address to=0,
        uint256 tokens=caller)

def claim(uint256 _day) payable: 
  mem[64] = 96
  require calldata.size - 4 >=ΓÇ▓ 32
  if not isInit:
      revert with 0, 'Not init'
  if not feeCollectorAddress:
      if not caller:
          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: burn from the zero address'
      if balanceOf[caller] < _day:
          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: burn amount exceeds balance'
      mem[0] = caller
      mem[32] = 2
      balanceOf[caller] -= _day
      if totalSupply < _day:
          revert with 0, 17
      totalSupply -= _day
      mem[96] = _day
      log Transfer(
            address from=_day,
            address to=caller,
            uint256 tokens=0)
      idx = 0
      while idx < unknown4be4e91f.length:
          if unknowna622ee7c[stor9[idx]].field_256 and _day > -1 / unknowna622ee7c[stor9[idx]].field_256:
              revert with 0, 17
          if not totalSupply:
              revert with 0, 18
          mem[0] = unknown4be4e91f[idx]
          mem[32] = 10
          if unknowna622ee7c[stor9[idx]].field_256 < unknowna622ee7c[stor9[idx]].field_256 * _day / totalSupply:
              revert with 0, 17
          unknowna622ee7c[stor9[idx]].field_256 -= unknowna622ee7c[stor9[idx]].field_256 * _day / totalSupply
          _241 = mem[64]
          mem[mem[64] + 36] = caller
          mem[mem[64] + 68] = unknowna622ee7c[stor9[idx]].field_256 * _day / totalSupply
          _246 = mem[64]
          mem[mem[64]] = 68
          mem[64] = mem[64] + 100
          mem[_246 + 32] = 0xa9059cbb00000000000000000000000000000000000000000000000000000000 or mem[_246 + 36 len 28]
          mem[64] = _241 + 164
          mem[_241 + 100] = 32
          mem[_241 + 132] = 'SafeERC20: low-level call failed'
          if eth.balance(this.address) < 0:
              revert with 0, 'Address: insufficient balance for call'
          if not ext_code.size(unknown4be4e91f[idx]):
              revert with 0, 'Address: call to non-contract'
          _267 = mem[_246]
          s = 0
          while s < _267:
              mem[s + _241 + 164] = mem[s + _246 + 32]
              s = s + 32
              continue 
          if ceil32(_267) > _267:
              mem[_267 + _241 + 164] = 0
          call unknown4be4e91f[idx].mem[_241 + 164 len 4] with:
               gas gas_remaining wei
              args mem[_241 + 168 len _267 - 4]
          if not return_data.size:
              if not ext_call.success:
                  if mem[96]:
                      revert with memory
                        from 128
                         len mem[96]
                  mem[_241 + 164] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                  mem[_241 + 168] = 32
                  idx = 0
                  while idx < 32:
                      mem[idx + _241 + 232] = mem[idx + _241 + 132]
                      idx = idx + 32
                      continue 
                  revert with 0, 32, 32, mem[_241 + 232]
              if mem[96]:
                  require mem[96] >=ΓÇ▓ 32
                  require mem[128] == bool(mem[128])
                  if not mem[128]:
                      revert with 0, 'SafeERC20: ERC20 operation did not succeed'
          else:
              mem[64] = _241 + ceil32(return_data.size) + 165
              mem[_241 + 164] = return_data.size
              mem[_241 + 196 len return_data.size] = ext_call.return_data[0 len return_data.size]
              if not ext_call.success:
                  if return_data.size:
                      revert with ext_call.return_data[0 len return_data.size]
                  mem[_241 + ceil32(return_data.size) + 165] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                  mem[_241 + ceil32(return_data.size) + 169] = 32
                  idx = 0
                  while idx < 32:
                      mem[idx + _241 + ceil32(return_data.size) + 233] = mem[idx + _241 + 132]
                      idx = idx + 32
                      continue 
                  revert with 0, 32, 32, mem[_241 + ceil32(return_data.size) + 233]
              if return_data.size:
                  require return_data.size >=ΓÇ▓ 32
                  require mem[_241 + 196] == bool(mem[_241 + 196])
                  if not mem[_241 + 196]:
                      revert with 0, 'SafeERC20: ERC20 operation did not succeed'
          if idx == -1:
              revert with 0, 17
          idx = idx + 1
          continue 
  else:
      if block.timestamp < unknown1ba2b2e8:
          revert with 0, 17
      if block.timestamp - unknown1ba2b2e8 < 24 * 3600:
          if not caller:
              revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: burn from the zero address'
          if balanceOf[caller] < _day:
              revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: burn amount exceeds balance'
          mem[0] = caller
          mem[32] = 2
          balanceOf[caller] -= _day
          if totalSupply < _day:
              revert with 0, 17
          totalSupply -= _day
          mem[96] = _day
          log Transfer(
                address from=_day,
                address to=caller,
                uint256 tokens=0)
          idx = 0
          while idx < unknown4be4e91f.length:
              if unknowna622ee7c[stor9[idx]].field_256 and _day > -1 / unknowna622ee7c[stor9[idx]].field_256:
                  revert with 0, 17
              if not totalSupply:
                  revert with 0, 18
              mem[0] = unknown4be4e91f[idx]
              mem[32] = 10
              if unknowna622ee7c[stor9[idx]].field_256 < unknowna622ee7c[stor9[idx]].field_256 * _day / totalSupply:
                  revert with 0, 17
              unknowna622ee7c[stor9[idx]].field_256 -= unknowna622ee7c[stor9[idx]].field_256 * _day / totalSupply
              _240 = mem[64]
              mem[mem[64] + 36] = caller
              mem[mem[64] + 68] = unknowna622ee7c[stor9[idx]].field_256 * _day / totalSupply
              _244 = mem[64]
              mem[mem[64]] = 68
              mem[64] = mem[64] + 100
              mem[_244 + 32] = 0xa9059cbb00000000000000000000000000000000000000000000000000000000 or mem[_244 + 36 len 28]
              mem[64] = _240 + 164
              mem[_240 + 100] = 32
              mem[_240 + 132] = 'SafeERC20: low-level call failed'
              if eth.balance(this.address) < 0:
                  revert with 0, 'Address: insufficient balance for call'
              if not ext_code.size(unknown4be4e91f[idx]):
                  revert with 0, 'Address: call to non-contract'
              _265 = mem[_244]
              s = 0
              while s < _265:
                  mem[s + _240 + 164] = mem[s + _244 + 32]
                  s = s + 32
                  continue 
              if ceil32(_265) > _265:
                  mem[_265 + _240 + 164] = 0
              call unknown4be4e91f[idx].mem[_240 + 164 len 4] with:
                   gas gas_remaining wei
                  args mem[_240 + 168 len _265 - 4]
              if not return_data.size:
                  if not ext_call.success:
                      if mem[96]:
                          revert with memory
                            from 128
                             len mem[96]
                      mem[_240 + 164] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                      mem[_240 + 168] = 32
                      idx = 0
                      while idx < 32:
                          mem[idx + _240 + 232] = mem[idx + _240 + 132]
                          idx = idx + 32
                          continue 
                      revert with 0, 32, 32, mem[_240 + 232]
                  if mem[96]:
                      require mem[96] >=ΓÇ▓ 32
                      require mem[128] == bool(mem[128])
                      if not mem[128]:
                          revert with 0, 'SafeERC20: ERC20 operation did not succeed'
              else:
                  mem[64] = _240 + ceil32(return_data.size) + 165
                  mem[_240 + 164] = return_data.size
                  mem[_240 + 196 len return_data.size] = ext_call.return_data[0 len return_data.size]
                  if not ext_call.success:
                      if return_data.size:
                          revert with ext_call.return_data[0 len return_data.size]
                      mem[_240 + ceil32(return_data.size) + 165] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                      mem[_240 + ceil32(return_data.size) + 169] = 32
                      idx = 0
                      while idx < 32:
                          mem[idx + _240 + ceil32(return_data.size) + 233] = mem[idx + _240 + 132]
                          idx = idx + 32
                          continue 
                      revert with 0, 32, 32, mem[_240 + ceil32(return_data.size) + 233]
                  if return_data.size:
                      require return_data.size >=ΓÇ▓ 32
                      require mem[_240 + 196] == bool(mem[_240 + 196])
                      if not mem[_240 + 196]:
                          revert with 0, 'SafeERC20: ERC20 operation did not succeed'
              if idx == -1:
                  revert with 0, 17
              idx = idx + 1
              continue 
      else:
          if totalSupply and unknownbce896f6 > -1 / totalSupply:
              revert with 0, 17
          if totalSupply * unknownbce896f6 and block.timestamp - unknown1ba2b2e8 > -1 / totalSupply * unknownbce896f6:
              revert with 0, 17
          unknown1ba2b2e8 = block.timestamp
          if not feeCollectorAddress:
              revert with 0, 'ERC20: mint to the zero address'
          if totalSupply > !((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600):
              revert with 0, 17
          totalSupply += (block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600
          if balanceOf[stor13] > !((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600):
              revert with 0, 17
          balanceOf[stor13] += (block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600
          log Transfer(
                address from=((block.timestamp * totalSupply * unknownbce896f6) - (unknown1ba2b2e8 * totalSupply * unknownbce896f6) / 8760 * 10^6 * 24 * 3600),
                address to=0,
                uint256 tokens=feeCollectorAddress)
          if not caller:
              revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: burn from the zero address'
          if balanceOf[caller] < _day:
              revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'ERC20: burn amount exceeds balance'
          mem[0] = caller
          mem[32] = 2
          balanceOf[caller] -= _day
          if totalSupply < _day:
              revert with 0, 17
          totalSupply -= _day
          mem[96] = _day
          log Transfer(
                address from=_day,
                address to=caller,
                uint256 tokens=0)
          idx = 0
          while idx < unknown4be4e91f.length:
              if unknowna622ee7c[stor9[idx]].field_256 and _day > -1 / unknowna622ee7c[stor9[idx]].field_256:
                  revert with 0, 17
              if not totalSupply:
                  revert with 0, 18
              mem[0] = unknown4be4e91f[idx]
              mem[32] = 10
              if unknowna622ee7c[stor9[idx]].field_256 < unknowna622ee7c[stor9[idx]].field_256 * _day / totalSupply:
                  revert with 0, 17
              unknowna622ee7c[stor9[idx]].field_256 -= unknowna622ee7c[stor9[idx]].field_256 * _day / totalSupply
              _239 = mem[64]
              mem[mem[64] + 36] = caller
              mem[mem[64] + 68] = unknowna622ee7c[stor9[idx]].field_256 * _day / totalSupply
              _242 = mem[64]
              mem[mem[64]] = 68
              mem[64] = mem[64] + 100
              mem[_242 + 32] = 0xa9059cbb00000000000000000000000000000000000000000000000000000000 or mem[_242 + 36 len 28]
              mem[64] = _239 + 164
              mem[_239 + 100] = 32
              mem[_239 + 132] = 'SafeERC20: low-level call failed'
              if eth.balance(this.address) < 0:
                  revert with 0, 'Address: insufficient balance for call'
              if not ext_code.size(unknown4be4e91f[idx]):
                  revert with 0, 'Address: call to non-contract'
              _263 = mem[_242]
              s = 0
              while s < _263:
                  mem[s + _239 + 164] = mem[s + _242 + 32]
                  s = s + 32
                  continue 
              if ceil32(_263) > _263:
                  mem[_263 + _239 + 164] = 0
              call unknown4be4e91f[idx].mem[_239 + 164 len 4] with:
                   gas gas_remaining wei
                  args mem[_239 + 168 len _263 - 4]
              if not return_data.size:
                  if not ext_call.success:
                      if mem[96]:
                          revert with memory
                            from 128
                             len mem[96]
                      mem[_239 + 164] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                      mem[_239 + 168] = 32
                      idx = 0
                      while idx < 32:
                          mem[idx + _239 + 232] = mem[idx + _239 + 132]
                          idx = idx + 32
                          continue 
                      revert with 0, 32, 32, mem[_239 + 232]
                  if mem[96]:
                      require mem[96] >=ΓÇ▓ 32
                      require mem[128] == bool(mem[128])
                      if not mem[128]:
                          revert with 0, 'SafeERC20: ERC20 operation did not succeed'
              else:
                  mem[64] = _239 + ceil32(return_data.size) + 165
                  mem[_239 + 164] = return_data.size
                  mem[_239 + 196 len return_data.size] = ext_call.return_data[0 len return_data.size]
                  if not ext_call.success:
                      if return_data.size:
                          revert with ext_call.return_data[0 len return_data.size]
                      mem[_239 + ceil32(return_data.size) + 165] = 0x8c379a000000000000000000000000000000000000000000000000000000000
                      mem[_239 + ceil32(return_data.size) + 169] = 32
                      idx = 0
                      while idx < 32:
                          mem[idx + _239 + ceil32(return_data.size) + 233] = mem[idx + _239 + 132]
                          idx = idx + 32
                          continue 
                      revert with 0, 32, 32, mem[_239 + ceil32(return_data.size) + 233]
                  if return_data.size:
                      require return_data.size >=ΓÇ▓ 32
                      require mem[_239 + 196] == bool(mem[_239 + 196])
                      if not mem[_239 + 196]:
                          revert with 0, 'SafeERC20: ERC20 operation did not succeed'
              if idx == -1:
                  revert with 0, 17
              idx = idx + 1
              continue 


