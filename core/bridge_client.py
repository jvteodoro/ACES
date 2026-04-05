from __future__ import annotations

import json
import logging
import socket
from typing import Any, Iterator, Optional

from .models import RawSPITransaction


class BridgeProtocolError(RuntimeError):
    pass


class WindowsBridgeClient:
    def __init__(
        self,
        *,
        host: str,
        port: int,
        timeout_s: float = 10.0,
        logger: Optional[logging.Logger] = None,
    ) -> None:
        self.host = host
        self.port = int(port)
        self.timeout_s = timeout_s
        self.logger = logger or logging.getLogger(__name__)
        self._socket: socket.socket | None = None
        self._reader = None
        self._writer = None
        self.hello: dict[str, Any] | None = None

    def __enter__(self) -> "WindowsBridgeClient":
        self.connect()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def connect(self) -> None:
        if self._socket is not None:
            return
        self._socket = socket.create_connection((self.host, self.port), timeout=self.timeout_s)
        self._reader = self._socket.makefile("r", encoding="utf-8", newline="\n")
        self._writer = self._socket.makefile("w", encoding="utf-8", newline="\n")
        self.hello = self.read_message()
        if self.hello.get("type") != "hello":
            raise BridgeProtocolError(f"Expected hello message, got {self.hello!r}")

    def close(self) -> None:
        if self._writer is not None:
            self._writer.close()
            self._writer = None
        if self._reader is not None:
            self._reader.close()
            self._reader = None
        if self._socket is not None:
            self._socket.close()
            self._socket = None

    def send_command(self, command: dict[str, Any]) -> None:
        if self._writer is None:
            raise BridgeProtocolError("Bridge client is not connected.")
        self._writer.write(json.dumps(command, sort_keys=True) + "\n")
        self._writer.flush()

    def read_message(self) -> dict[str, Any]:
        if self._reader is None:
            raise BridgeProtocolError("Bridge client is not connected.")
        line = self._reader.readline()
        if not line:
            raise BridgeProtocolError("Bridge server closed the connection.")
        return json.loads(line)

    def iter_messages(self) -> Iterator[dict[str, Any]]:
        while True:
            message = self.read_message()
            yield message
            if message.get("type") == "end":
                return

    def iter_transactions(self) -> Iterator[RawSPITransaction]:
        for message in self.iter_messages():
            message_type = message.get("type")
            if message_type == "spi_transaction":
                yield RawSPITransaction.from_message(message)
            elif message_type == "telemetry":
                self.logger.info("Bridge telemetry: %s", message.get("counters"))
            elif message_type == "ack":
                self.logger.info("Bridge ack: %s", message)
            elif message_type == "error":
                raise BridgeProtocolError(message.get("error", "Unknown bridge error."))

    def start_capture(self, capture_config: dict[str, Any], *, max_transactions: int | None = None) -> None:
        command = {
            "command": "start_capture",
            "capture_config": capture_config,
        }
        if max_transactions is not None:
            command["max_transactions"] = int(max_transactions)
        self.send_command(command)

    def start_pattern_test(
        self,
        *,
        frames: list[list[int]],
        pattern_config: dict[str, Any] | None = None,
        capture_config: dict[str, Any] | None = None,
        max_transactions: int | None = None,
        use_hardware: bool = True,
    ) -> None:
        command = {
            "command": "start_pattern_test",
            "frames": frames,
            "pattern_config": pattern_config or {},
            "capture_config": capture_config or {},
            "use_hardware": bool(use_hardware),
        }
        if max_transactions is not None:
            command["max_transactions"] = int(max_transactions)
        self.send_command(command)
