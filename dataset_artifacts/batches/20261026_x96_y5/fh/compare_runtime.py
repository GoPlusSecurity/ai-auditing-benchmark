"""Compare archived byte arrays; no EVM execution and no compiler invocation."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parent
SOURCES={'token':'token-source.json','v2_router':'v2-router-source.json','v3_router':'v3-router-source.json','pair':'pair-reference-source.json','usdt':'usdt-source.json'}
results=[]
for role,name in SOURCES.items():
    src=json.loads((ROOT/name).read_text())
    runtime=src['runtimeBytecode']
    onchain=bytes.fromhex(runtime['onchainBytecode'][2:])
    recompiled=bytes.fromhex(runtime['recompiledBytecode'][2:])
    normalized=bytearray(recompiled)
    ranges=[]
    for transform in runtime.get('transformations',[]):
        reason,key,offset=transform['reason'],transform['id'],transform['offset']
        family='immutables' if reason=='immutable' else reason
        value=bytes.fromhex(runtime['transformationValues'][family][key][2:])
        normalized[offset:offset+len(value)]=value
        ranges.append({'reason':reason,'offset':offset,'length':len(value)})
    before=json.loads((ROOT/f'{role}-runtime-before-blast.json').read_text())['result']
    attack=json.loads((ROOT/f'{role}-runtime-attack-blast.json').read_text())['result']
    before_bytes=bytes.fromhex(before[2:]); attack_bytes=bytes.fromhex(attack[2:])
    result={'role':role,'source_response':name,'source_verified_address':src['address'],
            'historical_reads':[{'file':f'{role}-runtime-before-blast.json','block':117979401},{'file':f'{role}-runtime-attack-blast.json','block':117979402}],
            'before_equals_attack':before_bytes==attack_bytes,
            'before_equals_source_onchain':before_bytes==onchain,
            'attack_equals_source_onchain':attack_bytes==onchain,
            'before_equals_recompiled':before_bytes==recompiled,
            'provider_recompiled_plus_reported_transforms_equals_historical':bytes(normalized)==before_bytes,
            'runtime_bytes':len(before_bytes),'runtime_sha256':hashlib.sha256(before_bytes).hexdigest(),
            'source_match':src['match'],'applied_provider_transformations':ranges,
            'local_compilation_performed':False}
    assert result['before_equals_attack'] and result['before_equals_source_onchain']
    assert result['provider_recompiled_plus_reported_transforms_equals_historical']
    if role=='pair':
        result['target_address']='0x8f2d1A3992856a860304f1B86534B6B129Cc4df7'
        result['binding_limit']='Historical target runtime is identical to the verified reference address runtime. This does not turn the reference source response into a direct target verification, target creation-transaction proof, or independent local compilation.'
    results.append(result)
(ROOT/'runtime-comparison.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps([{k:r[k] for k in ['role','before_equals_attack','before_equals_source_onchain','provider_recompiled_plus_reported_transforms_equals_historical']} for r in results]))