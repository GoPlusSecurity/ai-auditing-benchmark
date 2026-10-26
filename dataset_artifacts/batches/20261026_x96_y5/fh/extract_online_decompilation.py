from pathlib import Path
from html.parser import HTMLParser
import json,re,hashlib
ROOT=Path('dataset_artifacts/batches/20261026_x96_y5/fh')
class CodeBlocks(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True); self.depth=0; self.active=None; self.blocks=[]
    def handle_starttag(self,tag,attrs):
        if tag=='div':
            self.depth+=1
            attr=dict(attrs)
            if self.active is None and bool({'code','hljs'} & set(attr.get('class','').split())):
                self.active={'depth':self.depth,'class':attr.get('class',''),'text':[]}
    def handle_endtag(self,tag):
        if tag=='div':
            if self.active is not None and self.active['depth']==self.depth:
                self.blocks.append(self.active); self.active=None
            self.depth-=1
    def handle_data(self,data):
        if self.active is not None:self.active['text'].append(data)
parser=CodeBlocks(); parser.feed((ROOT/'attacker-ethervm-response.html').read_text())
print([(b['class'],len(''.join(b['text']))) for b in parser.blocks])
assert len(parser.blocks)==2
high,disasm=[''.join(b['text']) for b in parser.blocks]
assert high.startswith('contract Contract {')
(ROOT/'attacker-ethervm-decompiled.txt').write_text(high,encoding='utf-8')
(ROOT/'attacker-ethervm-disassembly.txt').write_text(disasm,encoding='utf-8')
raw=bytes.fromhex(json.loads((ROOT/'attacker-runtime-before-blast.json').read_text())['result'][2:])
covered=set(); mismatches=[]
for line in disasm.splitlines():
    match=re.match(r'^\s*([0-9A-Fa-f]{4,})\s+([0-9A-Fa-f]{2})\s+(.*)$',line)
    if not match:continue
    offset=int(match[1],16); byte=int(match[2],16); rest=match[3]
    if raw[offset]!=byte:mismatches.append({'offset':offset,'kind':'opcode'})
    covered.add(offset)
    if 0x60<=byte<=0x7f:
        value=re.search(r'0x([0-9a-fA-F]+)',rest)
        assert value, line
        operand=bytes.fromhex(value[1])
        if raw[offset+1:offset+1+len(operand)]!=operand:mismatches.append({'offset':offset,'kind':'operand'})
        covered.update(range(offset+1,offset+1+len(operand)))
result={'kind':'public_online_decompiler_output','service':'ethervm.io Online Solidity Decompiler',
 'service_url':'https://ethervm.io/decompile','method':'POST of archived historical runtime bytecode',
 'engine_version':None,'engine_version_status':'The returned page does not report the decompiler engine version. Frontend library/CDN versions are not substituted.',
 'runtime_block_numbers':[117979401,117979402],'runtime_bytes':len(raw),'runtime_sha256':hashlib.sha256(raw).hexdigest(),
 'historical_before_equals_attack':json.loads((ROOT/'attacker-runtime-before-blast.json').read_text())['result']==json.loads((ROOT/'attacker-runtime-attack-blast.json').read_text())['result'],
 'decompiled_path':'attacker-ethervm-decompiled.txt','raw_response_path':'attacker-ethervm-response.html',
 'extraction':'Unmodified text content of the service decompilation code div; HTML markup removed and entities decoded. No manually written pseudo-code.',
 'disassembly_path':'attacker-ethervm-disassembly.txt','response_disassembly_bytes_checked':len(covered),
 'response_disassembly_mismatches':mismatches,'response_disassembly_complete_byte_coverage':covered==set(range(len(raw))),
 'decompiler_error_comment_count':high.count('// Error:'),
 'public_method_names_caveat':'Service names use a 4byte signature cache; names and high-level reconstruction are not authoritative source or a full execution trace.',
 'not_original_source':True,'not_used_to_replace_vulnerable_original_source':True}
assert not mismatches and result['response_disassembly_complete_byte_coverage']
for name in ['attacker-ethervm-response.html','attacker-ethervm-decompiled.txt','attacker-ethervm-disassembly.txt','attacker-ethervm-request.txt']:
    p=ROOT/name;result.setdefault('artifacts',[]).append({'path':name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
(ROOT/'decompilation-provenance.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:result[k] for k in ['runtime_bytes','response_disassembly_bytes_checked','response_disassembly_complete_byte_coverage','decompiler_error_comment_count']}))