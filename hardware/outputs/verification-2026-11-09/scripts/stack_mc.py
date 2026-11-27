"""Spring-pin compression stacks, pod J2 and dock J2 (Mill-Max 0900-0: free 3.49, mid 0.5, max 1.0, lengths +-0.15).
Symmetric tolerances are normal with 3 sigma = stated tolerance; one-sided effects are uniform. 1e6 samples."""
import numpy as np
rng = np.random.default_rng(1); N = 1_000_000
n = lambda tol: rng.normal(0, tol / 3, N)
u = lambda a, b: rng.uniform(a, b, N)
def report(name, c, extra=''):
    print(f'{name}: mean {c.mean():.3f}  p0.1% {np.percentile(c,0.1):.3f}  p99.9% {np.percentile(c,99.9):.3f}  '
          f'P(c<=0, open) {100*(c<=0).mean():.2f} %  P(c<0.15, <35 g) {100*(c<0.15).mean():.2f} %  P(c>=1.0, bottomed) {100*(c>=1.0).mean():.2f} %  {extra}')
# ---- pod: CAD nominal 0.595 (pin tip 8.235 incl. 0.04 pad Cu + 0.045 solder; plate top 8.83)
for label, fdm in (('FDM +-0.2 (PCBWay)', 0.2), ('FDM +-0.1 (tuned printer)', 0.1)):
    sym = n(fdm) + n(fdm) + n(fdm) + n(fdm)         # boss-to-recess-ceiling, tab t, cup height, pocket floor height
    c = 0.595 + sym + n(0.02) + n(0.15) + n(0.03)   # plate t, pin length, solder
    c += u(0, 0.1) + u(0.02, 0.1)                   # lid bond line, plate adhesive (raise the plate)
    c -= u(0, 0.15) + u(0, 0.1)                     # recess-ceiling bridge sag, board lift (rib gap / thin board)
    report(f'pod, cartridge clamped flat, {label}', c)
    report(f'pod, worn, far end tilted onto cradle (-0.35 at pins), {label}', c - 0.35)
# worst cases (pod)
wc_hi = 0.595 + 4*0.2 + 0.02 + 0.15 + 0.03 + 0.1 + 0.1
wc_lo = 0.595 - 4*0.2 - 0.02 - 0.15 - 0.03 + 0 + 0.02 - 0.15 - 0.1 - 0.35
print(f'pod worst case: {wc_lo:.2f} .. {wc_hi:.2f} mm')
# ---- dock: CAD nominal 0.503; real top-boss datum adds +0.05 when the PCB is clamped
for label, fdm in (('FDM +-0.2', 0.2), ('FDM +-0.1', 0.1)):
    t = 1.6 + n(0.16)                                # PCB thickness +-10 %
    space = 1.66 + n(fdm) + n(fdm)                   # base standoff top to top-boss bottom (two parts)
    loose = np.maximum(0, space - t)                 # PCB pushed down onto the standoffs by the pins
    c = 0.553 - loose + n(fdm) + n(fdm) + n(0.15) + n(0.03)   # floor-to-boss (top), cup floor, pin length, solder
    c -= u(0, 0.1)                                   # strip bonding adhesive (strip bonded!)
    report(f'dock, strip bonded, cartridge on floor, {label}', c)
    report(f'dock, same, lifted onto the hook (-0.1)', c - 0.1)
