# Palkeoramix decompiler. 

const unknown01d61c49 = 0xa724ccab2a885eaeb8d56c54eda31f467564681f6e8dd32c5b64d40110054
const unknown06b9c01c = 10^18
const unknown084a3237 = ('signextend', 23, ('ext_call.return_data', 0, 32)), uint32(ext_call.return_data
const decimals = 8
const version = 1
const unknown5a096b2f = 32, 352, mem[mem
const description = 32, 59, 0xfe4564656c53747265616d7320666f72205853746f636b73202d20706f776572656420627920436861696e6c696e6b20446174612053747265616d, mem
const unknown8205bf6a = ext_call.return_data
const unknown9c896d23 = 0x49b87e8ba8371782c7e2c34485d1cdac3ec2b530
const unknowndf577ce5 = 0x1630f08370917e79df0b7572395a5e907508bbbc

#
#  Regular functions
#

def _fallback() payable: # default function
  revert

def unknown50d25bcd() payable: 
  static call 0x49b87e8ba8371782c7e2c34485d1cdac3ec2b530.getPrice(bytes32 orderId) with:
          gas gas_remaining wei
         args 0xa724ccab2a885eaeb8d56c54eda31f467564681f6e8dd32c5b64d40110054
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 64
  require ext_call.return_data == ('signextend', 23, ('ext_call.return_data', 0, 32))
  require ext_call.return_data == ext_call.return_data[60 len 4]
  if ('signextend', 23, ('ext_call.return_data', 0, 32)) <=ΓÇ▓ 0:
      revert with 1308336163
  static call 0x1630f08370917e79df0b7572395a5e907508bbbc.0x7a2d13a with:
          gas gas_remaining wei
         args 10^18
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 32
  if not -mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) + (mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data < ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10):
      return (ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10 / 10^18)
  if 10^18 <= mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) - (mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data < ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10):
      revert with 1313373041, 17 xor 0
  return (0xaccb18165bd6fe31ae1cf318dc5b51eee0e1ba569b88cd74c1773b91fac10669 * Mask(238, 18, (ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) - mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data >> 18 or mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) - (mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data < ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) - (mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data > ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) << 238)

def unknownfeaf968c() payable: 
  static call 0x49b87e8ba8371782c7e2c34485d1cdac3ec2b530.getPrice(bytes32 orderId) with:
          gas gas_remaining wei
         args 0xa724ccab2a885eaeb8d56c54eda31f467564681f6e8dd32c5b64d40110054
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 64
  require ext_call.return_data == ('signextend', 23, ('ext_call.return_data', 0, 32))
  require ext_call.return_data == ext_call.return_data[60 len 4]
  static call 0x1630f08370917e79df0b7572395a5e907508bbbc.0x7a2d13a with:
          gas gas_remaining wei
         args 10^18
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size >=ΓÇ▓ 32
  if not -mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) + (mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data < ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10):
      return ext_call.return_data << 224, 
             ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10 / 10^18,
             ext_call.return_data << 224,
             ext_call.return_data << 224,
             uint32(ext_call.return_data)
  if 10^18 <= mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) - (mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data < ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10):
      revert with 1313373041, 17 xor 0
  return ext_call.return_data << 224, 
         0xaccb18165bd6fe31ae1cf318dc5b51eee0e1ba569b88cd74c1773b91fac10669 * Mask(238, 18, (ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) - mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data >> 18 or mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) - (mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data < ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) - (mulmod(('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10, ext_call.return_data > ext_call.return_data * ('signextend', 23, ('ext_call.return_data', 0, 32)) /ΓÇ▓ 10^10) << 238,
         ext_call.return_data << 224,
         ext_call.return_data << 224,
         uint32(ext_call.return_data)


