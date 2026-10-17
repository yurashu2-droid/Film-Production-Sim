"""Play the instrument's own GUI keyboard through an output-only device."""
from contextlib import contextmanager
import threading


def open_output():
    from pedalboard.io import AudioStream
    device = AudioStream.default_output_device_name
    if not device:
        raise ValueError('No audio output device. Connect speakers/headphones and reopen studio.')
    return AudioStream(output_device_name=device, buffer_size=1024,
                       num_output_channels=2)


@contextmanager
def preview_audio(plugin):
    stop = threading.Event()
    errors = []
    with open_output() as stream:
        rate = stream.sample_rate
        options = dict(duration=1024 / rate, sample_rate=rate,
                       num_channels=2, buffer_size=1024, reset=False)
        # Prepare on the main thread before opening the editor. reset=True can
        # recreate the native plugin and invalidate the visible editor.
        plugin([], **options)

        def play():
            try:
                while not stop.is_set():
                    # The GUI queues its own note events inside UVI. Processing
                    # empty MIDI blocks lets those events produce live audio.
                    stream.write(plugin([], **options), rate)
            except Exception as error:
                errors.append(error)
                print(f'PREVIEW STOPPED: {error}', flush=True)

        worker = threading.Thread(target=play, name='uvi-preview', daemon=True)
        worker.start()
        try:
            yield
        finally:
            stop.set()
            worker.join()  # No processing may overlap preset_data access.
            # Stop held notes before saving or reopening; preserve the preset.
            plugin([([0xB0 + channel, 120, 0], 0) for channel in range(16)], **options)
    if errors:
        print('Audio preview failed. Check the Windows output device and reopen studio.', flush=True)
