"""Small dependency-free closed hair-clump sweep. Units are caller-defined.
Returns vertices/faces; does not touch a scene or create a hairstyle.
Independent half-width/depth curves, transported frame, twist and offset ridge.
"""
import math

def add(a,b):return tuple(x+y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def mul(a,s):return tuple(x*s for x in a)
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(a):
 d=math.sqrt(dot(a,a))
 if d<1e-10:raise ValueError('Coincident samples or degenerate frame')
 return mul(a,1/d)
def sample(values,t):
 # Centripetal overshoot is unnecessary here: authored points use a uniform
 # Catmull-Rom centerline; widths/depths use nonnegative linear interpolation.
 p=t*(len(values)-1);i=min(int(p),len(values)-2);u=p-i
 return values[i]*(1-u)+values[i+1]*u

def center(points,t):
 p=t*(len(points)-1);i=min(int(p),len(points)-2);u=p-i
 a,b,c,d=[points[max(0,min(len(points)-1,j))] for j in (i-1,i,i+1,i+2)]
 return tuple(.5*((2*b[k])+(-a[k]+c[k])*u+(2*a[k]-5*b[k]+4*c[k]-d[k])*u*u+(-a[k]+3*b[k]-3*c[k]+d[k])*u*u*u) for k in range(3))

def make_clump(points,widths,depths,*,rings=9,outward=(0,-1,0),twists=None,ridge=.16):
 """Make a solid asymmetric lens: centerline points ordered root to tip.
 widths are positive half-widths; depths are positive outward crest depths.
 The underside is at -0.48*depth, so total untwisted thickness is 1.48*depth.
 Both arrays have one value per point. twists are in radians.
 rings >= 4; more rings are not automatically better. ridge shifts the top
 crest laterally in profile coordinates. End rings stay nonzero and capped;
 this avoids a zero-radius ring containing duplicate vertices.
 """
 if len(points)<3 or len(widths)!=len(points) or len(depths)!=len(points):raise ValueError('Need >=3 points with matching width and depth arrays')
 if rings<4 or any(not math.isfinite(x) or x<=0 for x in widths+depths):raise ValueError('Positive extents and >=4 rings required')
 if not all(math.isfinite(x) for p in points for x in p):raise ValueError('Nonfinite points')
 if any(dot(sub(a,b),sub(a,b))<1e-16 for a,b in zip(points,points[1:])):raise ValueError('Coincident adjacent controls')
 if twists is None:twists=[0.0]*len(points)
 if len(twists)!=len(points) or not all(math.isfinite(x) for x in twists):raise ValueError('Finite twist controls must match points')
 if not math.isfinite(ridge) or abs(ridge)>=.8:raise ValueError('Ridge must remain between the section shoulders')
 profile=[(-1,0),(-.52,.66),(ridge,1),(.66,.54),(1,0),(.43,-.42),(-.25,-.48),(-.74,-.25)]
 verts=[];frames=[];prev_n=None
 for j in range(rings):
  t=j/(rings-1);c=center(points,t);a=center(points,max(0,t-.001));b=center(points,min(1,t+.001));tan=norm(sub(b,a))
  candidate=outward if prev_n is None else prev_n
  n=sub(candidate,mul(tan,dot(candidate,tan)))
  if dot(n,n)<1e-8:
   candidate=min([(1,0,0),(0,1,0),(0,0,1)],key=lambda x:abs(dot(x,tan)))
   n=sub(candidate,mul(tan,dot(candidate,tan)))
  n=norm(n);side=norm(cross(tan,n));prev_n=n
  angle=sample(twists,t);nn=add(mul(n,math.cos(angle)),mul(side,math.sin(angle)));ss=add(mul(side,math.cos(angle)),mul(n,-math.sin(angle)))
  w=sample(widths,t);d=sample(depths,t)
  for x,y in profile:verts.append(add(c,add(mul(ss,x*w),mul(nn,y*d))))
  frames.append((c,tan,ss,nn))
 faces=[];m=len(profile)
 for j in range(rings-1):
  for k in range(m):faces.append((j*m+k,j*m+(k+1)%m,(j+1)*m+(k+1)%m,(j+1)*m+k))
 # Opposite cap winding; Blender adapter recalculates outward normals.
 faces.append(tuple(reversed(range(m))));faces.append(tuple((rings-1)*m+k for k in range(m)))
 return verts,faces
