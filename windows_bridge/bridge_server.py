from __future__ import annotations

import argparse
import json
import logging
import socketserver
import threading
import time
from dataclasses import dataclass, field
from typing import Any, Iterable, Iterator, Optional, Sequence

from core.models import RawSPITransaction

from .waveforms_spi_capture import CaptureConfig, WaveFormsSPICapture
from .waveforms_spi_pattern_test import PatternConfig, WaveFormsPatternLoopbackHarness


@dataclass
class BridgeTelemetry:
    transactions_sent: int = 0
    words_sent: int = 0
    errors: int = 0
    started_at_ns: int = field(default_factory=time.time_ns)

    def note_transaction(self, transaction: RawSPITransaction) -> None:
        self.transactions_sent += 1
        self.words_sent += len(transaction.words)

    def note_error(self) -> None:
        self.errors += 1

    def snapshot(self) -> dict[str, int]:
        return {
            "transactions_sent": self.transactions_sent,
            "words_sent": self.words_sent,
            "errors": self.errors,
            "uptime_ns": max(0, time.time_ns() - self.started_at_ns),
        }


class WaveFormsBridgeBackend:
    def handle_command(self, command: dict[str, Any]) -> Iterable[RawSPITransaction]:
        command_name = command.get("command")
        if command_name == "start_capture":
            capture_config = CaptureConfig.from_mapping(command.get("capture_config"))
            max_transactions = command.get("max_transactions")
            capturer = WaveFormsSPICapture(capture_config)
            return capturer.capture_transactions(
                max_transactions=int(max_transactions) if max_transactions is not None else None
            )

        if command_name == "start_pattern_test":
            frames = [
                tuple(int(word) & 0xFFFFFFFF for word in frame)
                for frame in command.get("frames", [])
            ]
            pattern_config = PatternConfig.from_mapping(command.get("pattern_config"))
            capture_config = CaptureConfig.from_mapping(command.get("capture_config"))
            capture_config = CaptureConfig(
                cs_pin=capture_config.cs_pin,
                clk_pin=capture_config.clk_pin,
                data_pin=capture_config.data_pin,
                sample_rate_hz=capture_config.sample_rate_hz,
                buffer_size=capture_config.buffer_size,
                bits_per_word=capture_config.bits_per_word,
                cpol=capture_config.cpol,
                cpha=capture_config.cpha,
                byteorder=capture_config.byteorder,
                device_index=capture_config.device_index,
                chunk_timeout_s=capture_config.chunk_timeout_s,
                source="test",
                library_path=capture_config.library_path,
            )
            harness = WaveFormsPatternLoopbackHarness(pattern_config, capture_config)
            transactions = harness.run_loopback(
                frames,
                source="test",
                use_hardware=bool(command.get("use_hardware", True)),
            )
            max_transactions = command.get("max_transactions")
            if max_transactions is None:
                return transactions
            return transactions[: int(max_transactions)]

        raise ValueError(f"Unsupported command: {command_name!r}")


class _BridgeRequestHandler(socketserver.StreamRequestHandler):
    def handle(self) -> None:
        server: "BridgeServer" = self.server  # type: ignore[assignment]
        server.logger.info("Bridge client connected from %s", self.client_address)
        self._write_message(
            {
                "type": "hello",
                "protocol": "aces.spi.bridge",
                "version": 1,
                "server_time_ns": time.time_ns(),
            }
        )

        line = self.rfile.readline()
        if not line:
            return

        try:
            command = json.loads(line.decode("utf-8"))
            iterator = iter(server.backend.handle_command(command))
            self._write_message(
                {
                    "type": "ack",
                    "command": command.get("command"),
                    "server_time_ns": time.time_ns(),
                }
            )
            for transaction in iterator:
                server.telemetry.note_transaction(transaction)
                self._write_message(transaction.to_message())
            self._write_message(
                {
                    "type": "telemetry",
                    "component": "bridge_server",
                    "counters": server.telemetry.snapshot(),
                }
            )
            self._write_message({"type": "end", "reason": "completed"})
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            server.logger.info("Bridge client disconnected while streaming.")
        except Exception as exc:
            server.telemetry.note_error()
            server.logger.exception("Bridge command failed: %s", exc)
            try:
                self._write_message({"type": "error", "error": str(exc), "recoverable": False})
                self._write_message({"type": "end", "reason": "error"})
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                server.logger.info("Bridge client disconnected before error payload was delivered.")

    def _write_message(self, payload: dict[str, Any]) -> None:
        self.wfile.write((json.dumps(payload, sort_keys=True) + "\n").encode("utf-8"))
        self.wfile.flush()


class BridgeServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True

    def __init__(
        self,
        server_address: tuple[str, int],
        *,
        backend: WaveFormsBridgeBackend | None = None,
        logger: Optional[logging.Logger] = None,
    ) -> None:
        self.logger = logger or logging.getLogger(__name__)
        self.backend = backend or WaveFormsBridgeBackend()
        self.telemetry = BridgeTelemetry()
        super().__init__(server_address, _BridgeRequestHandler)

    def serve_in_thread(self, *, daemon: bool = True) -> threading.Thread:
        thread = threading.Thread(target=self.serve_forever, daemon=daemon)
        thread.start()
        return thread


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="WaveForms SPI bridge server for Windows <-> WSL.")
    parser.add_argument("--host", default="0.0.0.0", help="TCP listen host.")
    parser.add_argument("--port", type=int, default=9100, help="TCP listen port.")
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=("DEBUG", "INFO", "WARNING", "ERROR"),
        help="Logging verbosity.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)
    logging.basicConfig(
        level=getattr(logging, str(args.log_level).upper()),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    server = BridgeServer((args.host, args.port))
    server.logger.info("Starting bridge server on %s:%d", args.host, args.port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.logger.info("Stopping bridge server.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
