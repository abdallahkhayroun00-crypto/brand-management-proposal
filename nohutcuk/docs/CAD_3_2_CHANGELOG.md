# Nohutçuk — 3.2-inch ILI9341 parametric CAD and STL revision

**Created:** 2026-10-27. **State:** computer-generated and mesh-validated **PROTOTYPE**, **NOT tested with real parts or printed**.

## Current component envelope assumed for CAD

- Screen controller: ILI9341 SPI TFT, 3.2-inch, 240×320 rotated to landscape 320×240.
- Retail reference: **Voltaj MZK-6, non-touch** (merchant-supplied PCB envelope **89.30 mm horizontal × 55.04 mm vertical**; approximate visible image **64.8 × 48.6 mm**). Exact purchased unit, connector, PCB thickness, mounting-hole locations and panel edge details are **not confirmed**.
- The robot PC screenshot uses an **ESP32-S3-BOX-3 Wokwi example**. That is not a pin-equivalent representation of the ESP32-S3-DevKitC-1 planned for real hardware.
- Previous 1.9-inch and 2.4-inch options are **not on the purchase list**.

## Parametric CAD dimensions (millimetres)

| Feature | Earlier CAD | 3.2-inch revision | Comment |
|---|---:|---:|---|
| Outer head W × H × D | 100 × 58 × 50 | **116 × 80 × 58** | provisional clearance for 89.3 × 55.04 PCB |
| Active screen opening W × H | 77 × 34 | **69 × 52** | exceeds estimated visible image 64.8 × 48.6 |
| Head front bezel overall | 100 × 58 × 11 | **116 × 80 × 11** | new hole positions |
| Head rear housing | 100 × 58 × 39 | **116 × 80 × 47** | deeper rear cavity |
| Provisional LCD carrier | 87 × 43 × 3 | **102 × 66 × 3** | needs actual LCD mounting-hole verification |
| Lower body W × D × H | 74 × 58 × 47 | **84 × 64 × 55** | improves volume for electronics |
| Removable bottom plate | 74 × 58 × 3 | **84 × 64 × 3** | matching screw layout |
| Underglow ring | 74 × 58 | **84 × 64** | preserves consistent base |
| Electronics tray footprint | 62 × 43 | **69 × 49** | generic, not SKU-specific |
| One-piece statue | ~100 mm wide, ~155 mm high | **116 mm wide, ~179 mm high** | **decorative**, not functional electronics housing |

Other affected CAD geometry: head screw posts/countersinks, neck clearance, leaf attachment, top buttons, optional display blank and eye overlays, display carrier post relief, rear ventilation, lower-shell bosses, logo position and one-piece recess. The generic 34×26-mm servo cradle remains a **placeholder for an unverified servo**, not a verified MG90S mount. Source design dimensions are in [build_nohutcuk.py](../CAD_Source/build_nohutcuk.py).

## Regenerated deliverables

| Location | Output count | Meaning |
|---|---:|---|
| [STL_Individual](../STL_Individual/) | **16** | modular prototyping parts, CAD/world placement coordinates |
| [STL_Print_Oriented](../STL_Print_Oriented/) | **16** | slicer starting orientations, origin aligned with build plate |
| [STL_Merged](../STL_Merged/) | **2** | separated-parts assembly reference + watertight fused decorative statue |
| [STEP](../STEP/) | **2** | CAD assembly and separate solid decorative statue |
| [Validation JSON](../Docs/Mesh_Validation_Report.json) | 1 | 18 checks (16 oriented parts + two merged models) |
| [Regenerated ZIP](../downloads/NOHUTCUK_CAD_STL_COMPLETE_PROTOTYPE.zip) | 1 | all latest CAD/source/STL/STEP/mesh reports |

**Verified by GitHub CI:** all 16 individual meshes and all 16 oriented meshes are watertight, winding-consistent and connected; the one-piece decorative statue is connected and watertight; STEP and ZIP outputs exist; the new dimensions match the validation report. The **assembled reference STL contains intentionally independent overlapping parts**, so it is **not itself a watertight single print** — not a failure.

Build and mesh validation can be rerun from [CAD_Source/build_nohutcuk.py](../CAD_Source/build_nohutcuk.py) and [prepare_print_and_verify.py](../CAD_Source/prepare_print_and_verify.py). Automatic GitHub workflow [Nohutçuk 3.2-inch CAD regenerate and validate](https://github.com/abdallahkhayroun00-crypto/brand-management-proposal/actions/workflows/nohutcuk-cad-32.yml) compiles and checks these and republishes STLs/STEPs/ZIP on source changes.

## Not validated — hold final printing until these are measured

1. Real MZK-6 PCB edge dimensions, board thickness, cable plug direction/bend radius, connector pinout, viewing glass outer size, and mounting-hole position.
2. Screen-retention mechanics — modelled generic cradle does not yet have confirmed screw holes, standoffs or clearances to actual board hardware.
3. ESP32-S3 exact PCB, amplifier, speaker depth, sensor boards and their collision checks; selected head/body do not guarantee all devices fit simultaneously.
4. MG90S motor body, horn, torque with the enlarged head, real pivot axis, neck turning limits and low-voltage power distribution.
5. Wall printability and tolerances on a chosen printer, mechanical stress, stable base under real head load, tip-over / child safety, cable relief, and cooling.
6. STL files are **unit mm**; print-oriented files are a slicer starting point only. No slicer G-code or validated 3MF and **no physical trial print** exist.

**Use updated STL_Individual, STL_Print_Oriented, STEP and ZIP from this repo; avoid older copies or older ZIP downloads from browser cache.**
