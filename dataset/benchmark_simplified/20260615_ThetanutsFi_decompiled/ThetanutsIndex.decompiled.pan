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

def balanceOf(address _owner) payable: 
  require calldata.size - 4 >=ΓÇ▓ 32
  require _owner == _owner
  return balanceOf[addr(_owner)]

def allowance(address _owner, address _spender) payable: 
  require calldata.size - 4 >=ΓÇ▓ 64
  require _owner == _owner
  require _spender == _spender
  return allowance[addr(_owner)][addr(_spender)]

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


