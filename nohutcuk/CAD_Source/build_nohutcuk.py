"""Nohutçuk parametric concept/prototype CAD.

All dimensions millimetres. Revision 3.2 uses a provisional **3.2-inch SPI ILI9341** PCB envelope,
89.3 x 55.04 mm in landscape, approximately 64.8 x 48.6 mm active view.
TEST-FIT ONLY: exact PCB mounts, cables, servo torque, connector orientation, power and
supplier-specific dimensions MUST be checked against real hardware before printing.

Run: python build_nohutcuk.py [destination_root]
Dependencies: cadquery, trimesh, numpy
"""
import os, sys, math
from pathlib import Path
import cadquery as cq
import numpy as np
import trimesh

ROOT=Path(sys.argv[1] if len(sys.argv)>1 else Path(__file__).resolve().parents[1]);
STL=ROOT/'STL_Individual'; STL_M=ROOT/'STL_Merged'; STEP=ROOT/'STEP'
for d in [STL,STL_M,STEP]:d.mkdir(parents=True,exist_ok=True)

# CHANGE THESE IF THE ACTUAL ELECTRONICS REQUIRE DIFFERENT CLEARANCE
# Modular 3.2-inch HEAD: PCB envelope 89.3w x 55.04h, active LCD ~64.8w x 48.6h.
# 116x80 is a CAD envelope, NOT a hardware-approved mounting tolerance.
HEAD_W=116.0; HEAD_H=80.0; HEAD_DEPTH=58.0; HEAD_R=12.0
HEAD_CZ=111.0; HEAD_REAR_Y=25.0; HEAD_FRONT_Y=-33.0
# Rear shell spans 47 mm from y=25 to seam y=-22, bezel depth=11mm.
HEAD_SEAM_Y=HEAD_FRONT_Y+11.0
HEAD_REAR_DEPTH=HEAD_REAR_Y-HEAD_SEAM_Y
BODY_W=84.0; BODY_D=64.0; BODY_H=55.0; BODY_BOTTOM_Z=5.0
BODY_R=10.0; WALL=3.0
SCREEN_WINDOW_W=69.0; SCREEN_WINDOW_H=52.0; SCREEN_WINDOW_R=5.5
DISPLAY_PCB_W=89.3; DISPLAY_PCB_H=55.04
DISPLAY_ACTIVE_W=64.8; DISPLAY_ACTIVE_H=48.6
BOLT_R=1.65; BOLT_X=52.0; BOLT_Z=32.0
BOT_X=31.; BOT_Y=22.
assert HEAD_W-2*WALL>DISPLAY_PCB_W+4, "Width clearance for display PCB missing"
assert HEAD_H-2*WALL>DISPLAY_PCB_H+4, "Height clearance for display PCB missing"
assert SCREEN_WINDOW_W>DISPLAY_ACTIVE_W and SCREEN_WINDOW_H>DISPLAY_ACTIVE_H, "View aperture crops active pixels"
assert SCREEN_WINDOW_W<DISPLAY_PCB_W and SCREEN_WINDOW_H<DISPLAY_PCB_H, "Window has no PCB overlap"

parts={}
def save(name,solid):
    shape=solid.val() if isinstance(solid,cq.Workplane) else solid
    if not shape.isValid(): print('WARNING - CAD solid fails shape.isValid:',name)
    fp=STL/(name+'.stl')
    cq.exporters.export(shape,str(fp),exportType='STL',tolerance=.12,angularTolerance=.2)
    parts[name]=shape
    mesh=trimesh.load(str(fp),force='mesh',process=True)
    print(f'{name:<31s} volume={shape.Volume():>9.1f} mm3, triangles={len(mesh.faces):>6}, watertight={mesh.is_watertight}, bodies={len(mesh.split(only_watertight=False))}')
    return shape

def rzbox(w,h,t,r):
    # Centred X/Y rounded rectangular plate extruded from z=0 to thickness=t.
    o=cq.Workplane('XY').box(w,h,t,centered=(True,True,False))
    return o.edges('|Z').fillet(r)

def head_plate(w,h,dep,r,back_y,center_z=HEAD_CZ):
    # local sketch coordinates (X,Y) become (X,Z) after rotation, extrusion toward -Y.
    return rzbox(w,h,dep,r).rotate((0,0,0),(1,0,0),90).translate((0,back_y,center_z))

def cylinder_y(x,y,z,r,lenY):
    # y is the near point of a cylinder extending towards +y.
    return cq.Workplane('XY').circle(r).extrude(lenY).rotate((0,0,0),(1,0,0),-90).translate((x,y,z))

# 01. Front head bezel ring and accessible bolt holes
front=head_plate(HEAD_W,HEAD_H,11,HEAD_R,HEAD_SEAM_Y)
window=head_plate(SCREEN_WINDOW_W,SCREEN_WINDOW_H,15,SCREEN_WINDOW_R,HEAD_SEAM_Y+2)
front=front.cut(window)
for xx in (-BOLT_X,BOLT_X):
 for zz in (HEAD_CZ-BOLT_Z,HEAD_CZ+BOLT_Z):
  front=front.cut(cylinder_y(xx,HEAD_FRONT_Y-2,zz,BOLT_R,16))
  front=front.cut(cylinder_y(xx,HEAD_FRONT_Y-2,zz,2.85,2.5))
save('01_head_front_bezel',front)

# 02. Rear hollow head shell, with a near-front open cavity and four long screw posts
# local z=0 is rear outer face at y=25; cavity opens toward face at y=-22.
head=rzbox(HEAD_W,HEAD_H,HEAD_REAR_DEPTH,HEAD_R)
inner=rzbox(HEAD_W-6,HEAD_H-6,HEAD_REAR_DEPTH,HEAD_R-3).translate((0,0,3))
head=head.cut(inner)
# four posts, supported by inside of shell at the edges
for xx in (-BOLT_X,BOLT_X):
 for zz in (-BOLT_Z,BOLT_Z):
  post=cq.Workplane('XY').center(xx,zz).circle(5.1).extrude(HEAD_REAR_DEPTH-3).translate((0,0,3.0))
  head=head.union(post)
  hole=cq.Workplane('XY').center(xx,zz).circle(1.4).extrude(24).translate((0,0,HEAD_REAR_DEPTH-23.5))
  head=head.cut(hole)
head=head.rotate((0,0,0),(1,0,0),90).translate((0,HEAD_REAR_Y,HEAD_CZ))
# Slot on top face for leaf peg, positioned slightly to right and mid-depth
head=head.cut(cq.Workplane('XY').box(6.4,4.4,7,centered=(True,True,False)).translate((9,1,HEAD_CZ+36)))
# Slot for neck assembly at base of head. Do not call this a working servo bearing.
head=head.cut(cq.Workplane('XY').box(17.4,15.4,9,centered=(True,True,False)).translate((0,1,HEAD_CZ-43)))
# two top button apertures through enlarged roof
for xx in (-40,-28):
 head=head.cut(cq.Workplane('XY').circle(3.6).extrude(9).translate((xx,0,HEAD_CZ+36)))
save('02_head_rear_housing',head)

# 03. Provisional 3.2-inch display carrier: support ring around active view.
# PCB 89.3x55.04 fits INSIDE nominal 100x66 carrier, not mounted by exact PCB holes.
# Manufacturer mounting features and cable exit are still unknown.
screen=head_plate(102.0,66.0,3,4,HEAD_SEAM_Y+4.5)
screen=screen.cut(head_plate(69,52,6,3,HEAD_SEAM_Y+6))
# Relief for screw posts; nominal support ledges to be revised after hardware fit.
for xx in (-BOLT_X,BOLT_X):
 for zz in (HEAD_CZ-BOLT_Z,HEAD_CZ+BOLT_Z):
  screen=screen.cut(cylinder_y(xx,HEAD_SEAM_Y-1,zz,5.6,11))
save('03_universal_screen_carrier',screen)

# 04. Optional removable decorative face insert (NOT for use over a real OLED).
def happy_eye(cx,back_y=HEAD_FRONT_Y+10.7,eye_z=HEAD_CZ-3,depth=1.3):
    # Flat arch bands in XZ oriented toward -Y.
    outer=[(cx+10.0*math.cos(th),eye_z-HEAD_CZ+10.0*math.sin(th))
           for th in np.linspace(math.pi/18,17*math.pi/18,28)]
    inner=[(cx+6.6*math.cos(th),eye_z-HEAD_CZ+6.6*math.sin(th))
           for th in np.linspace(17*math.pi/18,math.pi/18,28)]
    return cq.Workplane('XY').polyline(outer+inner).close().extrude(depth).rotate((0,0,0),(1,0,0),90).translate((0,back_y,HEAD_CZ))

blank=head_plate(67,50,1.8,4.2,HEAD_SEAM_Y+0.5)
# Decorative cap only; omit with LCD. New eyes follow updated head Z.
blank=blank.union(happy_eye(-19,HEAD_SEAM_Y-0.3,eye_z=HEAD_CZ-3,depth=1.6)).union(happy_eye(19,HEAD_SEAM_Y-0.3,eye_z=HEAD_CZ-3,depth=1.6))
save('04_optional_display_blank',blank)
# Two optional colored overlays for the decorative face only.
# Omit both the blank/overlays when installing a real animated display.
save('15_optional_left_eye_overlay',happy_eye(-19,HEAD_SEAM_Y-1.85,eye_z=HEAD_CZ-3,depth=0.8))
save('16_optional_right_eye_overlay',happy_eye(19,HEAD_SEAM_Y-1.85,eye_z=HEAD_CZ-3,depth=0.8))

# 05. Hollow lower body with removable bottom opening and rear vent slots
body=rzbox(BODY_W,BODY_D,BODY_H,BODY_R)
inner=rzbox(BODY_W-2*WALL,BODY_D-2*WALL,BODY_H-3,BODY_R-WALL).translate((0,0,-1))
body=body.cut(inner)
# body locally z0..55 becomes world z5..60.
# bottom-facing fastener bosses supported against side shells
for xx in (-BOT_X,BOT_X):
 for yy in (-BOT_Y,BOT_Y):
  boss=cq.Workplane('XY').center(xx,yy).circle(5).extrude(16)
  bridge=cq.Workplane('XY').box(10,6,16,centered=(True,True,False)).translate((math.copysign(BODY_W/2-6,xx),yy,0))
  body=body.union(boss).union(bridge)
  hole=cq.Workplane('XY').center(xx,yy).circle(1.4).extrude(18).translate((0,0,-1))
  body=body.cut(hole)
# neck hole through top roof centered at x=0,y=1
body=body.cut(cq.Workplane('XY').center(0,1).rect(17.2,16.4).extrude(10).translate((0,0,BODY_H-7)))
# subtle slot vents through back wall +Y; all z measured locally
for xx in (-16,-8,0,8,16):
  vent=cq.Workplane('XY').box(3,10,14,centered=(True,True,False)).translate((xx,BODY_D/2-1,20))
  body=body.cut(vent)
body=body.translate((0,0,BODY_BOTTOM_Z))
save('05_lower_body_shell',body)

# 06. Lower plate with four screw holes
bottom=rzbox(BODY_W,BODY_D,3.0,BODY_R)
for xx in (-BOT_X,BOT_X):
 for yy in (-BOT_Y,BOT_Y):
  bottom=bottom.cut(cq.Workplane('XY').center(xx,yy).circle(1.65).extrude(5).translate((0,0,-1)))
  bottom=bottom.cut(cq.Workplane('XY').center(xx,yy).circle(3.15).extrude(2).translate((0,0,-.4)))
save('06_base_bottom_cover',bottom)

# 07. Optional glowing translucent base outline as separate thin ring
led=rzbox(BODY_W,BODY_D,2,BODY_R).cut(rzbox(BODY_W-9,BODY_D-9,4,BODY_R-3).translate((0,0,-1)))
led=led.translate((0,0,3))
save('07_underglow_diffuser_ring',led)

# 08. Mechanical generic neck/pedestal with central cable clearance
# (holes in body/head are nominal; not a servo-specific pivot.)
neck=rzbox(17,15,22,4).translate((0,1,57.0))
neck=neck.cut(cq.Workplane('XY').rect(7,6).extrude(24).translate((0,1,56)))
save('08_neck_with_cable_channel',neck)

# 09. Generic electronics removable platform inside body, with cable-tie slots
tray=rzbox(69,49,2.5,4).translate((0,0,13))
for xx in (-27,27):
 for yy in (-17,17):
  tray=tray.cut(cq.Workplane('XY').center(xx,yy).circle(2).extrude(4).translate((0,0,12.5)))
for xx in (-11,11):
 for yy in (-11,11):
  tray=tray.cut(cq.Workplane('XY').center(xx,yy).rect(9,2).extrude(4).translate((0,0,12.5)))
# Relief notches for the four screw pillars at the sides of the body
for xx in (-BOT_X,BOT_X):
 for yy in (-BOT_Y,BOT_Y):
  tray=tray.cut(cq.Workplane('XY').center(xx,yy).circle(5.5).extrude(4).translate((0,0,12.5)))
save('09_electronics_tray_generic',tray)

# 10. Universal servo cradle mockup / requires exact servo model dimensions
# U-shaped base cradle, inner space ~ 24.5 x 13.5 mm; not verified MG90S compatibility.
servo=rzbox(34,26,3.5,3).translate((0,1,24))
for xx in (-15.2,15.2):
 servo=servo.union(cq.Workplane('XY').box(3.5,26,13,centered=(True,True,False)).translate((xx,1,27.5)))
for xx in (-13.5,13.5):
 servo=servo.cut(cq.Workplane('XY').center(xx,1).circle(1.65).extrude(15).translate((0,0,23)))
save('10_servo_cradle_generic',servo)

# 11. Leaf sprout, single removable flattened piece, printed flat on build plate.
# Sketch in XY --> rotate X 90 to become XZ, extrusion toward -Y.
def leaf_shape(coords,thickness=3.2):
 w=cq.Workplane('XY').moveTo(*coords[0])
 for p in coords[1:]: w=w.lineTo(*p)
 return w.close().extrude(thickness)
# relative z coordinates with global origin at 123.5
stem=cq.Workplane('XY').moveTo(6,-2).lineTo(11,-2).lineTo(12,15).lineTo(8,15).close().extrude(4)
# rounded flowing contours through spline points
right=cq.Workplane('XY').moveTo(9,10).spline([(12,16),(16,23),(23,29),(27,31),(25,20),(19,13),(9,10)],includeCurrent=True).close().extrude(3.5)
left=cq.Workplane('XY').moveTo(10,9).spline([(5,17),(-2,23),(-10,22),(-14,19),(-11,12),(-3,9),(10,9)],includeCurrent=True).close().extrude(3.5)
leaf=stem.union(right).union(left)
# short peg for leaf roof slot
leaf=leaf.union(cq.Workplane('XY').rect(5.6,7).extrude(3.6).translate((9,-4,0)))
leaf=leaf.rotate((0,0,0),(1,0,0),90).translate((0,2.8,HEAD_CZ+37))
# ensure face orientation and intended display position
save('11_leaf_sprout_top',leaf)

# 12+13. Small removable button caps
for k,xx in enumerate((-40,-28),start=12):
 cap=cq.Workplane('XY').circle(3.35).extrude(3).translate((xx,0,HEAD_CZ+38.8))
 cap=cap.union(cq.Workplane('XY').circle(2.65).extrude(2.2).translate((xx,0,HEAD_CZ+37.0)))
 save(f'{k:02d}_top_button_cap',cap)

# 14. Optional logo plaque fixed to body front; print as separate contrasting accent.
# XZ text orientation uses y-normal, front-facing side is negative Y.
logo=rzbox(43,17,1.7,3.2).rotate((0,0,0),(1,0,0),90).translate((0,-BODY_D/2-0.5,30.2))
# label is printed as a plaque with embossed simple letters; try fully merged with text where possible
try:
 txt=cq.Workplane('XZ').text('NOHUT',9,0.9,font='DejaVu Sans',kind='bold',halign='center',valign='center').translate((0,-BODY_D/2-2.0,32.3))
 logo=logo.union(txt)
 label=cq.Workplane('XZ').text('FALAFEL',4.5,0.85,font='DejaVu Sans',kind='bold',halign='center',valign='center').translate((0,-BODY_D/2-2.0,25.4))
 logo=logo.union(label)
except Exception as e:
 print('Logo text fallback:',str(e)[:90])
save('14_front_logo_badge',logo)

# Merged / combined model of ALL individual STLs in their design coordinates:
# Carries true cavities and all print parts; may contain overlapping/separated solids.
meshes=[]
for k in sorted(parts):
 meshes.append(trimesh.load(str(STL/(k+'.stl')),force='mesh',process=True))
combined=trimesh.util.concatenate(meshes)
combined.export(str(STL_M/'NOHUTCUK_ALL_PARTS_ASSEMBLED_REFERENCE.stl'))
print('ALL_PARTS_ASSEMBLED_REFERENCE:',len(combined.faces),'triangles, watertight per component:',combined.is_watertight,'components:',len(combined.split(only_watertight=False)))

# The second requested single model: **one fused decorative print** rather than the electronics-accessible build.
# Designed as single watertight figurine; use supports for overhanging head/leaves.
# Intentionally solid to avoid inaccessible pockets in a one-piece physical print.
monobody=rzbox(BODY_W,BODY_D,BODY_H+BODY_BOTTOM_Z+0.1,BODY_R)
monohead=head_plate(HEAD_W,HEAD_H,HEAD_DEPTH,HEAD_R,HEAD_REAR_Y,HEAD_CZ)
mononeck=rzbox(18,17,21,4).translate((0,1,57))
mono=monobody.union(mononeck).union(monohead)
# inset dark panel effect: recess shallow pocket into front face, not a through-hole.
mono=mono.cut(head_plate(SCREEN_WINDOW_W,SCREEN_WINDOW_H,1.7,5.5,HEAD_FRONT_Y+1.3,HEAD_CZ))
# manual stylized leaves overlap head top, need connection
monoleaf=leaf
mono=mono.union(monoleaf)
# Add two physical cheerful eyebrows / eyes to the sunken face of decorative statue.
# On functional robot these will be digital on OLED, not fixed 3D geometry.
mono=mono.union(happy_eye(-19,HEAD_FRONT_Y+1.85,eye_z=HEAD_CZ-3,depth=1.6))
mono=mono.union(happy_eye(19,HEAD_FRONT_Y+1.85,eye_z=HEAD_CZ-3,depth=1.6))
# add simple top buttons
for xx in (-40,-28): mono=mono.union(cq.Workplane('XY').circle(3.4).extrude(3).translate((xx,0,HEAD_CZ+38.7)))
# optional front plaque slightly merged to torso
# Display logo as separate color-accent part in modular model; fuse plaque to statue here
mono=mono.union(logo.translate((0,1.0,0)))
# Carve outline around lower base to suggest light ring
# A shallow groove along x-y section at body z=4.5 gives model recognizable lower lip
try:
 ringcut=rzbox(BODY_W+0.2,BODY_D+0.2,1,BODY_R).cut(rzbox(BODY_W-2.5,BODY_D-2.5,3,BODY_R-1).translate((0,0,-1))).translate((0,0,4.0))
 mono=mono.cut(ringcut)
except Exception as ex:print('Groove fallback',str(ex)[:100])
statue=mono.val()
print('One-piece CAD shape',len(statue.Solids()),'valid',statue.isValid(),'volume',statue.Volume())
cq.exporters.export(statue,str(STL_M/'NOHUTCUK_ONE_PIECE_SOLID_STATUE.stl'),exportType='STL',tolerance=.12,angularTolerance=.2)
cq.exporters.export(statue,str(STEP/'NOHUTCUK_ONE_PIECE_SOLID_STATUE.step'),exportType='STEP')
statue_mesh=trimesh.load(str(STL_M/'NOHUTCUK_ONE_PIECE_SOLID_STATUE.stl'),force='mesh',process=True)
print('One-piece mesh watertight:',statue_mesh.is_watertight,'components:',len(statue_mesh.split(only_watertight=False)),'Euler:',statue_mesh.euler_number)

# STEP version of the relevant entire solids for editable geometry, not just triangle mesh.
# Keep module components as separate solids in STEP for future parametric adjustment.
try:
 assembly=cq.Assembly(name='NOHUTCUK_Individual_Parts')
 for name,shape in parts.items(): assembly.add(shape,name=name)
 assembly.save(str(STEP/'NOHUTCUK_MODULAR_ASSEMBLY.step'))
except Exception as e: print('Assembly STEP export issue:',str(e)[:200])

print('Wrote',len(parts),'parts to',ROOT)
