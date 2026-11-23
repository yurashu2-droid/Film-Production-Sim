"""Make compact contact sheets from matched Godot captures (no model edits)."""
from pathlib import Path
from PIL import Image,ImageDraw
import argparse
p=argparse.ArgumentParser();p.add_argument('groups',nargs='+');p.add_argument('--rear',action='store_true');args=p.parse_args()
root=Path(__file__).resolve().parents[1]/'artifacts/props-refresh-all'
for group in args.groups:
 files=sorted((root/group).glob('*_rear.png' if args.rear else '*_comparison.png'))
 for page in range((len(files)+7)//8):
  chosen=files[page*8:page*8+8];sheet=Image.new('RGB',(1200,365*((len(chosen)+1)//2)),'#eeeeee');draw=ImageDraw.Draw(sheet)
  for i,path in enumerate(chosen):
   im=Image.open(path).convert('RGB');im.thumbnail((600,337));x=(i%2)*600;y=(i//2)*365
   sheet.paste(im,(x,y));draw.text((x+8,y+340),path.stem,fill='#222222')
  out=root/(group+('_rear' if args.rear else '')+'_contact_'+str(page+1)+'.jpg');sheet.save(out);print(out)
