import math, itertools
T0=298.15
def Rntc(T,R25=10e3,B=3435): return R25*math.exp(B*(1/(T+273.15)-1/T0))
def T_of(R,R25=10e3,B=3435): return 1/(1/T0+math.log(R/R25)/B)-273.15
def trips(R5=22e3,R6=43e3,R7=39e3,R8=18e3,R25=10e3,B=3435,vos_hi=0.0,vos_lo=0.0,vbus=5.0,ib=0.0):
    tot=R6+R7+R8
    vhi=vbus*(R7+R8)/tot + ib*(R6*(R7+R8)/tot)   # bias current out of pin raises node
    vlo=vbus*R8/tot + ib*(R8*(R6+R7)/tot)
    # NTC_S node: two inputs draw ib out -> raises node by 2ib*(R5||Rn); solve numerically
    def T_at(vth):
        lo,hi=-40.0,120.0
        for _ in range(100):
            m=(lo+hi)/2; Rn=Rntc(m,R25,B); v=vbus*Rn/(R5+Rn)+2*ib*(R5*Rn/(R5+Rn))
            if v>vth: lo=m
            else: hi=m
        return m
    return T_at(vhi+vos_hi), T_at(vlo+vos_lo)
print('nominal B3435:', ['%.2f'%x for x in trips()])
for B in (3380,3435,3950,3977,4100): print('B',B, ['%.2f'%x for x in trips(B=B)])
# worst-case corners
for B in (3435,3950):
    cold=[];hot=[]
    for r5,r6,r7,r8,r25,b,v1,v2 in itertools.product((0.99,1.01),(0.99,1.01),(0.99,1.01),(0.99,1.01),(0.99,1.01),(0.99,1.01),(-9e-3,9e-3),(-9e-3,9e-3)):
        c,h=trips(22e3*r5,43e3*r6,39e3*r7,18e3*r8,10e3*r25,B*b,v1,v2,ib=250e-9)
        cold.append(c);hot.append(h)
    print('B',B,'1pctR,1pctNTC,1pctB,+-9mV,250nA: cold trip %.2f..%.2f  hot trip %.2f..%.2f'%(min(cold),max(cold),min(hot),max(hot)))
    cold=[];hot=[]
    for r5,r6,r7,r8 in itertools.product((0.99,1.01),repeat=4):
        c,h=trips(22e3*r5,43e3*r6,39e3*r7,18e3*r8,B=B)
        cold.append(c);hot.append(h)
    print('B',B,'1pct resistors only: cold %.2f..%.2f hot %.2f..%.2f'%(min(cold),max(cold),min(hot),max(hot)))
# slopes
for T in (0,45):
    Rn=Rntc(T); r=Rn/(22e3+Rn); dr=r*(1-r)*(-3435/((T+273.15)**2)); print('T',T,'ratio %.3f'%r,'dV/dT %.1f mV/C'%(dr*5000))
# Q: retune for ~3-42C with B3435 and B3950
def ratio(T,B): Rn=Rntc(T,B=B); return Rn/(22e3+Rn)
for B in (3435,3950):
    print('B',B,'ratio at 3C %.4f at 42C %.4f'%(ratio(3,B),ratio(42,B)))
# self-heating of NTC: power at 45C
Rn=Rntc(45); i=5/(22e3+Rn); print('NTC power at 45C %.2f mW'%(i*i*Rn*1e3), 'at 0C', (5/(22e3+Rntc(0)))**2*Rntc(0)*1e3)
print('--- wrong-NTC windows (charging allowed between these temperatures) ---')
for R25,B in ((2.2e3,3435),(4.7e3,3435),(6.8e3,3435),(10e3,3435),(10e3,3950),(15e3,3950),(22e3,3950),(33e3,4050),(47e3,4050),(100e3,4250)):
    c,h=trips(R25=R25,B=B)
    print(f'R25={R25/1e3:5.1f}k B={B}: charge window {c:6.1f} .. {h:6.1f} C ; at 25C ratio {Rntc(25,R25,B)/(22e3+Rntc(25,R25,B)):.3f}')
print('--- proposed retune R6=46.4k R7=33.2k R8=19.6k ---')
for B in (3435,3950):
    print('B',B,'nominal', ['%.2f'%x for x in trips(R6=46.4e3,R7=33.2e3,R8=19.6e3,B=B)])
    cold=[];hot=[]
    for r5,r6,r7,r8,r25,b,v1,v2 in itertools.product((0.99,1.01),(0.99,1.01),(0.99,1.01),(0.99,1.01),(0.99,1.01),(0.99,1.01),(-9e-3,9e-3),(-9e-3,9e-3)):
        c,h=trips(22e3*r5,46.4e3*r6,33.2e3*r7,19.6e3*r8,10e3*r25,B*b,v1,v2,ib=250e-9)
        cold.append(c);hot.append(h)
    print('  worst case cold %.2f..%.2f hot %.2f..%.2f'%(min(cold),max(cold),min(hot),max(hot)))
# CMR check
for vb in (5.25,5.0,4.75,4.5):
    print('VBUS',vb,'VTH_HI %.3f'%(vb*0.57),'CMR 25C %.2f full %.2f'%(vb-1.5,vb-2.0))
# half-seated P+ and NTC only: NTC_S initial
for Rn in (10e3,4.83e3,29.2e3):
    print('P+&NTC only, Rn=%.1fk: NTC_S initial = %.2f V'%(Rn/1e3,(5*Rn-3.7*22e3)/(22e3+Rn)))
