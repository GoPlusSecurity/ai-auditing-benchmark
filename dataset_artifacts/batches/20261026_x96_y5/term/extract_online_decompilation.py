"""Extract service-returned decompilation verbatim and verify its disassembly bytes."""
from pathlib import Path
from html.parser import HTMLParser
import json,re,hashlib
ROOT=Path(__file__).resolve().parent
class CodeBlocks(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True); self.depth=0; self.active=None; self.blocks=[]
    def handle_starttag(self,tag,attrs):
        if tag=='div':
            self.depth+=1; attr=dict(attrs)
            if self.active is None and bool({'code','hljs'} & set(attr.get('class','').split())):
                self.active={'depth':self.depth,'class':attr.get('class',''),'text':[]}
    def handle_endtag(self,tag):
        if tag=='div':
            if self.active is not None and self.active['depth']==self.depth:
                self.blocks.append(self.active); self.active=None
            self.depth-=1
    def handle_data(self,data):
        if self.active is not None:self.active['text'].append(data)
metas=json.loads((ROOT/'bytecode_metadata.json').read_text())
results=[]
for k,meta in zip(['attacker-strategy','helper-implementation'],metas):
    parser=CodeBlocks();parser.feed((ROOT/f'{k}-ethervm-response.html').read_text('utf-8'))
    if len(parser.blocks)!=2:
        failure={**meta,'kind':'online_decompilation_failure','service':'ethervm.io Online Solidity Decompiler','service_url':'https://ethervm.io/decompile','engine_version':None,'status':'failed','reason':'Service returned Decompilation timed out / Disassembly timed out / No output available.','raw_response_path':f'{k}-ethervm-response.html','request_path':f'{k}-ethervm-request.txt','not_original_source':True,'no_decompiled_output_available':True}
        for suffix in ['ethervm-response.html','ethervm-request.txt']:
            pp=ROOT/f'{k}-{suffix}';failure.setdefault('artifacts',[]).append({'path':pp.name,'sha256':hashlib.sha256(pp.read_bytes()).hexdigest(),'bytes':pp.stat().st_size})
        results.append(failure);print(k,'service failure recorded');continue
    high,disasm=[''.join(b['text']) for b in parser.blocks]
    assert high.startswith('contract Contract {')
    (ROOT/f'{k}-ethervm-decompiled.txt').write_text(high,encoding='utf-8')
    (ROOT/f'{k}-ethervm-disassembly.txt').write_text(disasm,encoding='utf-8')
    raw=bytes.fromhex((ROOT/f'{k}-creation-runtime.hex').read_text().strip()[2:])
    covered=set();mismatches=[]
    for line in disasm.splitlines():
        m=re.match(r'^\s*([0-9A-Fa-f]{4,})\s+([0-9A-Fa-f]{2})\s+(.*)$',line)
        if not m:continue
        offset=int(m[1],16);byte=int(m[2],16);rest=m[3]
        if offset>=len(raw) or raw[offset]!=byte:mismatches.append({'offset':offset,'kind':'opcode'})
        covered.add(offset)
        if 0x60<=byte<=0x7f:
            value=re.search(r'0x([0-9a-fA-F]+)',rest);assert value,line
            operand=bytes.fromhex(value[1])
            if raw[offset+1:offset+1+len(operand)]!=operand:mismatches.append({'offset':offset,'kind':'operand'})
            covered.update(range(offset+1,offset+1+len(operand)))
    result={**meta,'kind':'public_online_decompiler_output','service':'ethervm.io Online Solidity Decompiler','service_url':'https://ethervm.io/decompile','method':'POST archived original deployment runtime bytecode','engine_version':None,'engine_version_status':'Returned page does not report decompiler engine version; frontend library versions are not substituted.','decompiled_path':f'{k}-ethervm-decompiled.txt','raw_response_path':f'{k}-ethervm-response.html','extraction':'Unmodified text of returned high-level code div; HTML tags removed and entities decoded; no manually reconstructed code.','disassembly_path':f'{k}-ethervm-disassembly.txt','response_disassembly_bytes_checked':len(covered),'response_disassembly_mismatches':mismatches,'response_disassembly_complete_byte_coverage':covered==set(range(len(raw))),'decompiler_error_comment_count':high.count('// Error:'),'public_method_names_caveat':'Service-selected function names and variables are inferred, not original author names. High-level reconstruction may contain Error comments and is not a complete execution proof.','not_original_source':True,'not_used_to_replace_vulnerable_original_source':True}
    assert not mismatches and result['response_disassembly_complete_byte_coverage']
    for suffix in ['ethervm-response.html','ethervm-decompiled.txt','ethervm-disassembly.txt','ethervm-request.txt']:
        p=ROOT/f'{k}-{suffix}';result.setdefault('artifacts',[]).append({'path':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
    results.append(result)
    print(k,'byte_coverage',len(covered),'high_level_lines',len(high.splitlines()),'Error_comments',result['decompiler_error_comment_count'])
(ROOT/'decompilation-provenance.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

