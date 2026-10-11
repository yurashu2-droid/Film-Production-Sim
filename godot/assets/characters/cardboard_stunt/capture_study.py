"""Render the exact exported GLB in Godot, using the persistent hidden session."""
import json
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools'))
from dev_session import Session


def main():
    out=ROOT/'artifacts/cardboard-stunt'
    out.mkdir(parents=True,exist_ok=True)
    session=Session(name='cardboard_stunt')
    session.start('render')
    session.request(dict(op='reload',path='res://scripts/cardboard_stunt_lab.gd'))
    session.request(dict(op='load',scene='res://cardboard_stunt_lab.tscn'))
    def call(method,*args):
        return session.request(dict(op='call',method=method,args=list(args)))
    def capture(path):
        session.request(dict(op='capture',path=str(path)))
        return Image.open(path).convert('RGB')
    call('set_time',1.55)
    capture(out/'hero.png')
    call('show_titles',False)
    views=[]
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',24)
    call('set_time',0.)
    for view in ['front','left','right','back','top']:
        call('set_view',view)
        image=capture(out/(view+'.png'))
        # Diagnostic cameras center model rather than the editorial offset.
        image=image.crop((470,75,1130,825)).resize((330,375),Image.Resampling.LANCZOS)
        ImageDraw.Draw(image).text((15,15),view.upper(),font=font,fill='#253738')
        views.append(image)
    board=Image.new('RGB',(330*5,375),(239,232,214))
    for i,image in enumerate(views):board.paste(image,(330*i,0))
    board.save(out/'turnaround.jpg',quality=94)
    call('set_view','hero')
    frames=[]; evidence=[]
    for frame in range(96):
        call('set_time',frame/24)
        evidence.append(call('evidence'))
        image=capture(out/('frame_%03d.png'%frame))
        image=image.crop((660,70,1300,810)).resize((480,555),Image.Resampling.LANCZOS)
        frames.append(image)
    assert len({json.dumps(x['feet'],sort_keys=True) for x in evidence})==1,'Boot contacts drifted'
    assert all(x['meshes']==90 for x in evidence)
    assert all(x['clips']==['Action_Slate'] for x in evidence)
    palette=frames[0].quantize(colors=192)
    gif=[frame.quantize(palette=palette,dither=Image.Dither.NONE) for frame in frames]
    gif[0].save(out/'action.gif',save_all=True,append_images=gif[1:],loop=0,
                duration=[40,40,40,40,40,50]*16,disposal=2,optimize=True)
    strip=Image.new('RGB',(12*160,8*185),(239,232,214))
    for i,frame in enumerate(frames):
        thumb=frame.resize((160,185),Image.Resampling.LANCZOS)
        ImageDraw.Draw(thumb).text((4,4),str(i),fill='#253738')
        strip.paste(thumb,((i%12)*160,(i//12)*185))
    strip.save(out/'all_frames.jpg',quality=94)
    (out/'runtime_evidence.json').write_text(json.dumps(dict(
        scene='res://cardboard_stunt_lab.tscn',engine='Godot 4.7.2',
        frames=96,fps=24,views=['front','left','right','back','top','hero'],
        contact_drift_m=0,observations=evidence),indent=2),encoding='utf-8')
    call('set_time',1.55)
    call('show_titles',True)
    print('Captured 96 frames; 90 GLB meshes; Action_Slate; contact drift = 0m',flush=True)


if __name__=='__main__':main()
