"""Run the Godot client against a local disposable WebSocket server."""

import asyncio
import json
import os
from pathlib import Path
import socket
import subprocess
import sys

from websockets.asyncio.server import serve


ROOT = Path(__file__).resolve().parents[1]


async def main() -> int:
    godot = os.environ.get("GODOT_BIN", "godot")
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]

    async def handler(websocket):
        await websocket.send(json.dumps({
            "event": "START_SESSION",
            "session_id": "test-socket-1",
            "activities": [
                {"id": "juego", "type": "game", "title": "Juego"},
                {"id": "movimiento", "type": "movement", "title": "Movimiento"},
            ],
        }))
        message = json.loads(await asyncio.wait_for(websocket.recv(), timeout=8))
        if message.get("event") != "CHILD_INPUT" or message.get("action") != "activity_selected":
            raise AssertionError(f"Unexpected event: {message}")
        await websocket.send(json.dumps({"event": "EVENT_ACK", "event_id": message["event_id"]}))
        await asyncio.sleep(0.15)
        await websocket.send(json.dumps({"event": "END_SESSION"}))
        await asyncio.sleep(0.15)

    async with serve(handler, "127.0.0.1", port):
        environment = os.environ.copy()
        environment["MAKIPURA_TEST_WS_URL"] = f"ws://127.0.0.1:{port}"
        process = await asyncio.create_subprocess_exec(
            godot,
            "--headless",
            "--path",
            str(ROOT),
            "--script",
            "res://tests/socket_smoke.gd",
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        output, _ = await asyncio.wait_for(process.communicate(), timeout=15)
        print(output.decode(errors="replace"))
        return process.returncode


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
