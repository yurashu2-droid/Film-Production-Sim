"""Arrange unchanged render panels for one image edit; no creative raster edits."""
from pathlib import Path
from PIL import Image
ASSET=Path(__file__).resolve().parent.parent
board=Image.new('RGB',(2048,1024))
for i,name in enumerate(['front','back','left','right']):
    with Image.open(ASSET/'reference'/('guide_'+name+'.png')) as im:board.paste(im.convert('RGB'),(i*512,0))
board.save(ASSET/'reference/guide_body_sheet.png')
print('PAINT_SHEET_COMPOSED_2048x1024')
