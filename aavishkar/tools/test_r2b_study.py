"""Fixture tests for the R2b runner. They use artificial arrays and stored v1 outputs, never new data."""
import json
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import r2b_study as B


class Aggregation(unittest.TestCase):
    def test_t_critical_values(self):
        for df, expected in ((10, 2.228139), (30, 2.042272), (60, 2.000298), (120, 1.979930)):
            self.assertAlmostEqual(B.t_crit(df), expected, places=5)

    def test_equal_side_weight(self):
        steps = [{'participant': 7, 'condition': 'BF', 'layout': 'niva4', 'side': 'Right', **{k: 10.0 for k in B.KEYS}}] * 3
        steps += [{'participant': 7, 'condition': 'BF', 'layout': 'niva4', 'side': 'Left', **{k: 20.0 for k in B.KEYS}}]
        row = B.participant_means(steps)[0]
        self.assertEqual(row['n_steps'], 4)
        self.assertAlmostEqual(row['area_pct'], 15.0)       # mean of the two side means, not of the four steps

    def test_undefined_values_are_skipped(self):
        base = {'participant': 7, 'condition': 'BF', 'layout': 'niva4'}
        steps = [{**base, 'side': 'Right', **{k: 1.0 for k in B.KEYS}}, {**base, 'side': 'Left', **{k: 3.0 for k in B.KEYS}}]
        steps[0]['cop_ap_mae_mm'] = None
        self.assertAlmostEqual(B.participant_means(steps)[0]['cop_ap_mae_mm'], 3.0)

    def test_spread(self):
        s = B.spread([1.0, 2.0, 3.0, 4.0])
        self.assertAlmostEqual(s['mean'], 2.5)
        self.assertAlmostEqual(s['sd'], math.sqrt(5 / 3))
        half = 3.182446 * math.sqrt(5 / 3) / 2              # t for 3 degrees of freedom
        self.assertAlmostEqual(s['ci95'][1] - s['mean'], half, places=5)
        self.assertEqual((s['n'], s['min'], s['max']), (4, 1.0, 4.0))

    def test_reproduces_the_stored_v1_aggregation(self):
        """Fed the stored v1 step records, the v2 aggregation must give the stored v1 participant and group values."""
        steps = json.loads((B.V1_RUN / 'steps.json').read_text())
        people = B.participant_means(steps)
        stored = json.loads((B.V1_RUN / 'participants.json').read_text())
        self.assertEqual(len(people), len(stored))
        for mine, theirs in zip(people, stored):
            self.assertEqual((mine['participant'], mine['condition'], mine['layout']), (theirs['participant'], theirs['condition'], theirs['layout']))
            for k in B.KEYS:
                self.assertAlmostEqual(mine[k], theirs[k], places=10)
        groups = B.group_summary(people, B.FIRST)
        for mine, theirs in zip(groups, json.loads((B.V1_RUN / 'summary.json').read_text())):
            for k in B.KEYS:
                for stat in ('mean', 'min', 'max'):
                    self.assertAlmostEqual(mine[k][stat], theirs[k][stat], places=10)


class Checks(unittest.TestCase):
    def step(self, reverse=False):
        s = np.zeros((101, 75, 40))
        for t in range(101):
            row = int(round(65 - 55 * t / 100))            # heel (high row) to toe (low row)
            s[t, 74 - row if reverse else row, 20] = 100.0
        return s

    def test_orientation_sign(self):
        self.assertGreater(B.orientation(self.step()), B.ORIENT_MIN)
        self.assertLess(B.orientation(self.step(reverse=True)), 0)

    def test_maxdiff(self):
        self.assertEqual(B.maxdiff({'a': [1.0, None]}, {'a': [1.0, None]}), 0.0)
        self.assertAlmostEqual(B.maxdiff({'a': [1.0, 2.0]}, {'a': [1.0, 2.5]}), 0.5)
        self.assertEqual(B.maxdiff({'a': 1.0}, {'b': 1.0}), math.inf)
        self.assertEqual(B.maxdiff([1.0], [1.0, 2.0]), math.inf)

    def test_cohort(self):
        self.assertEqual((len(B.PARTICIPANTS), B.PARTICIPANTS[0], B.PARTICIPANTS[-1]), (149, 2, 150))
        self.assertNotIn(1, B.PARTICIPANTS)
        self.assertEqual(B.DIAMETERS[0], 12.7)


if __name__ == '__main__':
    unittest.main()
