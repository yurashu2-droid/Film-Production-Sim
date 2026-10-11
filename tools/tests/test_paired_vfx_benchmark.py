import sys
from pathlib import Path
import unittest
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from paired_vfx_benchmark import TASKS, mode_for, candidate, prepare_files, ROOT
from summarize_paired_vfx import before, subtract, stamp


class PairedFixturesTest(unittest.TestCase):
    def test_token_interval_uses_marker_boundaries_and_cache_subsets(self):
        events = [(stamp("2026-10-11T09:00:00+00:00"), {"input_tokens":1000,"cached_input_tokens":800,"output_tokens":40,"reasoning_output_tokens":10}),
                  (stamp("2026-10-11T09:00:20+00:00"), {"input_tokens":1600,"cached_input_tokens":1300,"output_tokens":100,"reasoning_output_tokens":25}),
                  (stamp("2026-10-11T09:00:40+00:00"), {"input_tokens":2000,"cached_input_tokens":1600,"output_tokens":120,"reasoning_output_tokens":30})]
        delta = subtract(before(events, stamp("2026-10-11T09:00:30+00:00")), before(events, stamp("2026-10-11T09:00:10+00:00")))
        self.assertEqual(delta["uncached_input_tokens"], 100)
        self.assertEqual(delta["cached_input_tokens"], 500)
        self.assertEqual(delta["output_tokens"], 60)
        self.assertEqual(delta["reasoning_output_tokens"], 15)
        with self.assertRaises(ValueError):
            subtract(events[0][1], events[1][1])

    def test_each_pair_starts_identically_with_complementary_methods(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            source = root / "godot/vfx/punch_trial_a"
            source.mkdir(parents=True)
            for file in ("punch.gd", "mark.gdshader"):
                (source / file).write_bytes((ROOT / "godot/vfx/punch_trial_a" / file).read_bytes())
            prepare_files(root)
            canonical = (root / "godot/.godot/dev_session/punch_paired/canonical.gd").read_bytes()
            for case in TASKS:
                self.assertEqual({mode_for(w, case) for w in ("left", "right")}, {"full", "compact"})
                left, right = (candidate(w, case, root) for w in ("left", "right"))
                self.assertNotEqual(left, right)
                self.assertEqual(left.read_bytes(), right.read_bytes())
                self.assertNotEqual(left.read_bytes(), canonical)
            with self.assertRaises(ValueError):
                prepare_files(root)


if __name__ == "__main__":
    unittest.main()
