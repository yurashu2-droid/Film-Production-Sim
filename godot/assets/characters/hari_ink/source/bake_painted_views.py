"""Bake registered AI-painted camera views into the model's actual shared UVs.

Run with ordinary Python + numpy/scipy/Pillow after make_paint_guides.py.
Camera-facing and BVH visibility are kept separate. Hidden regions retain
material pigment; generated views are art-directed, not measured photographs.
"""
from pathlib import Path
import numpy as np,json,math,hashlib
from PIL import Image
from scipy.ndimage import distance_transform_edt
HERE=Path(__file__).resolve().parent;ASSET=HERE.parent;ROOT=ASSET.parents[3]
data=np.load(ROOT/'artifacts/hari-ink/paint_geometry.npz')
meta=json.loads((ASSET/'reference/guide_cameras.json').read_text())
SIZE=4096
body=np.asarray(Image.open(ASSET/'reference/painted_body_sheet.png').convert('RGB'),dtype=np.float32)/255
face=np.asarray(Image.open(ASSET/'reference/painted_face.png').convert('RGB'),dtype=np.float32)/255
panels=np.split(body,4,axis=1)
guides=[np.asarray(Image.open(ASSET/'reference'/('guide_'+v['name']+'.png')).convert('RGB'),dtype=np.float32)/255 for v in meta['views']]
names=data['names'];head_ids={i for i,n in enumerate(names) if n.startswith(('Face_CC0','Eye_','Iris_','Pupil_','Brow_','Glasses_','Fringe_','Short_side_','Hair_coverage'))}
def sample(image,points,view):
    h,w=image.shape[:2];rel=points-np.array(view['center']);right=np.array(view['right'])
    width=view['vertical_m']*view['width']/view['height']
    px=(rel@right/width+.5)*w-.5;py=(.5-rel[:,2]/view['vertical_m'])*h-.5
    valid=(px>=0)&(px<w-1)&(py>=0)&(py<h-1)
    px=np.clip(px,0,w-1.001);py=np.clip(py,0,h-1.001)
    x=px.astype(np.int32);y=py.astype(np.int32);fx=(px-x)[:,None];fy=(py-y)[:,None]
    color=image[y,x]*(1-fx)*(1-fy)+image[y,x+1]*fx*(1-fy)+image[y+1,x]*(1-fx)*fy+image[y+1,x+1]*fx*fy
    return color,valid
tex=np.full((SIZE,SIZE,3),.16,np.float32);coverage=np.zeros((SIZE,SIZE),bool);painted=np.zeros_like(coverage)
positions=data['positions'];normals=data['normals'];uv=data['uv'];visibility=data['visibility']
for ti in range(len(uv)):
    a,b,c=uv[ti]*[SIZE,-SIZE]+[0,SIZE]
    x0=max(int(math.floor(min(a[0],b[0],c[0]))),0);x1=min(int(math.ceil(max(a[0],b[0],c[0]))),SIZE-1)
    y0=max(int(math.floor(min(a[1],b[1],c[1]))),0);y1=min(int(math.ceil(max(a[1],b[1],c[1]))),SIZE-1)
    if x1<x0 or y1<y0:continue
    den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
    if abs(den)<1e-7:continue
    X,Y=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
    w0=((b[1]-c[1])*(X-c[0])+(c[0]-b[0])*(Y-c[1]))/den
    w1=((c[1]-a[1])*(X-c[0])+(a[0]-c[0])*(Y-c[1]))/den;w2=1-w0-w1
    ins=(w0>=-1e-6)&(w1>=-1e-6)&(w2>=-1e-6)
    if not ins.any():continue
    iy,ix=np.nonzero(ins);W=np.stack([w0[ins],w1[ins],w2[ins]],1)
    P=W@positions[ti];N=W@normals[ti];N/=np.maximum(np.linalg.norm(N,axis=1,keepdims=True),1e-9);V=W@visibility[ti]
    accum=np.zeros((len(P),3),np.float32);weight=np.zeros(len(P),np.float32)
    for k,view in enumerate(meta['views']):
        col,valid=sample(panels[k],P,view)
        guide,_=sample(guides[k],P,view)
        bg=guides[k][0,0]
        valid&=np.linalg.norm(guide-bg,axis=1)>.09
        if k==0 and int(data['ids'][ti]) in head_ids:
            fc,fv=sample(face,P,meta['face'])
            mix=np.clip((P[:,2]-1.12)/.10,0,1)*fv
            col=col*(1-mix[:,None])+fc*mix[:,None]
        wk=np.clip(N@np.array(view['direction']),0,1)**5*np.clip(V[:,k],0,1)**2*valid
        accum+=col*wk[:,None];weight+=wk
    base=data['colors'][ti]
    base=np.where(base<=.0031308,base*12.92,1.055*np.maximum(base,0)**(1/2.4)-.055)
    col=np.where(weight[:,None]>.008,accum/np.maximum(weight[:,None],1e-8),base)
    ys=y0+iy;xs=x0+ix;tex[ys,xs]=col;coverage[ys,xs]=True;painted[ys,xs]=weight>.008
    if ti%25000==0:print('BAKE_TRIANGLES',ti,'/',len(uv),flush=True)
# Border dilation only; unobserved covered surfaces keep their material color.
nearest=distance_transform_edt(~coverage,return_distances=False,return_indices=True)
tex[~coverage]=tex[nearest[0][~coverage],nearest[1][~coverage]]
out=ASSET/'textures/hari_pigment_4k.png'
Image.fromarray(np.uint8(np.clip(tex,0,1)*255+.5)).save(out)
report=dict(size=SIZE,triangles=len(uv),atlas_coverage=float(coverage.mean()),
            camera_painted_fraction=float(painted.sum()/max(1,coverage.sum())),
            guides='Actual orthographic model renders, four world-space directions plus high-resolution face',
            visibility='Ray-tested geometry toward each camera; weighted by surface normal',
            hidden_surface='Original material pigment retained',
            texture_sha256=hashlib.sha256(out.read_bytes()).hexdigest())
(ASSET/'preview/paint_bake_evidence.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('PAINT_VIEW_UV_BAKE_OK',json.dumps(report),flush=True)
