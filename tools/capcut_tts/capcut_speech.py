"""Generate speech with the pinned, unofficial CapCut TTS Python client."""
import argparse
import json
import math
import os
from pathlib import Path
import sys
import tempfile

DEPS = Path.home() / '.cache/codex-audio/capcut-deps'
if DEPS.is_dir():
    sys.path.insert(0, str(DEPS))


def voice_catalog():
    from capcut_tts.voices import all_voices
    return all_voices()


def resolve_voice(name):
    matches = [v for v in voice_catalog()
               if name in (v['voice_type'], v['display_name'])]
    if len(matches) != 1:
        raise ValueError('Voice is unknown or ambiguous. Run voices and use its exact ID.')
    return matches[0]


def make_client():
    from capcut_tts import CapCutTTS
    from capcut_tts.device import make_device
    folder = Path(os.environ['LOCALAPPDATA']) / 'CapCut-Code-TTS'
    folder.mkdir(parents=True, exist_ok=True)
    profile = folder / 'device.json'
    if not profile.exists():
        device = make_device()
        device.update(region='JP', loc='JP', lan='ja-JP')
        profile.write_text(json.dumps(device), encoding='utf-8')
    # One stable identity; no account passwords, browser cookies or retry loop.
    return CapCutTTS(device=str(profile), timeout=30, poll_timeout=90, max_attempts=1)


def generate(text, voice, output, rate=1.0, force=False, client=None):
    if not text.strip():
        raise ValueError('Text must not be empty.')
    if not math.isfinite(rate) or not .5 <= rate <= 2:
        raise ValueError('Rate must be between 0.5 and 2.0 (normal: 1.0).')
    output = Path(output)
    if output.suffix.lower() != '.mp3':
        raise ValueError('Use an .mp3 output filename.')
    if output.exists() and not force:
        raise FileExistsError('Output exists. Choose another filename or use --force.')
    output.parent.mkdir(parents=True, exist_ok=True)
    if client is None:
        client = make_client()
    with tempfile.NamedTemporaryFile(dir=output.parent, suffix='.mp3', delete=False) as f:
        temporary = Path(f.name)
    try:
        client.synthesize(text, str(temporary), voice=voice['voice_type'],
                          resource_id=voice['resource_id'], rate=rate,
                          lang=voice['lang'])
        with temporary.open('rb') as f:
            header = f.read(3)
        if temporary.stat().st_size < 100 or not (
                header == b'ID3' or (len(header) >= 2 and header[0] == 255 and header[1] & 224 == 224)):
            raise ValueError('CapCut did not return an MP3 file.')
        temporary.replace(output)
    finally:
        temporary.unlink(missing_ok=True)
    return output.resolve()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    voices = sub.add_parser('voices', help='List catalog voices; Japanese by default (offline).')
    voices.add_argument('--all', action='store_true', help='Include all languages.')
    speak = sub.add_parser('speak', help='Send text to CapCut and save generated speech as MP3.')
    source = speak.add_mutually_exclusive_group(required=True)
    source.add_argument('--text')
    source.add_argument('--text-file', type=Path, help='UTF-8 text file (BOM accepted).')
    speak.add_argument('--voice', default='ICL_ja_female_narrator', help='Exact catalog name or voice ID.')
    speak.add_argument('--output', '-o', type=Path, required=True)
    speak.add_argument('--rate', type=float, default=1)
    speak.add_argument('--force', action='store_true', help='Replace an existing output only after successful generation.')
    args = parser.parse_args(argv)
    if args.command == 'voices':
        for voice in voice_catalog():
            if args.all or voice['lang'] == 'ja-JP':
                print(f'{voice["display_name"]}\t{voice["voice_type"]}\t{voice["lang"]}')
        return
    voice = resolve_voice(args.voice)
    text = args.text_file.read_text(encoding='utf-8-sig') if args.text_file else args.text
    print(f'Generating with {voice["display_name"]}...', flush=True)
    output = generate(text, voice, args.output, args.rate, args.force)
    print(f'SAVED {output} ({output.stat().st_size} bytes)', flush=True)


if __name__ == '__main__':
    try:
        main()
    except ImportError:
        print('Dependencies missing. Run tools/capcut_tts/setup.ps1 first.', file=sys.stderr)
        sys.exit(1)
    except (ValueError, OSError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        # Upstream exceptions can contain complete responses/URLs. Do not print
        # server tokens or installation identifiers in normal CLI output.
        status = getattr(error, 'status_code', None)
        print(f'CapCut generation failed: {type(error).__name__}'
              + (f' (HTTP {status})' if status else '')
              + '. Check service availability and voice access; no automatic retry was made.', file=sys.stderr)
        sys.exit(1)
