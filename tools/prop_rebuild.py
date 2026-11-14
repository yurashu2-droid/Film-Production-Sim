"""Integrate completed authoring groups and capture matched Godot comparisons."""
from pathlib import Path
import argparse
import json
import re
from dev_session import Session

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'godot/docs/PROP_REBUILD_MANIFEST.json'


def load():
    return json.loads(MANIFEST.read_text(encoding='utf-8'))


def save(data):
    MANIFEST.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=['integrate','capture','status'])
    parser.add_argument('groups',nargs='*')
    parser.add_argument('--engine',type=Path)
    parser.add_argument('--catalog',action='store_true')
    parser.add_argument('--include-retained',action='store_true',help='Also compare the ten already accepted models')
    args=parser.parse_args()
    data=load()
    if args.mode=='status':
        counts={}
        for row in data['entries']:
            counts[row['status']]=counts.get(row['status'],0)+1
        print(json.dumps(counts,ensure_ascii=False))
        return
    selected=[]
    table=ROOT/'godot/scripts/production_scrap.gd'
    text=table.read_text(encoding='utf-8')
    for group in args.groups:
        source=ROOT/'godot/assets/production'/group/'source'
        replacements=json.loads((source/'replacements.json').read_text(encoding='utf-8'))
        for replacement in replacements:
            row=next(e for e in data['entries'] if e['kind']==replacement['kind'])
            if row['original_file']!=replacement['original_file']:
                raise ValueError('Original identity mismatch: '+row['kind'])
            if not (ROOT/'godot/assets/production/scrap'/(replacement['file']+'.glb')).is_file():
                raise FileNotFoundError(replacement['file'])
            selected.append((row,replacement,group))
            if args.mode=='integrate':
                # Only the existing file field is replaced; IDs/order/metadata stay fixed.
                pattern=r'("kind": "'+re.escape(row['kind'])+r'", "file": ")[^"]+(")'
                text,count=re.subn(pattern,lambda m:m[1]+replacement['file']+m[2],text)
                if count!=1:
                    raise ValueError('Expected one table entry: '+row['kind'])
                row.update(current_file=replacement['file'],status='review',group=group)
    if args.mode=='integrate':
        table.write_text(text,encoding='utf-8')
        save(data)
        print('INTEGRATED',len(selected))
        return
    if args.include_retained:
        for row in data['entries']:
            if row['status']=='retained':
                selected.append((row,{'file':row['current_file']},'retained'))
    session=Session(project=ROOT/'godot',name='prop_rebuild_review',engine=args.engine)
    session.start('render')
    session.request({'op':'load','scene':'res://tools/refined_props_review.tscn'})
    try:
        kinds=[]
        for row,replacement,group in selected:
            out=ROOT/'artifacts/props-refresh-all'/group
            out.mkdir(parents=True,exist_ok=True)
            for rear in (False,True):
                session.request({'op':'call','method':'show_asset_pair','args':[row['kind'],replacement['file'],rear]})
                session.request({'op':'capture','path':str(out/(row['kind']+('_rear.png' if rear else '_comparison.png')))})
            kinds.append(row['kind'])
        audit=session.request({'op':'call','method':'audit_props','args':[kinds]})
        (ROOT/'artifacts/props-refresh-all'/'audit-latest.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
        if audit['errors']:
            raise RuntimeError(json.dumps(audit['errors']))
        if args.catalog:
            session.request({'op':'call','method':'save_catalog','args':[kinds]})
        for row,replacement,group in selected:
            row.update(status='retained' if row['status']=='retained' else 'rebuilt',comparison='artifacts/props-refresh-all/'+group+'/'+row['kind']+'_comparison.png')
        save(data)
        gallery=['# 全モデル置き換えの比較\n','左が元モデル、右が新モデル。\n']
        for row in data['entries']:
            if row.get('comparison'):
                gallery += ['## '+row['label']+'\n','!['+row['kind']+']('+str(ROOT/row['comparison']).replace('\\','/')+')\n']
        (ROOT/'artifacts/props-refresh-all/comparisons.md').write_text('\n'.join(gallery),encoding='utf-8')
        print('CAPTURE_AUDIT_OK',len(kinds))
    finally:
        session.stop()


if __name__=='__main__':
    main()
