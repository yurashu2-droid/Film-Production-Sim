"""Shared voice IDs; private plugin states live outside every Git worktree."""
import json
import os
from pathlib import Path
import hashlib
import re
import struct
import unicodedata
import xml.etree.ElementTree as ET
import zlib

CATALOG = Path(__file__).with_name('voices.json')


def voice_directory():
    override = os.environ.get('UVI_VOICE_DIR')
    return Path(override) if override else Path(os.environ['LOCALAPPDATA']) / 'UVI-Code-Voices'


def get_voice(voice_id):
    for voice in catalog_voices():
        if voice['id'] == voice_id:
            return voice
    raise ValueError(f'Unknown voice ID: {voice_id}. Run voices to list available IDs.')


def voice_state(voice_id, require=True):
    voice = get_voice(voice_id)
    state = voice_directory() / (voice['id'] + '.vstpreset')
    if require and not state.is_file():
        raise ValueError(f'Voice {voice_id} is not registered on this PC. Run register --voices {voice_id}.')
    return state


def list_voices(tag=None):
    voices = catalog_voices()
    return [dict(voice, registered=voice_state(voice['id'], require=False).is_file())
            for voice in voices if tag is None or tag in voice['tags']]


def catalog_voices():
    merged = {v['id']: v for v in json.loads(CATALOG.read_text(encoding='utf-8'))}
    local = voice_directory() / 'voices.local.json'
    if local.is_file():
        merged.update({v['id']: v for v in json.loads(local.read_text(encoding='utf-8'))})
    return list(merged.values())


def atomic_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')
    temporary.replace(path)


def preset_metadata(data):
    """Read only the program label/path from UVI's own saved VST3 state.

    The component is UVI4/version/size followed by zlib XML in Player 5.0.0.
    Audio samples are not read, unpacked, modified, or embedded by this tool.
    """
    try:
        if data[:4] != b'VST3':
            raise ValueError('Not a VST3 preset.')
        index = struct.unpack_from('<Q', data, 40)[0]
        if data[index:index + 4] != b'List':
            raise ValueError('Invalid VST3 chunk index.')
        count = struct.unpack_from('<I', data, index + 4)[0]
        component = None
        for i in range(count):
            entry = index + 8 + i * 20
            if data[entry:entry + 4] == b'Comp':
                offset, size = struct.unpack_from('<QQ', data, entry + 4)
                component = data[offset:offset + size]
                break
        if component is None or component[:4] != b'UVI4':
            raise ValueError('This preset format is not supported by automatic naming.')
        version, expected = struct.unpack_from('<II', component, 4)
        if version != 1:
            raise ValueError('This UVI state version is not supported by automatic naming.')
        xml = zlib.decompress(component[12:])
        if len(xml) != expected:
            raise ValueError('Incomplete UVI state.')
        programs = [p for p in ET.fromstring(xml).iter('Program') if p.get('ProgramPath')]
        if len(programs) != 1:
            raise ValueError('Choose one instrument in Single mode before registering.')
        program = programs[0]
        name = (program.get('DisplayName') or '').strip()
        source = program.get('ProgramPath', '')
        match = re.match(r'^\$(.+?)\.ufs/', source)
        if not name or not match:
            raise ValueError('No loaded UVI Soundware preset was found. Wait until loading finishes.')
        return dict(preset=name, bank=match.group(1), program_path=source)
    except (struct.error, zlib.error, ET.ParseError, IndexError) as error:
        raise ValueError('Could not read the current UVI preset; no voice was registered.') from error


def save_current_voice(data):
    metadata = preset_metadata(data)
    voices = catalog_voices()
    voice = next((v.copy() for v in voices
                  if v['preset'] == metadata['preset'] and v['bank'] == metadata['bank']), None)
    if voice is None:
        slug = unicodedata.normalize('NFKD', metadata['preset']).encode('ascii', 'ignore').decode()
        slug = re.sub(r'[^a-z0-9]+', '_', slug.lower()).strip('_')[:64]
        digest = hashlib.sha256(metadata['program_path'].encode()).hexdigest()[:8]
        voice_id = slug or 'voice_' + digest
        if any(v['id'] == voice_id for v in voices):
            voice_id += '_' + digest
        parts = metadata['program_path'].split('/')
        category = parts[2] if len(parts) > 2 else 'soundware'
        voice = dict(id=voice_id, preset=metadata['preset'], bank=metadata['bank'],
                     tags=[re.sub(r'^\d+\s*', '', category).lower()], note=60)
    voice['program_path'] = metadata['program_path']
    folder = voice_directory()
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / (voice['id'] + '.vstpreset')
    temporary = target.with_suffix('.tmp')
    temporary.write_bytes(data)
    temporary.replace(target)
    local_path = folder / 'voices.local.json'
    local = json.loads(local_path.read_text(encoding='utf-8')) if local_path.is_file() else []
    local = [v for v in local if v['id'] != voice['id']] + [voice]
    atomic_json(local_path, local)
    return voice
