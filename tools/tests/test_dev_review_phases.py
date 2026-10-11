import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dev_review import select_samples, review


class PhaseSelectionTest(unittest.TestCase):
    def test_preserves_short_impact_exit_and_unexpected_failure(self):
        samples = [{"frame": i, "checks": [{"passed": i != 10, "severity": 0.2 if i == 10 else 0}]} for i in range(31)]
        selected = select_samples(samples, 6, key_frames=[1, 2, 20])
        self.assertEqual(len(selected), 6)
        self.assertTrue({0, 1, 2, 10, 20, 30}.issubset(selected))
        self.assertEqual(selected, select_samples(samples, 6, key_frames=[1.0, 2.0, 20.0]))
        with self.assertRaises(ValueError):
            select_samples(samples, 6, key_frames=[100])
        with self.assertRaises(ValueError):
            select_samples(samples, 6, key_frames=list(range(1, 7)))

    def test_invalid_key_frame_fails_before_contacting_engine(self):
        class UnusedSession:
            def request(self, *args, **kwargs):
                raise AssertionError("Must not contact the engine")
        with self.assertRaises(ValueError):
            review(UnusedSession(), {"frames": [0, 6, 12], "key_frames": [5]}, Path("unused"))


if __name__ == "__main__":
    unittest.main()
