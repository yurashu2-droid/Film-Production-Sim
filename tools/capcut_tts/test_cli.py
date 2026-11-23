import tempfile
import unittest
from pathlib import Path

from capcut_speech import generate, resolve_voice


class SpeechTests(unittest.TestCase):
    def test_lively_girl_alias_uses_the_desktop_catalog_voice(self):
        voice = resolve_voice('快活な女の子')
        self.assertEqual(voice, resolve_voice('快活な娘'))
        self.assertEqual(voice['voice_type'], 'ICL_uranus_ja_female_yuanqi')
        self.assertEqual(voice['resource_id'], '7681166532600220936')
        self.assertEqual(voice['lang'], 'ja-JP')

    def test_japanese_display_name_resolves_to_catalog_voice(self):
        voice = resolve_voice('女性AI')
        self.assertEqual(voice['voice_type'], 'ICL_ja_female_lengjingnv')
        with self.assertRaises(ValueError):
            resolve_voice('unknown-voice')

    def test_generation_passes_japanese_and_voice_and_saves_mp3(self):
        class Client:
            def synthesize(self, text, path, **options):
                self.received = (text, options)
                Path(path).write_bytes(b'ID3' + b'\0' * 200)
        with tempfile.TemporaryDirectory() as folder:
            client = Client()
            dest = Path(folder) / '日本語.mp3'
            generate('こんにちは。', resolve_voice('narrator'), dest, client=client)
            self.assertTrue(dest.read_bytes().startswith(b'ID3'))
            self.assertEqual(client.received[0], 'こんにちは。')
            self.assertEqual(client.received[1]['lang'], 'ja-JP')

    def test_failure_keeps_existing_audio_and_cleans_partial_download(self):
        class Client:
            def synthesize(self, text, path, **options):
                Path(path).write_bytes(b'partial')
                raise RuntimeError('API refused')
        with tempfile.TemporaryDirectory() as folder:
            dest = Path(folder) / 'saved.mp3'
            dest.write_bytes(b'original')
            with self.assertRaises(RuntimeError):
                generate('test', resolve_voice('narrator'), dest, force=True, client=Client())
            self.assertEqual(dest.read_bytes(), b'original')
            self.assertEqual(list(Path(folder).iterdir()), [dest])

    def test_empty_text_or_bad_rate_or_existing_file_never_calls_api(self):
        class Client:
            def synthesize(self, *args, **kwargs):
                raise AssertionError('Validation must happen before network access')
        with tempfile.TemporaryDirectory() as folder:
            dest = Path(folder) / 'saved.mp3'
            voice = resolve_voice('narrator')
            with self.assertRaises(ValueError):
                generate(' ', voice, dest, client=Client())
            with self.assertRaises(ValueError):
                generate('test', voice, dest, rate=float('nan'), client=Client())
            dest.write_bytes(b'original')
            with self.assertRaises(FileExistsError):
                generate('test', voice, dest, client=Client())


if __name__ == '__main__':
    unittest.main()
