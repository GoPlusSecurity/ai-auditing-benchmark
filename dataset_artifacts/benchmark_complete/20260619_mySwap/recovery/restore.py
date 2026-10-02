"""Dependency-free Sierra 1.3 decoding and conservative SSA recovery.

Serialization follows starkware-libs/cairo v2.2.0:
crates/cairo-lang-starknet/src/{felt252_serde,felt252_vec_compression}.rs
The upstream serialization reference is Apache-2.0 licensed.
This tool retains unknown user identifiers and all branch arms; it does not
recover original Cairo names or claim that its pseudo-Cairo recompiles.
"""
import hashlib

PRIME = 2**251 + 17 * 2**192 + 1
U64 = 2**64 - 1
U128 = 2**128 - 1


def keccak256(value):
    rc = [0x1,0x8082,0x800000000000808a,0x8000000080008000,
          0x808b,0x80000001,0x8000000080008081,0x8000000000008009,
          0x8a,0x88,0x80008009,0x8000000a,0x8000808b,
          0x800000000000008b,0x8000000000008089,0x8000000000008003,
          0x8000000000008002,0x8000000000000080,0x800a,
          0x800000008000000a,0x8000000080008081,0x8000000000008080,
          0x80000001,0x8000000080008008]
    rotation = [0,1,62,28,27,36,44,6,55,20,3,10,43,25,39,
                41,45,15,21,8,18,2,61,56,14]
    def rol(v, n):
        return ((v << n) | (v >> ((64-n) % 64))) & U64
    padded = bytearray(value)
    padded.append(1)
    padded.extend(bytes((-len(padded)) % 136))
    padded[-1] |= 128
    a = [0] * 25
    for offset in range(0, len(padded), 136):
        for i in range(17):
            a[i] ^= int.from_bytes(padded[offset+8*i:offset+8*i+8], 'little')
        for constant in rc:
            c = [a[x]^a[x+5]^a[x+10]^a[x+15]^a[x+20] for x in range(5)]
            d = [c[(x-1)%5]^rol(c[(x+1)%5],1) for x in range(5)]
            a = [v^d[i%5] for i,v in enumerate(a)]
            b = [0]*25
            for x in range(5):
                for y in range(5):
                    b[y+5*((2*x+3*y)%5)] = rol(a[x+5*y], rotation[x+5*y])
            for x in range(5):
                for y in range(5):
                    a[x+5*y] = b[x+5*y] ^ ((~b[(x+1)%5+5*y]) & b[(x+2)%5+5*y])
            a[0] ^= constant
    return b''.join(v.to_bytes(8, 'little') for v in a)[:32]


def starknet_keccak(value):
    return int.from_bytes(keccak256(value), 'big') & (2**250-1)


HADES = [int.from_bytes(hashlib.sha256(('Hades'+str(i)).encode()).digest(), 'big') % PRIME
         for i in range(273)]


def poseidon_many(values):
    values = list(values) + [1]
    if len(values) % 2:
        values.append(0)
    a,b,c = 0,0,0
    for offset in range(0,len(values),2):
        a = (a + values[offset]) % PRIME
        b = (b + values[offset+1]) % PRIME
        for r in range(91):
            a = (a + HADES[3*r]) % PRIME
            b = (b + HADES[3*r+1]) % PRIME
            c = (c + HADES[3*r+2]) % PRIME
            if r < 4 or r >= 87:
                a = pow(a,3,PRIME)
                b = pow(b,3,PRIME)
            c = pow(c,3,PRIME)
            total = a+b+c
            a,b,c = (total+2*a)%PRIME, (total-2*b)%PRIME, (total-3*c)%PRIME
    return a


def as_int(value):
    return int(value,0) if isinstance(value,str) else value


def class_hash(value):
    if not isinstance(value['abi'], str):
        raise ValueError('ABI must be the exact original serialized string')
    entry_hashes = []
    for kind in ['EXTERNAL','L1_HANDLER','CONSTRUCTOR']:
        flat = []
        for entry in value['entry_points_by_type'][kind]:
            flat.extend([as_int(entry['selector']), as_int(entry['function_idx'])])
        entry_hashes.append(poseidon_many(flat))
    return poseidon_many([
        int.from_bytes(('CONTRACT_CLASS_V'+value['contract_class_version']).encode(),'big'),
        *entry_hashes, starknet_keccak(value['abi'].encode()),
        poseidon_many(map(as_int,value['sierra_program']))])


def words_per_felt(base):
    if base < 256 or base & (base-1):
        raise ValueError('Invalid compression base')
    value,count = base,0
    while value < PRIME:
        value *= base
        count += 1
    if count == 0:
        raise ValueError('Compression base exceeds field')
    return count


def decompress(values):
    size,padding = values[:2]
    table = values[2:2+size]
    if len(table) != size or len(values) <= 2+size:
        raise ValueError('Truncated codebook')
    remaining = values[2+size]
    base = size+padding
    width = words_per_felt(base)
    if len(values)-3-size != (remaining+width-1)//width:
        raise ValueError('Wrong packed length')
    out = []
    for value in values[3+size:]:
        if not 0 <= value < PRIME:
            raise ValueError('Packed value outside field')
        count = min(width,remaining)
        for _ in range(count):
            value,code = divmod(value,base)
            if code >= size:
                raise ValueError('Reference outside codebook')
            out.append(table[code])
        if value:
            raise ValueError('Nonzero unused packed digits')
        remaining -= count
    return out


def compress(values):
    code = {v:i for i,v in enumerate(dict.fromkeys(values))}
    base = 1 << (max(256,len(code))-1).bit_length()
    width = words_per_felt(base)
    out = [len(code),base-len(code),*code,len(values)]
    for i in range(0,len(values),width):
        packed = 0
        for v in reversed(values[i:i+width]):
            packed = packed*base+code[v]
        out.append(packed)
    return out


LONG_IDS = ['storage_address_from_base_and_offset','contract_address_try_from_felt252',
            'storage_base_address_from_felt252','storage_address_try_from_felt252',
            'secp256k1_get_point_from_x_syscall','secp256r1_get_point_from_x_syscall']
LONG_NAMES = {starknet_keccak(s.encode()):s for s in LONG_IDS}


def generic_name(value):
    if value in LONG_NAMES:
        return LONG_NAMES[value]
    raw = value.to_bytes(max(1,(value.bit_length()+7)//8),'big')
    if all(32 <= c <= 126 for c in raw):
        return raw.decode('ascii')
    return 'unknown_generic_'+hex(value)


class Reader:
    def __init__(self, values):
        self.values,self.i = values,0
    def one(self):
        if self.i >= len(self.values):
            raise ValueError('Truncated program at '+str(self.i))
        value = self.values[self.i]
        self.i += 1
        return value
    def vec(self):
        count = self.one()
        if count > len(self.values)-self.i:
            raise ValueError('Vector size exceeds remaining input')
        return [self.one() for _ in range(count)]
    def generic_args(self,count=None):
        if count is None:
            count = self.one()
        out = [(self.one(),self.one()) for _ in range(count)]
        if any(tag > 5 for tag,_ in out):
            raise ValueError('Unknown generic argument tag')
        return out


def decode_program(values):
    r = Reader(values)
    types,libfuncs,statements,functions = [],[],[],[]
    for i in range(r.one()):
        name,packed = r.one(),r.one()
        types.append({'id':i,'name':generic_name(name),'name_felt':name,
                      'flags':packed>>128,'args':r.generic_args(packed & U128)})
    for i in range(r.one()):
        name = r.one()
        libfuncs.append({'id':i,'name':generic_name(name),'name_felt':name,'args':r.generic_args()})
    for _ in range(r.one()):
        kind = r.one()
        if kind == 0:
            libfunc,args = r.one(),r.vec()
            branches = []
            for _ in range(r.one()):
                target = r.one()
                branches.append({'target':None if target == U64 else target,'results':r.vec()})
            statements.append({'kind':'invoke','libfunc':libfunc,'args':args,'branches':branches})
        elif kind == 1:
            statements.append({'kind':'return','values':r.vec()})
        else:
            raise ValueError('Unknown statement variant '+str(kind))
    for i in range(r.one()):
        params,rets = r.vec(),r.vec()
        variables = [r.one() for _ in params]
        functions.append({'id':i,'param_types':params,'ret_types':rets,'params':variables,'entry':r.one()})
    if r.i != len(values):
        raise ValueError('Trailing undecoded program words')
    return {'types':types,'libfuncs':libfuncs,'statements':statements,'functions':functions}


def encode_program(program):
    out = []
    def vec(values):
        out.extend([len(values),*values])
    def args(values):
        for tag,value in values:
            out.extend([tag,value])
    out.append(len(program['types']))
    for t in program['types']:
        out.extend([t['name_felt'],(t['flags']<<128)|len(t['args'])])
        args(t['args'])
    out.append(len(program['libfuncs']))
    for t in program['libfuncs']:
        out.extend([t['name_felt'],len(t['args'])])
        args(t['args'])
    out.append(len(program['statements']))
    for s in program['statements']:
        if s['kind'] == 'return':
            out.append(1)
            vec(s['values'])
        else:
            out.extend([0,s['libfunc']])
            vec(s['args'])
            out.append(len(s['branches']))
            for b in s['branches']:
                out.append(U64 if b['target'] is None else b['target'])
                vec(b['results'])
    out.append(len(program['functions']))
    for f in program['functions']:
        vec(f['param_types'])
        vec(f['ret_types'])
        out.extend([*f['params'],f['entry']])
    return out


def function_ranges(program):
    fs = program['functions']
    entries = [f['entry'] for f in fs]
    if entries != sorted(set(entries)) or entries[0] != 0:
        raise ValueError('Expected distinct, ordered, contiguous function entries')
    return {f['id']:(f['entry'],entries[i+1] if i+1<len(fs) else len(program['statements']))
            for i,f in enumerate(fs)}


def function_dependencies(program):
    graph = {}
    for fid,(start,end) in function_ranges(program).items():
        deps = set()
        for pc in range(start,end):
            s = program['statements'][pc]
            if s['kind'] == 'invoke':
                lib = program['libfuncs'][s['libfunc']]
                deps.update(value for tag,value in lib['args'] if tag == 3)
                for b in s['branches']:
                    target = pc+1 if b['target'] is None else b['target']
                    if not start <= target < end:
                        raise ValueError(f'Branch {pc} escapes function {fid}: {target}')
        graph[fid] = sorted(deps)
    return graph


def closure(graph, roots):
    selected = set(roots)
    pending = list(roots)
    while pending:
        for fid in graph[pending.pop()]:
            if fid not in selected:
                selected.add(fid)
                pending.append(fid)
    return selected


def render_sierra(program, debug=None):
    """Standard Sierra text; debug names are only accepted from an input fixture."""
    debug = debug or {}
    tn = dict(debug.get('type_names',[]))
    ln = dict(debug.get('libfunc_names',[]))
    fn = dict(debug.get('user_func_names',[]))
    ti = lambda n: tn.get(n,f'[{n}]')
    li = lambda n: ln.get(n,f'[{n}]')
    fi = lambda n: fn.get(n,f'[{n}]')
    def arg(pair):
        tag,v = pair
        return [lambda:f'ut@[{v}]',lambda:ti(v),lambda:str(v),
                lambda:'user@'+fi(v),lambda:'lib@'+li(v),lambda:str(-v)][tag]()
    def long(d):
        return d['name'] + ('<'+', '.join(map(arg,d['args']))+'>' if d['args'] else '')
    out = []
    for t in program['types']:
        flags = t['flags']
        info = ''
        if flags:
            info = ' ['+', '.join(f'{name}: {str(bool(flags&bit)).lower()}' for name,bit in
                       [('storable',1),('drop',2),('dup',4),('zero_sized',8)])+']'
        out.append(f"type {ti(t['id'])} = {long(t)}{info};")
    out.append('')
    out += [f"libfunc {li(l['id'])} = {long(l)};" for l in program['libfuncs']]
    out.append('')
    variables = lambda vs:', '.join(f'[{v}]' for v in vs)
    for pc,s in enumerate(program['statements']):
        if s['kind'] == 'return':
            out.append('return('+variables(s['values'])+');')
        else:
            call = li(s['libfunc'])+'('+variables(s['args'])+')'
            bs = s['branches']
            if len(bs)==1 and bs[0]['target'] is None:
                out.append(call+' -> ('+variables(bs[0]['results'])+');')
            else:
                out.append(call+' { '+ ' '.join(('fallthrough' if b['target'] is None else str(b['target']))+
                                  '('+variables(b['results'])+')' for b in bs)+' };')
        out[-1] += f' // {pc}'
    out.append('')
    for f in program['functions']:
        params = ', '.join(f'[{v}]: {ti(t)}' for v,t in zip(f['params'],f['param_types']))
        out.append(f"{fi(f['id'])}@{f['entry']}({params}) -> ("+', '.join(map(ti,f['ret_types']))+');')
    return '\n'.join(out)+'\n'


def render_decompiled(program, entries, selected=None):
    selected = set(range(len(program['functions']))) if selected is None else set(selected)
    ranges = function_ranges(program)
    public = {e['function_idx']:e['name'] for e in entries}
    func_name = lambda i:f'{public[i]}__entry_{i}' if i in public else f'fn_{i}'
    used_libs = {s['libfunc'] for i in selected for s in program['statements'][ranges[i][0]:ranges[i][1]]
                 if s['kind']=='invoke'}
    used_types = {t for i in selected for t in program['functions'][i]['param_types']+program['functions'][i]['ret_types']}
    for i in used_libs:
        used_types.update(v for tag,v in program['libfuncs'][i]['args'] if tag == 1)
    pending = list(used_types)
    while pending:
        for tag,v in program['types'][pending.pop()]['args']:
            if tag == 1 and v not in used_types:
                used_types.add(v)
                pending.append(v)
    def arg(pair):
        tag,v = pair
        return [lambda:f'user_type_{v:x}',lambda:f'T{v}',lambda:str(v),
                lambda:func_name(v),lambda:f'lib_{v}',lambda:str(-v)][tag]()
    def long(d):
        return d['name']+('<'+', '.join(map(arg,d['args']))+'>' if d['args'] else '')
    variables = lambda vs:', '.join(f'v{v}' for v in vs)
    out = ['// mySwap CL: mechanically recovered Sierra in SSA / pseudo-Cairo notation.',
           '// NOT original Cairo source. NOT a compilable Cairo translation.',
           '// Every L<number> is an ORIGINAL, zero-based Sierra statement index.',
           '// Numeric private names are retained. Public entry names come from ABI selector hashes.',
           '// Each branch arm retains its ordinal, output variables and absolute target.',
           '// Builtins, range checks, panic branches and compiler operations are retained.',
           '// Branch ordinals are NOT assumed to mean true/false; use the libfunc semantics.',
           '// See SOURCE.md and onchain/mySwap.contract_class.json for provenance.', '']
    for t in program['types']:
        if t['id'] in used_types:
            out.append(f"type T{t['id']} = {long(t)}; // serialized_flags={hex(t['flags'])}")
    out.append('')
    for l in program['libfuncs']:
        if l['id'] in used_libs:
            out.append(f"// lib_{l['id']} = {long(l)}")
    out.append('')
    for f in program['functions']:
        if f['id'] not in selected:
            continue
        start,end = ranges[f['id']]
        out.append(f"// function_id={f['id']}; original_statements=[{start}, {end}); count={end-start}")
        params = ', '.join(f'v{v}: T{t}' for v,t in zip(f['params'],f['param_types']))
        out.append(f"fn {func_name(f['id'])}({params}) -> ("+', '.join(f'T{t}' for t in f['ret_types'])+') {')
        for pc in range(start,end):
            s = program['statements'][pc]
            if s['kind']=='return':
                out.append(f"    L{pc}: return ({variables(s['values'])});")
                continue
            l = program['libfuncs'][s['libfunc']]
            call = long(l)+'('+variables(s['args'])+')'
            comment = f" // lib_{l['id']}"
            if l['name']=='felt252_const' and l['args']:
                n=l['args'][0][1]
                raw=n.to_bytes(max(1,(n.bit_length()+7)//8),'big')
                if len(raw)>1 and all(32<=c<=126 for c in raw):
                    comment += ' ascii='+repr(raw.decode())
            if len(s['branches']) == 1:
                b = s['branches'][0]
                target=pc+1 if b['target'] is None else b['target']
                out.append(f"    L{pc}: let ({variables(b['results'])}) = {call}; goto L{target};{comment}")
            else:
                out.append(f'    L{pc}: match {call} {{{comment}')
                for ordinal,b in enumerate(s['branches']):
                    target=pc+1 if b['target'] is None else b['target']
                    out.append(f"        branch_{ordinal}({variables(b['results'])}) => goto L{target},")
                out.append('    }')
        out.extend(['}',''])
    return '\n'.join(out)


def recover(contract, view='complete'):
    import json
    words = list(map(as_int,contract['sierra_program']))
    unpacked = decompress(words[6:])
    program = decode_program(unpacked)
    if encode_program(program) != unpacked or compress(unpacked) != words[6:]:
        raise ValueError('Lossless round-trip failed')
    abi = json.loads(contract['abi'])
    def functions(items):
        for item in items:
            if item['type'] in ['function','constructor','l1_handler']:
                yield item
            yield from functions(item.get('items',[]))
    names = {starknet_keccak(i['name'].encode()):i['name'] for i in functions(abi)}
    entries = []
    for kind,items in contract['entry_points_by_type'].items():
        for e in items:
            name = names[as_int(e['selector'])]
            entries.append({**e,'name':name,'kind':kind,'statement':program['functions'][e['function_idx']]['entry']})
    graph = function_dependencies(program)
    roots = [e['function_idx'] for e in entries if e['name'] in
             ['create_pool','mint','initialize_pool_price','burn','collect']]
    selected = set(graph) if view=='complete' else closure(graph,roots)
    ranges = function_ranges(program)
    statements = [program['statements'][pc] for fid in sorted(selected) for pc in range(*ranges[fid])]
    text = render_decompiled(program,entries,selected)
    sierra = render_sierra(program)
    report = {
        'method':'Dependency-free deterministic Sierra decoding and conservative SSA / pseudo-Cairo recovery',
        'original_cairo_recovered':False,'recompilable_cairo':False,
        'class_hash':hex(class_hash(contract)),
        'sierra_version':'.'.join(map(str,words[:3])),
        'compiler_version_from_serialized_header':'.'.join(map(str,words[3:6])),
        'serialized_felt_count':len(words),'uncompressed_word_count':len(unpacked),
        'full_program_counts':{k:len(v) for k,v in program.items()},
        'lossless_compression_roundtrip':True,'lossless_program_roundtrip':True,
        'abi_entry_point_selectors_matched':len(entries),
        'dataset_view':view,'root_entry_function_ids':roots,
        'selected_function_count':len(selected),'selected_statement_count':len(statements),
        'selected_branch_arm_count':sum(len(s.get('branches',[])) for s in statements),
        'selected_return_count':sum(s['kind']=='return' for s in statements),
        'selected_function_ids':sorted(selected),
        'branch_targets_stay_inside_functions':True,
        'internal_call_graph_closed':all(set(graph[f])<=selected for f in selected),
        'function_ranges':[{'id':i,'start_inclusive':ranges[i][0],'end_exclusive':ranges[i][1],
                            'calls':graph[i]} for i in sorted(selected)]}
    return program,entries,text,sierra,report


def main():
    import argparse,json
    from pathlib import Path
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--class-file',type=Path,required=True)
    parser.add_argument('--view',choices=['complete','simplified'],default='complete')
    parser.add_argument('--expected-class-hash',required=True)
    parser.add_argument('--output',type=Path,help='Omit to verify without writing files')
    opts = parser.parse_args()
    contract = json.loads(opts.class_file.read_text(encoding='utf8'))
    program,entries,text,sierra,report = recover(contract,opts.view)
    if as_int(report['class_hash']) != as_int(opts.expected_class_hash):
        raise ValueError('Recovered class does not match expected historical class')
    if opts.output:
        opts.output.mkdir(parents=True,exist_ok=True)
        (opts.output/'mySwap.decompiled.cairo').write_text(text,encoding='utf8')
        if opts.view=='complete':
            (opts.output/'mySwap.sierra').write_text(sierra,encoding='utf8')
        (opts.output/'recovery.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print(json.dumps({k:v for k,v in report.items() if k not in ['function_ranges','selected_function_ids']},indent=2))


if __name__ == '__main__':
    main()
