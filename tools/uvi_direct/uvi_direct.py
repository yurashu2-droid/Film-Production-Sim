"""Render the locally licensed UVI Player VST3 from timed MIDI notes."""
import argparse
import json
import math
import os
from pathlib import Path
import sys
import time
import wave
from voice_registry import get_voice, list_voices, voice_state
from voice_studio import live_session, request_capture, run_studio

# Optional local dependency install, separate from the game's environment.
LOCAL_DEPS = Path.home() / '.cache' / 'codex-audio' / 'python-deps'
if LOCAL_DEPS.is_dir():
    sys.path.insert(0, str(LOCAL_DEPS))

DEFAULT_PLUGIN = (Path(os.environ.get('ProgramFiles', r'C:\Program Files')) /
                  'Common Files/VST3/UVI Player.vst3/Contents/x86_64-win/UVI Player.vst3')


def load_score(path):
    """Read note events; reject invalid values before entering the native plugin."""
    events = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    if not isinstance(events, list) or not events:
        raise ValueError('Score must be a nonempty JSON list of note events.')
    messages = []
    end = 0.0
    for item in events:
        if not isinstance(item, dict):
            raise ValueError('Each note event must be an object.')
        note = item['note']
        velocity = item.get('velocity', 100)
        start = item.get('start', 0.0)
        duration = item['duration']
        channel = item.get('channel', 1)
        for name, value, low, high in [('note', note, 0, 127),
                                       ('velocity', velocity, 1, 127),
                                       ('channel', channel, 1, 16)]:
            if type(value) is not int or not low <= value <= high:
                raise ValueError(f'{name} must be an integer in {low}..{high}.')
        for name, value in [('start', start), ('duration', duration)]:
            if type(value) not in (int, float) or not math.isfinite(value):
                raise ValueError(f'{name} must be a finite number of seconds.')
        if start < 0 or duration <= 0:
            raise ValueError('start must be >= 0 and duration must be > 0.')
        finish = start + duration
        messages.append(([0x90 + channel - 1, note, velocity], float(start)))
        messages.append(([0x80 + channel - 1, note, 0], float(finish)))
        end = max(end, finish)
    # Note-offs precede note-ons at the same timestamp, permitting retriggers.
    messages.sort(key=lambda event: (event[1], event[0][0] & 0xF0 == 0x90))
    return messages, end


def load_instrument(path):
    from pedalboard import load_plugin
    path = Path(path)
    if not path.is_file():
        raise ValueError(f'VST3 binary does not exist: {path}')
    plugin = load_plugin(str(path))
    if not plugin.is_instrument:
        raise ValueError('The selected plugin is not a MIDI instrument.')
    return plugin


def render(plugin, messages, duration, rate, peak_db, output):
    import numpy as np
    started = time.perf_counter()
    audio = plugin(messages, duration=duration, sample_rate=rate,
                   num_channels=2, buffer_size=512)
    render_seconds = time.perf_counter() - started
    if audio.ndim != 2 or audio.shape[0] != 2 or not np.isfinite(audio).all():
        raise ValueError('Plugin returned invalid stereo audio.')
    peak = float(np.max(np.abs(audio)))
    if peak < 1e-7:
        raise ValueError('Plugin returned silence. Use edit to select and save an instrument.')
    # Preserve the performance dynamics, setting only a common output peak.
    audio = audio.astype(np.float64) * (10 ** (peak_db / 20) / peak)
    fade = min(int(rate * 0.003), audio.shape[1] // 2)
    audio[:, :fade] *= np.linspace(0, 1, fade)
    audio[:, -fade:] *= np.linspace(1, 0, fade)
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(audio.T, -1, 1) * 32767).astype('<i2')
    with wave.open(str(output), 'wb') as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(pcm.tobytes())
    return dict(output=str(output.resolve()), frames=audio.shape[1], sample_rate=rate,
                seconds=audio.shape[1] / rate, source_peak=peak,
                peak_dbfs=float(20 * np.log10(np.max(np.abs(audio)))),
                rms_dbfs=float(20 * np.log10(np.sqrt(np.mean(audio ** 2)))),
                render_seconds=render_seconds)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plugin', type=Path, default=DEFAULT_PLUGIN)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('inspect', help='Check the plugin and list exposed automation controls.')
    sub.add_parser('studio', help='Open the voice-registration editor; save with the capture command.')
    sub.add_parser('capture', help='Save the current sound of the registration editor automatically.')
    voices = sub.add_parser('voices', help='List shared voice IDs without loading UVI.')
    voices.add_argument('--tag', help='Filter by a catalog tag such as impact, synth, or ui.')
    register = sub.add_parser('register', help='Save several voice states with one plugin session.')
    register.add_argument('--voices', nargs='+', required=True)
    edit = sub.add_parser('edit', help='Choose an instrument, close the editor to save its state.')
    edit.add_argument('--state', type=Path, required=True)
    output = sub.add_parser('render', help='Render notes directly to WAV with no editor or audio device.')
    source = output.add_mutually_exclusive_group(required=True)
    source.add_argument('--state', type=Path)
    source.add_argument('--voice', help='Shared voice ID from the voices catalog.')
    output.add_argument('--score', type=Path, required=True)
    output.add_argument('--output', type=Path, required=True)
    output.add_argument('--tail', type=float, default=0.8, help='Release tail in seconds.')
    output.add_argument('--rate', type=int, choices=[44100, 48000, 96000], default=48000)
    output.add_argument('--peak-db', type=float, default=-3)
    batch = sub.add_parser('batch', help='Reuse one loaded instrument for several scores.')
    source = batch.add_mutually_exclusive_group(required=True)
    source.add_argument('--state', type=Path)
    source.add_argument('--voice')
    batch.add_argument('--scores', type=Path, nargs='+', required=True)
    batch.add_argument('--output-dir', type=Path, required=True)
    batch.add_argument('--tail', type=float, default=0.8)
    batch.add_argument('--rate', type=int, choices=[44100, 48000, 96000], default=48000)
    batch.add_argument('--peak-db', type=float, default=-3)
    args = parser.parse_args(argv)
    if args.command == 'voices':
        print(json.dumps(list_voices(args.tag), ensure_ascii=True, indent=2))
        return
    if args.command == 'capture':
        print(json.dumps(request_capture(), ensure_ascii=True, indent=2))
        return
    if args.command == 'studio':
        if live_session() is not None:
            raise ValueError('A registration editor is already open. Use capture to save its current sound.')
        print('Loading UVI Player for voice registration...', flush=True)
    if args.command == 'register':
        for voice_id in args.voices:
            get_voice(voice_id)
    if args.command in ('render', 'batch'):
        if args.voice:
            args.state = voice_state(args.voice)
        scores = [args.score] if args.command == 'render' else args.scores
        if args.command == 'batch' and len({path.stem for path in scores}) != len(scores):
            raise ValueError('Batch scores must have distinct filenames to avoid output collisions.')
        jobs = [(score, *load_score(score)) for score in scores]
        if not math.isfinite(args.tail) or args.tail < 0:
            raise ValueError('tail must be finite and >= 0.')
        if not math.isfinite(args.peak_db) or not -60 <= args.peak_db <= 0:
            raise ValueError('peak-db must be between -60 and 0 dBFS.')
        if not args.state.is_file():
            raise ValueError(f'State is missing; run edit first: {args.state}')
    started = time.perf_counter()
    plugin = load_instrument(args.plugin)
    print(json.dumps(dict(plugin=plugin.name, loaded_seconds=time.perf_counter() - started)), flush=True)
    if args.command == 'studio':
        run_studio(plugin)
    elif args.command == 'inspect':
        print(json.dumps(dict(instrument=plugin.is_instrument,
                              parameters=list(plugin.parameters)), indent=2))
    elif args.command == 'register':
        for voice_id in args.voices:
            voice = get_voice(voice_id)
            state = voice_state(voice_id, require=False)
            if state.exists():
                plugin.load_preset(str(state))
            print(f'REGISTER {voice_id}: select {voice["bank"]} / {voice["preset"]}; close editor after loading.', flush=True)
            plugin.show_editor()
            state.parent.mkdir(parents=True, exist_ok=True)
            temporary = state.with_suffix('.tmp')
            temporary.write_bytes(plugin.preset_data)
            temporary.replace(state)
            print(json.dumps(dict(registered=voice_id, state=str(state), bytes=state.stat().st_size)), flush=True)
    elif args.command == 'edit':
        if args.state.exists():
            plugin.load_preset(str(args.state))
        print('Choose an instrument, wait for loading to finish, then close the plugin editor.', flush=True)
        plugin.show_editor()
        args.state.parent.mkdir(parents=True, exist_ok=True)
        args.state.write_bytes(plugin.preset_data)
        print(json.dumps(dict(saved_state=str(args.state.resolve()), bytes=args.state.stat().st_size)), flush=True)
    else:
        plugin.load_preset(str(args.state))
        for score, messages, end in jobs:
            target = args.output if args.command == 'render' else args.output_dir / (score.stem + '.wav')
            report = render(plugin, messages, end + args.tail, args.rate, args.peak_db, target)
            report['state'] = str(args.state.resolve())
            report['score'] = str(score.resolve())
            target.with_suffix('.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
            print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, ImportError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
