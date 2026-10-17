"""File-based save requests; editor and state access stay on the main thread."""
import json
import os
import queue
import threading
import time
import uuid

from voice_registry import atomic_json, save_current_voice, voice_directory
from voice_preview import preview_audio


def live_session():
    try:
        session = json.loads((voice_directory() / 'studio.json').read_text(encoding='utf-8'))
        if time.time() - session['heartbeat'] < 5:
            return session
    except (OSError, ValueError, KeyError):
        pass
    return None


def request_capture(timeout=30):
    session = live_session()
    if session is None:
        raise ValueError('Registration editor is not open. Run studio / 01_open_voice_editor.cmd first.')
    folder = voice_directory() / 'sessions' / session['id']
    request_id = uuid.uuid4().hex
    request = folder / 'capture.request.json'
    result = folder / (request_id + '.json')
    try:
        with request.open('x', encoding='utf-8') as f:
            json.dump(dict(id=request_id), f)
    except FileExistsError as error:
        raise ValueError('A registration is already being processed. Wait for it to finish.') from error
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if result.is_file():
            answer = json.loads(result.read_text(encoding='utf-8'))
            if not answer['ok']:
                raise ValueError(answer['error'])
            return answer
        time.sleep(.1)
    raise ValueError('Registration timed out. Check the registration editor and its console before retrying.')


def run_studio(plugin):
    if live_session() is not None:
        raise ValueError('A registration editor is already open. Use capture to save its current sound.')
    session_id = uuid.uuid4().hex
    folder = voice_directory() / 'sessions' / session_id
    folder.mkdir(parents=True, exist_ok=True)
    session_path = voice_directory() / 'studio.json'
    close_editor = threading.Event()
    stop = threading.Event()
    busy = threading.Event()
    requests = queue.Queue()

    def watch():
        next_heartbeat = 0
        while not stop.is_set():
            if time.monotonic() >= next_heartbeat:
                atomic_json(session_path, dict(id=session_id, pid=os.getpid(), heartbeat=time.time()))
                next_heartbeat = time.monotonic() + 1
            request = folder / 'capture.request.json'
            if request.is_file() and not busy.is_set():
                try:
                    payload = json.loads(request.read_text(encoding='utf-8'))
                    request_id = payload['id']
                    busy.set()
                    requests.put(request_id)
                    request.unlink()
                    close_editor.set()
                except (ValueError, KeyError):
                    pass  # The client may still be finishing its small JSON write.
            stop.wait(.05)

    atomic_json(session_path, dict(id=session_id, pid=os.getpid(), heartbeat=time.time()))
    watcher = threading.Thread(target=watch, daemon=True)
    watcher.start()
    print('Choose a sound and wait for loading; run 02_register_current_voice.cmd to save it.', flush=True)
    print('Click the UVI on-screen keyboard to audition through your default audio output.', flush=True)
    try:
        while True:
            with preview_audio(plugin):
                plugin.show_editor(close_editor)
            try:
                request_id = requests.get_nowait()
            except queue.Empty:
                break  # Closing the editor by hand ends this registration session.
            try:
                voice = save_current_voice(plugin.preset_data)
                answer = dict(ok=True, voice=voice)
                print(f'SAVED {voice["id"]}: {voice["preset"]}', flush=True)
            except (ValueError, OSError) as error:
                answer = dict(ok=False, error=str(error))
                print(f'NOT SAVED: {error}', flush=True)
            atomic_json(folder / (request_id + '.json'), answer)
            close_editor.clear()
            busy.clear()
    finally:
        stop.set()
        watcher.join(2)
        atomic_json(session_path, dict(id=session_id, pid=os.getpid(), heartbeat=0))
