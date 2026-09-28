#!/bin/sh
# KiCad 9 raytraced renders of the pod PCB (colour reference for the Blender close-up).
# Run from hardware/work with the kicad9 docker wrapper on PATH.
cd ../outputs/NIVA-3D-engineering-prototype/electronics || exit 1
O=../renders/pcb-raw; mkdir -p $O
R="kicad9 kicad-cli pcb render --quality high --background opaque --width 2400 --height 2400"
$R --side top    -o $O/pcb_top.png       NIVA-pod.kicad_pcb
$R --side bottom -o $O/pcb_underside.png NIVA-pod.kicad_pcb
$R --side top --perspective --floor --rotate "-38,0,30" --zoom 0.85 -o $O/pcb_iso.png NIVA-pod.kicad_pcb
$R --side top --perspective --floor --rotate "-50,0,-25" --zoom 2.0 --pan "0.3,-0.6,0" -o $O/pcb_closeup.png NIVA-pod.kicad_pcb
