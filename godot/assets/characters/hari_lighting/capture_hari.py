"""Retain reference-driven part comparisons, all views and the actual GLB motion."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools'))
from dev_session import Session


def main():
    out=ROOT/'artifacts/hari-lighting'
    out.mkdir(parents=True,exist_ok=True)
    final=out/'final';final.mkdir(exist_ok=True)
    session=Session(name='hari_lighting');session.start('render')
    session.request(dict(op='reload',path='res://scripts/hari_lighting_lab.gd'))
    session.request(dict(op='load',scene='res://hari_lighting_lab.tscn'))
    def call(method,*args):return session.request(dict(op='call',method=method,args=list(args)))
    def capture(path):
        session.request(dict(op='capture',path=str(path)))
        with Image.open(path) as image:return image.convert('RGB')
    call('set_time',0.)
    capture(final/'hero.png')
    for part in ['face','hair','cuff','lamp']:
        call('set_part',part)
        capture(final/(part+'.png'))
    call('reset_view'); call('show_titles',False)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22)
    views=[]
    for view in ['front','left','right','back','top']:
        call('set_view',view)
        image=capture(final/(view+'.png'))
        image=image.crop((470,65,1130,815)).resize((330,375),Image.Resampling.LANCZOS)
        ImageDraw.Draw(image).text((12,10),view.upper(),fill='#253738',font=font)
        views.append(image)
    board=Image.new('RGB',(1650,375),'#f2edde')
    for i,image in enumerate(views):board.paste(image,(330*i,0))
    board.save(final/'turnaround.jpg',quality=94)
    call('set_view','hero')
    frames=[];checks=[]
    for frame in range(96):
        call('set_time',frame/24)
        checks.append(call('evidence'))
        image=capture(out/('frame_%03d.png'%frame))
        frames.append(image.crop((690,70,1290,810)).resize((450,555),Image.Resampling.LANCZOS))
    assert all(x['meshes']==113 and x['clips']==['Light_Check'] for x in checks)
    assert len({json.dumps(x['feet'],sort_keys=True) for x in checks})==1
    assert all(x['lamp_is_child_of_hand'] for x in checks)
    assert len({json.dumps(x['lamp_attachment']) for x in checks})==1
    palette=frames[0].quantize(colors=192)
    gif=[image.quantize(palette=palette,dither=Image.Dither.NONE) for image in frames]
    gif[0].save(final/'light_check.gif',save_all=True,append_images=gif[1:],loop=0,
        duration=[40,40,40,40,40,50]*16,disposal=2,optimize=True)
    strip=Image.new('RGB',(1800,1480),'#f2edde')
    for i,image in enumerate(frames):
        thumb=image.resize((150,185),Image.Resampling.LANCZOS)
        ImageDraw.Draw(thumb).text((4,4),str(i),fill='#253738')
        strip.paste(thumb,((i%12)*150,(i//12)*185))
    strip.save(final/'all_frames.jpg',quality=93)
    comparisons=Image.new('RGB',(960,4*320),'#f2edde')
    for i,part in enumerate(['face','hair','cuff','lamp']):
        for col,path in enumerate([out/'round01'/(part+'.png'),final/(part+'.png')]):
            if path.exists():
                with Image.open(path) as image:im=image.convert('RGB').resize((480,270),Image.Resampling.LANCZOS)
                comparisons.paste(im,(col*480,i*320+45))
        ImageDraw.Draw(comparisons).text((14,i*320+12),part.upper()+' / FIRST',font=font,fill='#253738')
        ImageDraw.Draw(comparisons).text((494,i*320+12),part.upper()+' / RETAINED',font=font,fill='#253738')
    comparisons.save(final/'part_comparison.jpg',quality=94)
    report=dict(scene='res://hari_lighting_lab.tscn',engine='Godot 4.7.2',fps=24,frames=96,
        views=['front','left','right','back','top','hero'],parts=['face','hair','cuff','lamp'],
        mesh_count=113,clips=['Light_Check'],contact_drift_m=0,lamp_attached_all_frames=True,
        glb_sha256=hashlib.sha256((HERE/'hari_lighting.glb').read_bytes()).hexdigest(),
        visual_review='Requires human/model inspection of saved images; numeric checks alone do not establish quality.')
    (final/'runtime_evidence.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    (out/'runtime_samples.json').write_text(json.dumps(checks,indent=2)+'\n',encoding='utf-8')
    for name in ['hero.png','turnaround.jpg','light_check.gif','all_frames.jpg','part_comparison.jpg','runtime_evidence.json']:
        shutil.copy2(final/name,HERE/'preview'/name)
    call('reset_view');call('set_time',0.)
    print('HARI_CAPTURE_PASS: 96 frames; 113 meshes; fixed contacts; lamp attached; saved comparisons',flush=True)


if __name__=='__main__':main()
