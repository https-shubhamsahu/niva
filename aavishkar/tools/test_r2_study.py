"""Analytic/software fixtures only; these are not research data."""
import sys
from pathlib import Path
import unittest
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parent))
from r2_study import discs, centres, measure, select, LAYOUTS, PITCH, DIAMETER

class GeometryTests(unittest.TestCase):
    def test_circle_area_and_overlap_union(self):
        positions=np.array([[10.,10.],[10.,10.]])
        w,u=discs((21,21),positions)
        expected=np.pi*(DIAMETER/2)**2
        self.assertLess(abs(u.sum()*PITCH**2-expected)/expected,.005)
        np.testing.assert_array_equal(w[0],u)
        np.testing.assert_array_equal(u,u[::-1,::-1])

    def test_uniform_field_analytic_coverage(self):
        step=np.ones((3,21,21))
        r=measure(step,np.array([[10.,10.]]))
        expected=100*np.pi*(DIAMETER/2)**2/(21*21*PITCH**2)
        self.assertAlmostEqual(r['area_pct'],expected,delta=.005*expected)
        self.assertEqual(r['area_pct'],r['load_pct'])
        self.assertAlmostEqual(r['cop_ap_mae_mm'],0.)
        self.assertAlmostEqual(r['cop_ml_mae_mm'],0.)

    def test_completely_missed_frame_is_kept(self):
        step=np.zeros((2,21,21));step[0,2,2]=50
        r=measure(step,np.array([[15.,15.]]))
        self.assertEqual(r['area_pct'],0.)
        self.assertEqual(r['load_pct'],0.)
        self.assertEqual(r['peak_hit_pct'],0.)
        self.assertEqual(r['undefined_cop_pct'],100.)
        self.assertIsNone(r['cop_ap_mae_mm'])
        self.assertEqual(r['loaded_frames'],1)
        self.assertEqual(r['empty_frames'],1)
        self.assertEqual(r['load_bias_pct'],-100.)

    def test_side_mirroring_and_padding_invariance(self):
        step=np.zeros((3,25,15));step[:,4:22,3:13]=1
        step[1,5,4]=20
        pos=centres((4,21,3,12),LAYOUTS['niva4'],'Right')
        a=measure(step,pos)
        mirrored=step[:,:,::-1]
        left=centres((4,21,2,11),LAYOUTS['niva4'],'Left')
        b=measure(mirrored,left)
        padded=np.pad(step,((0,0),(5,5),(6,6)))
        c=measure(padded,pos+np.array([5,6]))
        for key in a:
            if a[key] is not None:
                self.assertAlmostEqual(a[key],b[key],places=10,msg=key)
                self.assertAlmostEqual(a[key],c[key],places=10,msg=key)

    def test_chronological_selection_flags_and_pairing(self):
        a=np.zeros((28,2,5,5));a[:,:,1:4,1:4]=1
        meta=[{'FootstepID':str(i),'StartFrame':str(i),'Side':'Right' if i%2==0 else 'Left',
               'Exclude':'1' if i==0 else '0','Incomplete':'0','Standing':'0','Outlier':'0'}
              for i in range(len(a))]
        chosen,audit=select(a,meta,2,'BF')
        self.assertEqual(chosen['Right'],list(range(2,26,2)))
        self.assertEqual(chosen['Left'],list(range(1,24,2)))
        self.assertEqual(audit[0]['status'],'excluded')
        chosen,_=select(a[:20],meta[:20],2,'BF')
        self.assertEqual(chosen,{'Right':[],'Left':[]})

if __name__=='__main__':
    unittest.main()
