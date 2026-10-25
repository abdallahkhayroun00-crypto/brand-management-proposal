"""Generate print-oriented copies of each prototype STL and validate manifold meshes.
Run: python prepare_print_and_verify.py /path/to/Nohutcuk_STL_Complete
"""
from pathlib import Path
import csv, sys, math, json
import numpy as np
import trimesh
root=Path(sys.argv[1] if len(sys.argv)>1 else Path(__file__).resolve().parents[1])
ind=root/'STL_Individual'; merged=root/'STL_Merged'; dst=root/'STL_Print_Oriented'
dst.mkdir(exist_ok=True)

# Rotation angle around X only; all are *slicer starting orientations*, not machine-verified print profiles.
angles={
 '01_head_front_bezel':90,           # visible front face on bed
 '02_head_rear_housing':-90,         # rear solid back on bed, cavity facing up
 '03_universal_screen_carrier':-90,
 '04_optional_display_blank':-90,   # back down, relief eyes on top
 '05_lower_body_shell':180,          # roof on bed, bottom opening facing up
 '06_base_bottom_cover':0,
 '07_underglow_diffuser_ring':0,
 '08_neck_with_cable_channel':0,
 '09_electronics_tray_generic':0,
 '10_servo_cradle_generic':0,
 '11_leaf_sprout_top':90,            # leaves flat
 '12_top_button_cap':180,
 '13_top_button_cap':180,
 '14_front_logo_badge':-90,
 '15_optional_left_eye_overlay':90,
 '16_optional_right_eye_overlay':90,         # badge back down, letters on top
}
records=[]
for src in sorted(ind.glob('*.stl')):
 stem=src.stem
 mesh=trimesh.load(str(src),force='mesh',process=True)
 angle=angles.get(stem,0)
 xfm=trimesh.transformations.rotation_matrix(math.radians(angle),[1,0,0])
 mesh.apply_transform(xfm)
 mesh.apply_translation([-mesh.bounds.mean(axis=0)[0],-mesh.bounds.mean(axis=0)[1],-mesh.bounds[0,2]])
 dest=dst/src.name
 mesh.export(str(dest))
 rec={'file':dest.name,'watertight':mesh.is_watertight,'connected_components':len(mesh.split(only_watertight=False)),
      'winding_consistent':mesh.is_winding_consistent,'number_of_triangles':len(mesh.faces),
      'size_x_mm':round(float(mesh.extents[0]),2),'size_y_mm':round(float(mesh.extents[1]),2),
      'height_on_plate_mm':round(float(mesh.extents[2]),2),'rotation_x_degrees':angle}
 records.append(rec)
 if not rec['watertight'] or rec['connected_components']!=1:
  raise RuntimeError('Mesh failed validation: '+str(rec))

for f in sorted(merged.glob('*.stl')):
 mesh=trimesh.load(str(f),force='mesh',process=True)
 records.append({'file':f.name,'watertight':mesh.is_watertight,'connected_components':len(mesh.split(only_watertight=False)),
      'winding_consistent':mesh.is_winding_consistent,'number_of_triangles':len(mesh.faces),
      'size_x_mm':round(float(mesh.extents[0]),2),'size_y_mm':round(float(mesh.extents[1]),2),
      'height_on_plate_mm':round(float(mesh.extents[2]),2),'rotation_x_degrees':0})
if not records[-1]['watertight'] or records[-1]['connected_components'] != 1:
  # merged file names sort alphabetically: one-piece last (should be)
  raise RuntimeError('One piece prototype is not connected manifold')
with open(root/'Docs'/'Mesh_Validation_Report.csv','w',newline='') as fp:
 w=csv.DictWriter(fp,fieldnames=records[0].keys());w.writeheader();w.writerows(records)
with open(root/'Docs'/'Mesh_Validation_Report.json','w') as fp:
 json.dump({'dimensions_unit':'millimetres','slicer_fitting_test_performed':False,'real_hardware_fit_verified':False,
 'items':records,'note':'These are computer geometry watertight tests, not a physical fit/safety/print test.'},fp,indent=2)
print('Validated print-oriented',len(list(dst.glob('*.stl'))),'files plus',len(list(merged.glob('*.stl'))),'merged models.')
for r in records:print(r['file'], 'watertight=',r['watertight'], 'bodies=',r['connected_components'], 'size(mm)=',r['size_x_mm'],r['size_y_mm'],r['height_on_plate_mm'])
