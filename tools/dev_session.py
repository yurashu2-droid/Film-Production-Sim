#!/usr/bin/env python3
"""Persistent, editor-free Godot playtesting. Python standard library only."""
import argparse
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def native_windows(pid):
    """Godot does not allow Window.hide() on its main window; use the host API."""
    if os.name != "nt":
        return []
    import ctypes
    from ctypes import wintypes
    api = ctypes.windll.user32
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    api.EnumWindows.argtypes = [callback_type, wintypes.LPARAM]
    api.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    api.IsWindowVisible.argtypes = [wintypes.HWND]
    api.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
    handles = []
    def collect(handle, _):
        owner = wintypes.DWORD()
        api.GetWindowThreadProcessId(handle, ctypes.byref(owner))
        if owner.value == pid:
            handles.append(handle)
        return True
    api.EnumWindows(callback_type(collect), 0)
    return handles


class SessionError(RuntimeError):
    pass


class SessionUnavailable(SessionError):
    pass


class Session:
    def __init__(self, project=ROOT / "godot", name="default", engine=None):
        if not name or any(not (c.isalnum() or c in "_-") for c in name):
            raise SessionError("Session name must contain letters, digits, _ or -")
        self.project = Path(project).resolve()
        self.engine = Path(engine) if engine else ROOT / "tools/godot/Godot_v4.7.2-stable_win64.exe"
        self.folder = self.project / ".godot/dev_session"
        self.state = self.folder / (name + ".json")
        self.log = self.folder / (name + ".log")
        self._worker = None

    def request(self, payload, timeout=70):
        connected = False
        try:
            config = json.loads(self.state.read_text(encoding="utf-8"))
            data = dict(payload, token=config["token"])
            with socket.create_connection(("127.0.0.1", config["port"]), timeout=timeout) as connection:
                connected = True
                connection.sendall((json.dumps(data, ensure_ascii=False) + "\n").encode("utf-8"))
                with connection.makefile("rb") as stream:
                    line = stream.readline(16 * 1024 * 1024)
            if not line:
                raise SessionError("Session closed the connection; inspect " + str(self.log))
            response = json.loads(line)
            if not response.get("ok"):
                raise SessionError(response.get("error", "Unknown session error"))
            result = response["result"]
            if payload.get("op") == "status":
                if result["mode"] == "headless":
                    result["window_visible"] = False
                elif os.name == "nt":
                    import ctypes
                    result["window_visible"] = any(ctypes.windll.user32.IsWindowVisible(h) for h in native_windows(result["pid"]))
            return result
        except (FileNotFoundError, ConnectionRefusedError) as error:
            raise SessionUnavailable("Session is unavailable. Run start; log: " + str(self.log)) from error
        except TimeoutError as error:
            if not connected:
                raise SessionUnavailable("Cannot connect to session; log: " + str(self.log)) from error
            raise SessionError("Session is busy or timed out; existing worker retained. Log: " + str(self.log)) from error
        except (OSError, ValueError, KeyError) as error:
            raise SessionError("Session is unavailable. Run start; log: " + str(self.log)) from error

    def start(self, mode="headless"):
        if mode not in ("headless", "render"):
            raise SessionError("Mode must be headless or render")
        if mode == "render" and os.name != "nt":
            raise SessionError("Hidden rendering currently supports Windows; use headless on this host")
        try:
            status = self.request({"op": "status"}, timeout=1)
        except SessionUnavailable:
            status = None
        if status is not None:
            if Path(status["project"]).resolve() != self.project:
                raise SessionError("Port belongs to a different project")
            if status["mode"] != mode:
                raise SessionError("Existing session has a different mode; stop it or choose another --name")
            return status
        if not self.engine.exists() or not (self.project / "project.godot").exists():
            raise SessionError("Godot engine or project.godot was not found")
        self.folder.mkdir(parents=True, exist_ok=True)
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        config = {"port": port, "token": secrets.token_hex(24)}
        self.state.write_text(json.dumps(config), encoding="utf-8")
        command = [str(self.engine), "--path", str(self.project), "--audio-driver", "Dummy", "--script", "res://addons/dev_session/runner.gd", "--log-file", str(self.log)]
        if mode == "headless":
            command += ["--headless"]
        else:
            # Start outside the desktop; the runner hides and unfocuses its window.
            command += ["--position", "-32000,-32000"]
        command += ["--", "--dev-port=" + str(port), "--dev-token=" + config["token"]]
        options = {"stdin": subprocess.DEVNULL, "stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
        if os.name == "nt":
            options["creationflags"] = subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP
        else:
            options["start_new_session"] = True
        process = subprocess.Popen(command, **options)
        self._worker = process
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise SessionError("Godot exited at startup; inspect " + str(self.log))
            try:
                status = self.request({"op": "status"}, timeout=0.5)
                if mode == "render":
                    import ctypes
                    for handle in native_windows(status["pid"]):
                        ctypes.windll.user32.ShowWindow(handle, 0)
                    status = self.request({"op": "status"})
                config["pid"] = status["pid"]
                self.state.write_text(json.dumps(config), encoding="utf-8")
                return status
            except SessionError:
                time.sleep(0.1)
        process.terminate()  # Only the child this start call created.
        raise SessionError("Startup timed out; inspect " + str(self.log))

    def stop(self):
        try:
            self.request({"op": "shutdown"}, timeout=2)
        except SessionError:
            return {"stopped": False, "message": "No reachable session"}
        self.state.unlink(missing_ok=True)
        if self._worker is not None:
            self._worker.wait(timeout=5)
        return {"stopped": True}

    def watch(self):
        self.request({"op": "status"}, timeout=2)
        def scripts():
            return {p: p.stat().st_mtime_ns for p in self.project.rglob("*.gd") if ".godot" not in p.parts and "dev_session" not in p.parts}
        previous = scripts()
        print("Watching scripts. Ctrl+C ends watching and leaves Godot running.", flush=True)
        while True:
            time.sleep(0.5)
            current = scripts()
            for path, modified in current.items():
                if previous.get(path) != modified:
                    resource = "res://" + path.relative_to(self.project).as_posix()
                    try:
                        print(json.dumps(self.request({"op": "reload", "path": resource}), ensure_ascii=False), flush=True)
                    except SessionError as error:
                        print(str(error), file=sys.stderr, flush=True)
            previous = current


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--name", default="default")
    parser.add_argument("--engine", type=Path)
    commands = parser.add_subparsers(dest="command", required=True)
    start = commands.add_parser("start")
    start.add_argument("--mode", choices=["headless", "render"], default="headless")
    start.add_argument("--scene")
    for command in ["status", "stop", "watch"]:
        commands.add_parser(command)
    request = commands.add_parser("request", help="Send an operation as JSON, or '-' to read JSON from stdin")
    request.add_argument("json")
    load = commands.add_parser("load")
    load.add_argument("scene")
    reload = commands.add_parser("reload")
    reload.add_argument("path")
    step = commands.add_parser("step")
    step.add_argument("frames", type=int, nargs="?", default=1)
    capture = commands.add_parser("capture")
    capture.add_argument("path", type=Path)
    args = parser.parse_args()
    try:
        session = Session(args.project, args.name, args.engine)
        if args.command == "start":
            result = session.start(args.mode)
            if args.scene:
                session.request({"op": "load", "scene": args.scene})
                result = session.request({"op": "status"})
        elif args.command == "stop":
            result = session.stop()
        elif args.command == "watch":
            session.watch()
            return
        elif args.command == "request":
            payload = json.load(sys.stdin) if args.json == "-" else json.loads(args.json)
            result = session.request(payload)
        elif args.command == "capture":
            args.path.parent.mkdir(parents=True, exist_ok=True)
            result = session.request({"op": "capture", "path": str(args.path.resolve())})
        elif args.command in ("load", "reload", "step"):
            field = {"load": "scene", "reload": "path", "step": "frames"}[args.command]
            result = session.request({"op": args.command, field: getattr(args, field)})
        else:
            result = session.request({"op": "status"})
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except KeyboardInterrupt:
        pass
    except (SessionError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    raise SystemExit(main())
