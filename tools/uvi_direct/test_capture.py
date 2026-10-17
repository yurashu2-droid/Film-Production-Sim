"""No GUI or licensed instrument is opened by these checks."""
import os
from contextlib import contextmanager
from pathlib import Path
import struct
import tempfile
import threading
import unittest
from unittest.mock import patch
import zlib

from voice_registry import get_voice, list_voices, voice_state, save_current_voice
from voice_studio import run_studio, request_capture


def preset(name='Example Synth', bank='UVI Starter', multiple=False):
    extra = '<Program DisplayName="Second" ProgramPath="$Prisma.ufs/Presets/Second.uvip" />' if multiple else ''
    xml = (f'<UVI4><Engine><Synth><Part><Program DisplayName="{name}" '
           f'ProgramPath="${bank}.ufs/Presets/Lead/{name}.uvip" />'
           f'{extra}</Part></Synth></Engine></UVI4>').encode()
    component = b'UVI4' + struct.pack('<II', 1, len(xml)) + zlib.compress(xml)
    offset = 48 + len(component)
    return (b'VST3' + struct.pack('<I', 1) + b'0' * 32 + struct.pack('<Q', offset)
            + component + b'List' + struct.pack('<I', 1)
            + b'Comp' + struct.pack('<QQ', 48, len(component)))


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.env = patch.dict(os.environ, UVI_VOICE_DIR=self.temp.name)
        self.env.start()
        self.addCleanup(self.env.stop)

    def test_current_preset_is_named_saved_and_discovered(self):
        data = preset()
        saved = save_current_voice(data)
        self.assertEqual(saved['id'], 'example_synth')
        self.assertEqual(saved['preset'], 'Example Synth')
        self.assertEqual(saved['bank'], 'UVI Starter')
        self.assertEqual(voice_state(saved['id']).read_bytes(), data)
        self.assertTrue(next(v for v in list_voices() if v['id'] == saved['id'])['registered'])

    def test_known_presets_keep_shared_semantic_ids(self):
        saved = save_current_voice(preset('Bite Them'))
        self.assertEqual(saved['id'], 'lead')
        self.assertEqual(get_voice('lead')['preset'], 'Bite Them')

    def test_registering_the_same_preset_updates_without_duplicate_entries(self):
        save_current_voice(preset())
        save_current_voice(preset())
        self.assertEqual(len([v for v in list_voices() if v['id'] == 'example_synth']), 1)

    def test_invalid_state_does_not_create_a_voice(self):
        with self.assertRaises(ValueError):
            save_current_voice(b'not a preset')
        self.assertEqual(list(Path(self.temp.name).iterdir()), [])

    def test_unsafe_display_name_cannot_escape_the_voice_folder(self):
        saved = save_current_voice(preset('../Outside'))
        self.assertEqual(voice_state(saved['id']).parent, Path(self.temp.name))
        self.assertNotIn('/', saved['id'])

    def test_multiple_parts_are_not_registered_under_one_misleading_name(self):
        with self.assertRaisesRegex(ValueError, 'Single mode'):
            save_current_voice(preset(multiple=True))
        self.assertEqual(list(Path(self.temp.name).iterdir()), [])

    def test_no_registration_editor_fails_with_an_actionable_error(self):
        with self.assertRaisesRegex(ValueError, 'studio'):
            request_capture(timeout=.1)

    def test_capture_signal_saves_on_main_thread_and_reopens_editor(self):
        main_thread = threading.get_ident()
        ready = threading.Event()
        results = []
        failures = []
        preview_active = []

        @contextmanager
        def preview(plugin):
            preview_active.append(True)
            try:
                yield
            finally:
                preview_active.pop()

        class Instrument:
            count = 0

            @property
            def preset_data(self):
                if threading.get_ident() != main_thread:
                    raise AssertionError('VST3 state accessed from a background thread')
                if preview_active:
                    raise AssertionError('State saved while audio processing was active')
                return preset()

            def show_editor(self, close_event):
                if not preview_active:
                    raise AssertionError('Editor opened without audio preview')
                self.count += 1
                if self.count == 1:
                    ready.set()
                    if not close_event.wait(3):
                        raise AssertionError('Capture did not close the editor')
                # Returning on the second invocation simulates the user closing it.

        def client():
            try:
                if not ready.wait(3):
                    raise AssertionError('Editor never opened')
                results.append(request_capture(timeout=3))
            except Exception as error:
                failures.append(error)

        thread = threading.Thread(target=client)
        thread.start()
        instrument = Instrument()
        with patch('voice_studio.preview_audio', side_effect=preview):
            run_studio(instrument)
        thread.join(4)
        self.assertFalse(thread.is_alive())
        self.assertEqual(failures, [])
        self.assertEqual(results[0]['voice']['id'], 'example_synth')
        self.assertEqual(instrument.count, 2)
        self.assertTrue(voice_state('example_synth').is_file())


if __name__ == '__main__':
    unittest.main()
