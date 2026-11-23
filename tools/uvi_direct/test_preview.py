"""Preview runs while the editor is open and stops before state is saved."""
import threading
import unittest
from unittest.mock import patch

from voice_preview import preview_audio


class PreviewTests(unittest.TestCase):
    def test_audio_reaches_output_without_resetting_the_instrument(self):
        played = threading.Event()
        calls = []
        main_thread = threading.get_ident()

        class Stream:
            sample_rate = 48000
            closed = False

            def __enter__(self):
                return self

            def __exit__(self, *args):
                self.closed = True

            def write(self, audio, rate):
                self.assert_audio = (audio, rate)
                played.set()
                threading.Event().wait(.005)

        def plugin(messages, **kwargs):
            calls.append((threading.get_ident(), messages, kwargs))
            return 'audio from instrument'

        stream = Stream()
        with patch('voice_preview.open_output', return_value=stream):
            with preview_audio(plugin):
                self.assertTrue(played.wait(1), 'Editor has no live audio output')
                self.assertFalse(stream.closed)
        self.assertTrue(stream.closed)
        self.assertEqual(stream.assert_audio, ('audio from instrument', 48000))
        self.assertTrue(any(tid != main_thread for tid, _, _ in calls))
        self.assertTrue(all(not options['reset'] for _, _, options in calls))
        self.assertEqual(calls[-1][0], main_thread)
        count = len(calls)
        threading.Event().wait(.02)
        self.assertEqual(len(calls), count, 'Audio worker survived editor closure')


if __name__ == '__main__':
    unittest.main()
