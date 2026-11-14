"""Eight photo-led furniture replacements. Blender Z-up / front -Y.

Run in an isolated factory-startup Blender CLI. No Godot cache/editor access.
Reference photographs inform construction only; no third-party image is shipped.
"""
from pathlib import Path
import importlib.util
import json
import math
import sys
import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix

SOURCE = Path(__file__).resolve().parent
PROJECT = SOURCE.parents[3]
ARTIFACTS = PROJECT.parent / 'artifacts/rebuild-furniture-a'
spec = importlib.util.spec_from_file_location('furniture_a_fresh_helpers', SOURCE.parents[1] / 'fresh_props/source/build_assets.py')
f = importlib.util.module_from_spec(spec)
spec.loader.exec_module(f)
h = f.h
box, cylinder, material, mesh = f.box, f.cylinder, f.material, f.mesh
TAU = math.tau


def wood(name, color, rough=.48):
    """Original baked long-grain albedo, embedded in each exported GLB."""
    mat = material(name, color, rough)
    n = 512
    u, v = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n))
    bend = .014*np.sin(u*8.0+1.1) + .006*np.sin(u*19.0-v*3)
    # Irregular nested growth lines; quiet large fields, no deep geometry grooves.
    phase = (v+bend)*110 + .6*np.sin(v*14+u*4)
    variation = .026*np.sin(phase) + .012*np.sin(phase*2.31+u*2.6)
    variation += .018*np.sin(v*16+u*1.3) + .007*np.sin(v*320+u*8)
    rng = np.random.default_rng(74)
    variation += rng.normal(0, .002, (n,n))
    rgb = [h.linear(int(color[i:i+2],16)/255) for i in (0,2,4)]
    pixels = np.ones((n,n,4), dtype=np.float32)
    for i,c in enumerate(rgb): pixels[:,:,i] = np.clip(c*(1+variation*2.5),0,1)
    im = bpy.data.images.new(name+' original long grain',width=n,height=n)
    im.colorspace_settings.name='sRGB'
    im.pixels.foreach_set(pixels.ravel())
    im.pack()
    node=mat.node_tree.nodes.new('ShaderNodeTexImage')
    node.image=im
    shader=mat.node_tree.nodes.get('Principled BSDF')
    mat.node_tree.links.new(node.outputs['Color'],shader.inputs['Base Color'])
    return mat


def board(name, at, size, mat, bevel=.003):
    obj=box(name,at,size,mat,bevel)
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='UVMap')
    # Board grain follows the actual long dimension in local object coordinates.
    axis=max(range(3),key=lambda i:size[i])
    for p in obj.data.polygons:
        n=max(range(3),key=lambda i:abs(p.normal[i]))
        axes=[i for i in range(3) if i!=n]
        along=axis if axis in axes else axes[0]
        across=next(i for i in axes if i!=along)
        for li in p.loop_indices:
            co=obj.data.vertices[obj.data.loops[li].vertex_index].co
            uv.data[li].uv=(co[along]/max(size[along],.001)+.5,
                           co[across]/max(size[across],.001)*.65+.5)
    return obj


def beam(name,a,b,width,depth,mat):
    a,b=Vector(a),Vector(b)
    obj=board(name,(a+b)/2,(width,depth,(b-a).length),mat,.002)
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return obj


def taper_leg(name, top, bottom, upper, lower, mat):
    pts=[]
    for c,w in [(bottom,lower),(top,upper)]:
        pts += [(c[0]+sx*w/2,c[1]+sy*w/2,c[2]) for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    o=mesh(name,pts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,False)
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Small eased timber edges','BEVEL');mod.width=.0025;mod.segments=2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # Long grain on both broad sides, end grain quiet.
    uv=o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        for li in p.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co
            uv.data[li].uv=(v.z/max(top[2],.001), (v.x+v.y)*4+.5)
    return o


def rr(w,d,r,steps=8):
    out=[]
    for cx,cy,a0 in [(w/2-r,d/2-r,0),(-w/2+r,d/2-r,math.pi/2),
                      (-w/2+r,-d/2+r,math.pi),(w/2-r,-d/2+r,math.pi*1.5)]:
        for i in range(steps+1):
            a=a0+i*math.pi/2/steps
            out.append((cx+r*math.cos(a),cy+r*math.sin(a)))
    return out


def upholstery(name,at,size,mat,corner=.06,bulge=1.,rotate_x=0.,tufts=False):
    """Closed sewn cushion shell: broad panels, a raised edge, supported underside.

    Rounded rectangular contour rings produce a single shaped volume, rather
    than disconnected ellipsoids. Tiny unequal seam compression stays localized.
    """
    w,d,t=size
    profile=[(.18,-.49),(.62,-.49),(.88,-.48),(.97,-.36),(1.,-.14),
             (1.,.14),(.98,.36),(.90,.49),(.69,.54),(.40,.57),(.13,.58)]
    verts=[];ring_n=36
    rotation=Matrix.Rotation(rotate_x,4,'X')
    for ring,(s,z) in enumerate(profile):
        outline=rr(w*s,d*s,min(corner*s,w*s*.3,d*s*.3))
        for x,y in outline:
            zz=z*t
            if ring>=7:
                zz += .004*bulge*math.sin((x/w+.18)*13)*math.exp(-((abs(y)-d*.38)/(.12*d))**2)*max(0,(abs(x)/w-.15))
                if tufts:
                    for tx in (-w*.22,0,w*.22):
                        zz-=.008*math.exp(-((x-tx)/(.06*w))**2-((y+.01)/(.07*d))**2)
            v=rotation@Vector((x,y,zz)) + Vector(at)
            verts.append(tuple(v))
    faces=[]
    for j in range(len(profile)-1):
        for i in range(ring_n):
            a=j*ring_n+i;b=j*ring_n+(i+1)%ring_n
            faces.append((a,b,b+ring_n,a+ring_n))
    faces += [tuple(reversed(range(ring_n))),tuple((len(profile)-1)*ring_n+i for i in range(ring_n))]
    return mesh(name,verts,faces,mat)


def welt(name,at,w,d,r,z,mat,rotate_x=0.):
    rot=Matrix.Rotation(rotate_x,4,'X')
    points=[rot@Vector((x,y,z))+Vector(at) for x,y in rr(w,d,r)]
    h.tube(name,points,.0025,mat,True,sides=6)


def side_panel(name,sign,profile,x_center,width,mat):
    """Padded chair-side envelope with a continuous side and shaped arm crown."""
    # polygon lives in local XZ; rotate to a YZ profile after extrusion.
    obj=h.extruded_profile(name,profile,-sign*x_center,width,mat,.018)
    obj.rotation_euler.z=math.pi/2
    return obj


def rolled_chair_arm(sign,mat,seam):
    # Continuous rounded arm/side cushion with a shaped crown and joined base.
    sections=[(-.410,.655,.105),(-.392,.702,.165),(-.330,.744,.186),
              (-.22,.720,.18),(0,.742,.166),(.16,.790,.168),
              (.27,.825,.170),(.335,.794,.120)]
    verts=[];n=32
    for y,top,width in sections:
        bottom=.275
        for x,z in rr(width,top-bottom,min(width*.38,.064),7):
            verts.append((sign*.405+x,y,(top+bottom)/2+z))
    faces=[]
    for j in range(len(sections)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
    faces.extend([tuple(reversed(range(n))),tuple((len(sections)-1)*n+i for i in range(n))])
    mesh('Wing chair continuous curved padded arm',verts,faces,mat)
    h.tube('Wing chair curved arm sewn crown',[(sign*(.405+w*.28),y,top-.012)
            for y,top,w in sections],.003,seam,sides=6)


def director():
    timber=wood('Director honey beech','A57343',.46)
    canvas=material('Director warm ivory canvas','D7CFAB',.86)
    seam=material('Director sewn canvas hems','B8AB85',.88)
    metal=material('Director bronze folding hardware','A2844F',.4,.8)
    dark=material('Director dark rubber feet','2D2922',.87)
    for y in (-.265,.265):
        beam('Crossed folding leg',(-.390,y,.035),(.345,y,.715),.052,.045,timber)
        beam('Opposing crossed folding leg',(.390,y+.046,.035),(-.345,y+.046,.715),.052,.045,timber)
        cylinder('X frame pivot',(0,y-.028,.395),.022,.018,metal,(0,1,0),24)
        cylinder('Pivot pin center',(0,y-.040,.395),.007,.005,dark,(0,1,0),16)
    for x in (-.36,.36):
        board('Canvas seat dowel rail',(x,0,.723),(.042,.63,.046),timber)
        board('Long arm support',(x,-.245,.835),(.044,.044,.29),timber)
        board('Backrest upright',(x,.262,.976),(.047,.047,.53),timber)
        board('Flat comfortable armrest',(x,.015,.990),(.095,.66,.035),timber,.009)
        board('Low foot stretcher',(x*.93,0,.09),(.040,.64,.043),timber)
        for y in (-.265,.31):
            board('Protective end shoe',(x*1.08,y,.026),(.061,.052,.05),dark,.005)
    board('Front footrest',(0,-.268,.265),(.72,.055,.044),timber)
    # A supported cloth sheet with a shallow unequal catenary sag and sewn thickness.
    def cloth_sheet(back=False):
        nx,ny=24,10;verts=[]
        for layer in (0,1):
            for j in range(ny+1):
                v=j/ny
                for i in range(nx+1):
                    u=i/nx;x=(u-.5)*.714
                    sag=math.sin(math.pi*u)**1.6
                    if back:
                        y=.267+.026*sag*math.sin(math.pi*v);z=1.035+v*.205-.006*sag
                        verts.append((x,y+layer*.004,z))
                    else:
                        y=(v-.5)*.552;z=.745-.027*sag*(.78+.22*math.sin(math.pi*v))
                        verts.append((x,y,z-layer*.004))
        faces=[];n=(nx+1)*(ny+1)
        for layer in (0,1):
            off=layer*n
            for j in range(ny):
                for i in range(nx):
                    a=off+j*(nx+1)+i;face=(a,a+1,a+nx+2,a+nx+1)
                    faces.append(face if layer==0 else tuple(reversed(face)))
        boundary=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
        for a,b in zip(boundary,boundary[1:]+boundary[:1]):faces.append((a,b,b+n,a+n))
        mesh('Suspended canvas backrest' if back else 'Suspended sagging canvas seat',verts,faces,canvas)
        for u in (0.025,.975):
            if back: points=[((u-.5)*.714,.263,1.035+v*.205) for v in [j/12 for j in range(13)]]
            else: points=[((u-.5)*.714,(v-.5)*.552,.747-.027*math.sin(math.pi*u)**1.6) for v in [j/12 for j in range(13)]]
            h.tube('Reinforced sewn canvas sleeve',points,.003,seam,sides=6)
    cloth_sheet();cloth_sheet(True)
    # Real two-piece folding lock braces at both sides.
    for x in (-.383,.383):
        beam('Folding lock brace',(x,-.233,.704),(x,.025,.573),.017,.012,metal)
        beam('Folding lock brace',(x,.025,.573),(x,.273,.704),.017,.012,metal)
        cylinder('Lock brace center hinge',(x,.025,.573),.013,.020,metal,(1,0,0),16)
    h.ticket_anchor((.13,-.279,.74))


def sofa():
    fabric=material('Sofa faded petrol upholstery','557377',.86)
    cushion=material('Sofa softly worn petrol cushions','66858A',.84)
    piping=material('Sofa tailored welt','3C565C',.89)
    woodmat=wood('Sofa dark oak feet','4D3527',.55)
    # Continuous supporting lower upholstered deck; arms and rear shell meet it.
    upholstery('Sofa upholstered support deck',(0,.015,.333),(1.98,.82,.29),fabric,.055,.2)
    upholstery('Sofa continuous rear shell',(0,.330,.661),(1.94,.22,.58),fabric,.07,.2)
    for sign in (-1,1):
        profile=[(-.410,.25),(.405,.25),(.405,.87),(.31,.91),(-.29,.84),(-.410,.77)]
        side_panel('Sofa integrated padded side',sign,profile,.895,.22,fabric)
        # Welting follows the actual shaped outer arm edge, not a detached sausage.
        h.tube('Sofa arm crown sewn edge',[(sign*1.004,-.395,.77),(sign*1.004,-.30,.835),
                   (sign*1.004,.27,.9),(sign*1.004,.38,.87)],.003,piping,sides=6)
        for y in (-.325,.31):
            taper_leg('Sofa tapered timber foot',(sign*.84,y,.245),(sign*.865,y,.0),.085,.055,woodmat)
    for x in (-.404,.404):
        upholstery('Individual supported seat cushion',(x,-.078,.526),(.785,.615,.18),cushion,.066,.7)
        welt('Seat cushion sewn welt',(x,-.078,.526),.775,.606,.062,.045,piping)
        upholstery('Individual back cushion',(x,.244,.762),(.795,.440,.15),cushion,.071,.6,math.pi/2-.16)
        welt('Back cushion sewn welt',(x,.244,.762),.778,.423,.066,.039,piping,math.pi/2-.16)
    h.ticket_anchor((.21,-.404,.34))


def armchair():
    fabric=material('Wing chair oxblood leather','6B3932',.54)
    cushion=material('Wing chair worn leather seat','805046',.61)
    seams=material('Wing chair edge bindings','462923',.70)
    woodmat=wood('Wing chair walnut legs','4F3324',.48)
    brass=material('Wing chair brass tack heads','B59353',.44,.8)
    upholstery('Wing chair supported upholstered deck',(0,-.005,.354),(.86,.77,.25),fabric,.060,.2)
    # Closed high back: gradually widened shoulders and wings join the lower shell.
    levels=[(.40,.34,.24,.11),(.60,.36,.27,.12),(.83,.365,.285,.13),
            (.96,.43,.29,.14),(1.10,.45,.33,.14),(1.21,.44,.35,.14),
            (1.25,.385,.36,.14)]
    verts=[];n=32
    for z,w,y,t in levels:
        # Wings sweep towards the sitter at the outer sixth of the back.
        for x,yy in rr(w*2,t,.055,7):
            wing=max(0,(abs(x)/w-.64)/.36)
            wing_strength=min(1,max(0,(z-.72)/.28))
            verts.append((x,y+yy-.285*wing*wing_strength,z))
    faces=[]
    for j in range(len(levels)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
    faces.extend([tuple(reversed(range(n))),tuple((len(levels)-1)*n+i for i in range(n))])
    shell=mesh('Continuous high wingback shell',verts,faces,fabric)
    bpy.context.view_layer.objects.active=shell
    bevel=shell.modifiers.new('Soft outer high back edges','BEVEL');bevel.width=.022;bevel.segments=3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    # One seat and one broad interior back panel, gently reclined.
    upholstery('Wing chair broad seat cushion',(0,-.08,.527),(.665,.625,.17),cushion,.073,.7)
    welt('Wing chair seat welt',(0,-.08,.527),.656,.616,.067,.04,seams)
    upholstery('Wing chair fitted button back',(0,.203,.932),(.655,.590,.12),cushion,.085,.5,math.pi/2-.14,True)
    welt('Wing chair back outline',(0,.203,.932),.645,.575,.082,.030,seams,math.pi/2-.14)
    for x in (-.145,0,.145):
        # Tuft buttons are attached to the supported panel, with a short crease fan.
        cylinder('Leather covered tuft button',(x,.135,.92),.012,.008,seams,(0,-1,0),16)
        for s in (-1,1):
            h.tube('Short button compression seam',[(x,.137,.921),(x+s*.033,.14,.938)],.0014,seams,sides=4)
    for sign in (-1,1):
        rolled_chair_arm(sign,fabric,seams)
        for y in (-.30,.29):
            taper_leg('Wing chair tapered foot',(sign*.329,y,.30),(sign*.35,y+.015,.0),.067,.043,woodmat)
        for j in range(8):
            cylinder('Side leather upholstery nail',(sign*.496,-.33+j*.078,.391),.0045,.003,brass,(1,0,0),12)
    h.ticket_anchor((.08,-.405,.36))


def stool():
    chrome=material('Stool bright satin chrome','B9C4CA',.23,.94)
    red=material('Stool vintage red vinyl','A74036',.42)
    seam=material('Stool red vinyl welting','772A25',.58)
    dark=material('Stool rubber base protection','242727',.84)
    f.lathe('Weighted dished pedestal base',[(0,0),(.295,0),(.315,.013),(.320,.027),
            (.308,.045),(.25,.065),(.15,.098),(.074,.145),(.058,.162),(.0,.162)],chrome,64)
    f.lathe('Floor protective rubber rim',[(.295,0),(.315,0),(.318,.009),(.315,.015),(.295,.015),(.295,0)],dark,64)
    cylinder('Outer gas lift cylinder',(0,0,.43),.054,.58,chrome,vertices=32)
    cylinder('Upper sliding seat stem',(0,0,.807),.035,.32,chrome,vertices=32)
    cylinder('Stem rubber wiper seal',(0,0,.715),.055,.016,dark,vertices=32)
    cylinder('Seat underside swivel plate',(0,0,.959),.215,.055,dark,vertices=48)
    f.lathe('Chrome rolled seat skirt',[(0,.97),(.24,.97),(.286,.982),(.293,1.005),
             (.292,1.049),(.282,1.063),(.0,1.063)],chrome,64)
    f.lathe('One continuous padded vinyl seat',[(0,1.035),(.265,1.035),(.290,1.050),
             (.30,1.080),(.292,1.112),(.265,1.133),(.19,1.143),(0,1.146)],red,64)
    ring=[(.294*math.cos(i*TAU/64),.294*math.sin(i*TAU/64),1.068) for i in range(64)]
    h.tube('Vinyl seat continuous welt',ring,.003,seam,True,sides=6)
    # Footring connects with three radial welded struts at the central collar.
    ring=[(.262*math.cos(i*TAU/64),.262*math.sin(i*TAU/64),.454) for i in range(64)]
    h.tube('Circular chrome footrest',ring,.014,chrome,True,sides=8)
    cylinder('Footrest mounting collar',(0,0,.451),.069,.060,chrome,vertices=32)
    for a in (math.pi/2,math.pi/2+TAU/3,math.pi/2+2*TAU/3):
        h.tube('Footrest welded spoke',[(.054*math.cos(a),.054*math.sin(a),.450),
               (.256*math.cos(a),.256*math.sin(a),.454)],.010,chrome,sides=8)
    h.tube('Height adjustment handle',[(.13,.0,.949),(.206,-.04,.925),(.239,-.06,.925)],.009,chrome,sides=8)
    box('Height adjustment black grip',(.255,-.065,.925),(.061,.025,.021),dark,.008)
    # Small lumbar rest preserves the original stool's low back silhouette.
    for sign in (-1,1):
        h.tube('Lumbar rest chrome support',[(sign*.19,.19,.988),(sign*.22,.24,1.165),
               (sign*.20,.25,1.235)],.012,chrome,sides=8)
    upholstery('Low padded stool back',(0,.255,1.231),(.51,.133,.115),red,.05,.15,math.pi/2)
    h.ticket_anchor((0,-.294,1.055))


def table():
    oak=wood('Dining table warm oak','986C43',.48)
    dark=wood('Dining table end and joint grain','765033',.59)
    # Glued board top: intentional tiny joints and full thickness, same long grain.
    for i in range(5):
        board('Joined solid oak tabletop board',(0,-.4+i*.2,.776),(1.8,.199,.060),oak,.005)
    for x in (-.745,.745):
        for y in (-.35,.35):
            taper_leg('Dining table tapered oak leg',(x,y,.750),(x,y,.0),.085,.045,oak)
    for y in (-.35,.35):board('Long tenoned tabletop apron',(0,y,.684),(1.50,.035,.12),dark)
    for x in (-.745,.745):board('End tenoned tabletop apron',(x,0,.684),(.035,.70,.12),dark)
    for sx in (-1,1):
        for sy in (-1,1):
            beam('Under table diagonal corner block',(sx*.59,sy*.35,.692),(sx*.745,sy*.20,.692),.036,.042,oak)
    h.ticket_anchor((.28,-.5,.775))


def drawer(name,x,z,w,height,walnut,shadow,brass,y=-.382):
    # Inset frame opening stays visible around a separate face and a raised center.
    board(name+' shadow reveal',(x,y+.014,z),(w+.012,.012,height+.012),shadow,.001)
    board(name+' front',(x,y-.004,z),(w,.028,height),walnut,.004)
    board(name+' raised inset panel',(x,y-.021,z),(w-.038,.010,height-.031),walnut,.004)
    spread=min(.09,w*.24)
    for sx in (-1,1):
        cylinder(name+' handle mount',(x+sx*spread,y-.034,z),.010,.007,brass,(0,-1,0),16)
    pts=[(x-spread,y-.040,z),(x-spread*.8,y-.055,z-.019),
         (x+spread*.8,y-.055,z-.019),(x+spread,y-.040,z)]
    h.tube(name+' hanging brass bail',pts,.004,brass,sides=8)


def desk():
    walnut=wood('Writing desk walnut','765037',.45)
    edge=wood('Writing desk dark edge and joinery','513726',.54)
    dark=material('Writing desk drawer dark reveals','2D241B',.87)
    brass=material('Writing desk aged brass handles','B29A61',.38,.85)
    leather=material('Writing desk green leather writing inset','354E43',.66)
    # Twin pedestals preserve the source's 1.5 x .81 x .85 meter envelope.
    board('Desk thick framed top',(0,0,.815),(1.50,.81,.07),walnut,.009)
    board('Desk lower molded top edge',(0,0,.773),(1.46,.775,.018),edge,.004)
    board('Leather writing inset',(0,-.005,.852),(1.20,.575,.004),leather,.014)
    for x in (-.565,.565):
        board('Pedestal plinth',(x,.005,.080),(.30,.73,.060),edge,.006)
        board('Pedestal rear panel',(x,.345,.427),(.29,.026,.645),walnut)
        for sx in (-1,1):
            board('Pedestal structural side',(x+sx*.135,.0,.427),(.025,.70,.645),walnut)
        board('Pedestal front upper cross rail',(x,-.355,.717),(.29,.056,.071),edge)
        board('Pedestal front lower cross rail',(x,-.355,.125),(.29,.056,.040),edge)
        for z in (.226,.412,.598):
            drawer('Pedestal drawer',x,z,.247,.166,walnut,dark,brass)
        for y in (-.29,.29):
            taper_leg('Desk short bracket foot',(x,y,.100),(x,y,.0),.095,.075,edge)
    board('Rear modesty support panel',(0,.330,.57),(.84,.026,.365),walnut)
    drawer('Central shallow desk drawer',0,.695,.79,.124,walnut,dark,brass)
    for x in (-.427,.427):board('Kneehole inner rail',(x,.0,.697),(.024,.68,.125),edge)
    h.ticket_anchor((.11,-.407,.81))


def bar():
    oak=wood('Bar counter dark chestnut timber','755035',.43)
    frame=wood('Bar counter stiles and moldings','4F3524',.53)
    brass=material('Bar counter aged brass footrail','B49A5D',.30,.88)
    shadow=material('Bar counter deep joints','2B211B',.90)
    # Structural carcass, complete side/rear storage and overhanging thick top.
    board('Bar structural lower deck',(0,.055,.105),(2.48,.68,.09),frame,.005)
    board('Bar substantial countertop',(0,.0,1.125),(2.65,.83,.09),oak,.015)
    board('Bar countertop molded edge',(0,-.015,1.064),(2.61,.82,.035),frame,.010)
    for x in (-1.19,1.19):
        board('Bar end structural panel',(x,.015,.585),(.060,.69,.99),oak)
        for z in (.17,.99):board('Bar end horizontal molding',(x*1.03,.025,z),(.025,.67,.054),frame)
    # Three inset panels, real frame thickness, and close inner bevel molding.
    board('Bar continuous panel backing',(0,-.28,.588),(2.42,.045,.96),shadow)
    for x in (-1.18,-.39,.39,1.18):
        board('Bar face structural stile',(x,-.319,.584),(.075,.070,.95),frame,.004)
        board('Bar stile raised center',(x,-.358,.584),(.038,.012,.83),oak,.003)
    for z in (.185,.991):board('Bar face horizontal rail',(0,-.321,z),(2.44,.071,.090),frame)
    for x in (-.785,0,.785):
        board('Bar recessed chestnut panel',(x,-.318,.588),(.689,.025,.68),oak,.004)
        for xx in (x-.326,x+.326):board('Panel vertical bead molding',(xx,-.345,.588),(.018,.018,.70),frame,.005)
        for z in (.247,.929):board('Panel horizontal bead molding',(x,-.345,z),(.67,.018,.018),frame,.005)
    board('Bar lower skirting',(0,-.339,.105),(2.51,.075,.10),frame,.007)
    # Rail belongs to the cabinet through three wall-mounted brackets.
    cylinder('Continuous brass foot rail',(0,-.447,.237),.020,2.37,brass,(1,0,0),32)
    for x in (-.95,0,.95):
        cylinder('Footrail mounting flange',(x,-.365,.17),.035,.012,brass,(0,-1,0),24)
        h.tube('Footrail curved bracket',[(x,-.365,.17),(x,-.401,.17),(x,-.447,.207),(x,-.447,.237)],.013,brass,sides=8)
    # Open bartender-side storage is supported, not a hollow object with missing back.
    for z in (.47,.795):board('Bar rear storage shelf',(0,.10,z),(2.32,.51,.034),oak)
    for x in (-.39,.39):board('Bar rear vertical shelf divider',(x,.10,.586),(.035,.51,.91),frame)
    h.ticket_anchor((.15,-.364,.50))


def bed():
    oak=wood('Bed golden oak frame','A47C50',.51)
    edge=wood('Bed dark end grain and joints','795A38',.61)
    linen=material('Bed warm white cotton sheet','E4E0D1',.9)
    side=material('Bed mattress ticking','C9C7BB',.88)
    piping=material('Bed mattress and pillow sewn edging','B6B4A8',.91)
    blanket=material('Bed dusty teal woven blanket','5D8180',.91)
    # Bed front is the low foot end (-Y); headboard is +Y.
    for x in (-.5,.5):
        board('Bed long structural side rail',(x,0,.351),(.055,1.99,.16),oak,.004)
        board('Bed inner mattress support cleat',(x*.92,0,.320),(.028,1.98,.037),edge)
        for y in (-.985,.985):
            board('Bed solid square leg',(x,y,.31 if y<0 else .51),(.09,.09,.62 if y<0 else 1.02),oak,.005)
    for y in (-.985,.985):board('Bed end joining rail',(0,y,.355),(1.01,.065,.17),oak,.005)
    for j in range(14):board('Bed mattress support slat',(0,-.89+j*.137,.342),(.96,.108,.025),edge,.002)
    board('Bed headboard top rail',(0,.985,.978),(1.10,.08,.080),oak,.007)
    board('Bed headboard lower rail',(0,.985,.648),(1.02,.065,.070),oak,.004)
    for x in (-.345,-.1725,0,.1725,.345):
        board('Bed headboard fitted vertical slat',(x,.985,.805),(.075,.037,.32),oak,.003)
    upholstery('Bed fully supported mattress',(0,0,.474),(.975,1.965,.23),side,.074,.15)
    welt('Mattress lower taped edge',(0,0,.474),.968,1.957,.07,-.065,piping)
    welt('Mattress upper taped edge',(0,0,.474),.968,1.957,.07,.073,piping)
    # Fitted sheet covers the mattress top and wraps past the upper tape.
    upholstery('Bed tucked cotton fitted sheet',(0,0,.529),(.983,1.972,.13),linen,.076,.45)
    upholstery('Bed separate filled cotton pillow',(0,.676,.660),(.745,.42,.17),linen,.085,1.2)
    welt('Pillow continuous perimeter seam',(0,.676,.660),.731,.410,.077,.0,piping)
    # A light coverlet rests on the mattress, with two gravity-supported side drops.
    nx,ny=30,22;verts=[]
    for layer in (0,1):
        for j in range(ny+1):
            y=-.905+j*1.15/ny
            for i in range(nx+1):
                x=-.55+i*1.10/nx
                outside=max(0,abs(x)-.445)
                drop=(outside/.105)**.70*.17
                wave=.006*math.sin(y*14+x*4)*min(1,outside/.05)
                z=.620-drop+wave-layer*.004
                # Two broad diagonal compression folds at the coverlet's turned edge.
                z += .007*math.exp(-((y-.11-x*.08)/.055)**2)*(1-min(1,abs(x)/.55))
                verts.append((x,y,z))
    faces=[];n=(nx+1)*(ny+1)
    for layer in (0,1):
        off=layer*n
        for j in range(ny):
            for i in range(nx):
                a=off+j*(nx+1)+i;face=(a,a+1,a+nx+2,a+nx+1)
                faces.append(face if layer==0 else tuple(reversed(face)))
    boundary=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
    for a,b in zip(boundary,boundary[1:]+boundary[:1]):faces.append((a,b,b+n,a+n))
    mesh('Bed resting woven coverlet with supported side drops',verts,faces,blanket)
    h.ticket_anchor((.20,-1.021,.355))


SPECS=[
    ('scrap_director_chair','S026_director_chair',director,[.875,.7230085731,1.254059203],.95,3.),
    ('scrap_two_seat_sofa','S027_two_seat_sofa',sofa,[2.02,.865,.970],1.35,7.),
    ('scrap_wing_armchair','S028_wing_armchair',armchair,[.99,.84,1.27],.95,5.),
    ('scrap_swivel_bar_stool','S029_swivel_bar_stool',stool,[.64,.64,1.30],.9,3.),
    ('scrap_dining_table','S030_dining_table',table,[1.8,1.,.806],1.2,6.),
    ('scrap_writing_desk','S031_writing_desk',desk,[1.5,.81,.85],1.,6.),
    ('scrap_bar_counter','S032_bar_counter',bar,[2.65,.95,1.17],1.7,10.),
    ('scrap_single_bed','S033_single_bed',bed,[1.10,2.085,1.02],1.4,8.),
]


def fit_envelope(dimensions):
    bpy.context.view_layer.update()
    points=[o.matrix_world@v.co for o in h.PARTS for v in o.data.vertices]
    lo=Vector([min(p[i] for p in points) for i in range(3)])
    hi=Vector([max(p[i] for p in points) for i in range(3)])
    factor=Vector([dimensions[i]/(hi[i]-lo[i]) for i in range(3)])
    center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
    transform=Matrix.Diagonal((*factor,1)) @ Matrix.Translation(-center)
    for obj in h.PARTS+h.MARKERS:
        obj.matrix_world=transform@obj.matrix_world
    bpy.context.view_layer.update()
    return list(factor)


def validate_geometry():
    for obj in h.PARTS:
        if not all(math.isfinite(c) for v in obj.data.vertices for c in v.co):raise RuntimeError('Nonfinite '+obj.name)
        # All authored surfaces are closed volumes; joined shells may overlap at upholstery contacts.
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
        bm.to_mesh(obj.data)
        if any(f.calc_area()<1e-12 for f in bm.faces):raise RuntimeError('Degenerate face '+obj.name)
        if any(not e.is_manifold for e in bm.edges):raise RuntimeError('Open shell '+obj.name)
        bm.free()


def preview(name, dimensions):
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
    scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Furniture neutral studio');scene.world.color=(.35,.35,.35)
    scene.view_settings.view_transform='AgX'
    target=Vector((0,0,dimensions[2]*.43));extent=max(dimensions)
    # Rendering-only geometry is added after export and .blend save.
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.004))
    floor=bpy.context.object;floor.data.materials.append(material('Render only ground','777972',.9))
    for pos,power,size in [((-3,-4,5),600,4),((4,-2,3),350,3),((0,4,4),550,3)]:
        data=bpy.data.lights.new('Broad studio area','AREA');data.energy=power*max(1,extent);data.shape='DISK';data.size=size
        obj=bpy.data.objects.new(data.name,data);bpy.context.collection.objects.link(obj);obj.location=Vector(pos)*max(.7,extent*.65)
        obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=extent*1.36;scene.camera=cam
    for view,direction in [('front',(2.5,-3.8,2.1)),('rear',(-2.5,3.8,2.1))]:
        cam.location=target+Vector(direction)*extent
        cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(ARTIFACTS/(name+'_'+view+'.png'))
        bpy.ops.render.render(write_still=True)


def main():
    ARTIFACTS.mkdir(parents=True,exist_ok=True)
    rows=[];replacements=[]
    requested=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
    for kind,original,build,dimensions,size,mass in SPECS:
        if requested and original not in requested:continue
        bpy.ops.wm.read_factory_settings(use_empty=True);h.PARTS.clear();h.MARKERS.clear()
        build()
        validate_geometry()
        fit=fit_envelope(dimensions)
        row=h.export_asset(original+'_rebuilt')
        row.update(kind=kind,original_file=original,normalization_size=size,mass_kg=mass,
                   dimensions_blender=dimensions,authoring_axis_fit=fit,textures_embedded=any(m.node_tree and any(n.type=='TEX_IMAGE' for n in m.node_tree.nodes) for m in bpy.data.materials),
                   validation={'finite_vertices':True,'closed_authored_shells':True,'no_degenerate_faces':True,'blender_render':'front and rear','godot_runtime':'parent owned; not tested here'})
        rows.append(row)
        replacements.append({'kind':kind,'original_file':original,'file':original+'_rebuilt'})
        bpy.ops.wm.save_as_mainfile(filepath=str(ARTIFACTS/(original+'_rebuilt.blend')))
        preview(original,dimensions)
        print('FURNITURE_ASSET_OK '+json.dumps(row),flush=True)
    # Partial selection builds retain the rest of this batch's manifest.
    manifest=SOURCE/'build_manifest.json';mapping=SOURCE/'replacements.json'
    if requested and manifest.exists():
        old=json.loads(manifest.read_text(encoding='utf-8'));rows=[r for r in old if r['kind'] not in {n['kind'] for n in rows}]+rows
    if requested and mapping.exists():
        old=json.loads(mapping.read_text(encoding='utf-8'));replacements=[r for r in old if r['kind'] not in {n['kind'] for n in replacements}]+replacements
    rows.sort(key=lambda r:r['file']);replacements.sort(key=lambda r:r['file'])
    manifest.write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
    mapping.write_text(json.dumps(replacements,indent=2)+'\n',encoding='utf-8')
    print('FURNITURE_BATCH_OK '+str(len(rows)),flush=True)


if __name__=='__main__':main()
