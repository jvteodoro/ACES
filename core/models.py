from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional


@dataclass(frozen=True)
class FFTBin:
    bin_id: int
    real: int
    imag: int
    flags_real: int = 0
    flags_imag: int = 0

    def to_dict(self) -> dict[str, int]:
        return {
            "bin_id": self.bin_id,
            "real": self.real,
            "imag": self.imag,
            "flags_real": self.flags_real,
            "flags_imag": self.flags_imag,
        }


@dataclass(frozen=True)
class FFTFrame:
    seq: int
    count_words: int
    flags: int
    exp: int
    bins: tuple[FFTBin, ...]
    timestamp_host_ns: int
    source: str
    raw_words: Optional[tuple[int, ...]] = None
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self, *, include_raw_words: bool = False) -> dict[str, Any]:
        payload = {
            "seq": self.seq,
            "count_words": self.count_words,
            "flags": self.flags,
            "exp": self.exp,
            "bins": [item.to_dict() for item in self.bins],
            "timestamp_host_ns": self.timestamp_host_ns,
            "source": self.source,
            "metadata": dict(self.metadata),
        }
        if include_raw_words and self.raw_words is not None:
            payload["raw_words"] = list(self.raw_words)
        return payload


@dataclass(frozen=True)
class RawSPITransaction:
    words: tuple[int, ...]
    timestamp_host_ns: int
    source: str
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_message(self) -> dict[str, Any]:
        return {
            "type": "spi_transaction",
            "timestamp_host_ns": self.timestamp_host_ns,
            "source": self.source,
            "words": list(self.words),
            "metadata": dict(self.metadata),
        }

    @classmethod
    def from_message(cls, message: dict[str, Any]) -> "RawSPITransaction":
        if message.get("type") != "spi_transaction":
            raise ValueError(f"Unexpected bridge message type: {message.get('type')!r}")
        return cls(
            words=tuple(int(word) & 0xFFFFFFFF for word in message.get("words", [])),
            timestamp_host_ns=int(message["timestamp_host_ns"]),
            source=str(message["source"]),
            metadata=dict(message.get("metadata", {})),
        )


@dataclass
class ParserTelemetry:
    frames_received: int = 0
    frames_parsed_ok: int = 0
    frames_invalid: int = 0
    header_errors: int = 0
    count_errors: int = 0
    payload_errors: int = 0
    sequence_gaps: int = 0
    last_seq: Optional[int] = None
    last_timestamp_host_ns: Optional[int] = None
    source_counts: dict[str, int] = field(default_factory=dict)
    error_counts: dict[str, int] = field(default_factory=dict)

    def note_received(self, *, source: str, timestamp_host_ns: int) -> None:
        self.frames_received += 1
        self.last_timestamp_host_ns = timestamp_host_ns
        self.source_counts[source] = self.source_counts.get(source, 0) + 1

    def note_success(self, *, seq: int, timestamp_host_ns: int) -> None:
        if self.last_seq is not None:
            expected = (self.last_seq + 1) & 0xFFFF
            if seq != expected:
                self.sequence_gaps += 1
        self.frames_parsed_ok += 1
        self.last_seq = seq
        self.last_timestamp_host_ns = timestamp_host_ns

    def note_invalid(self, *, category: str, timestamp_host_ns: int) -> None:
        self.frames_invalid += 1
        self.last_timestamp_host_ns = timestamp_host_ns
        self.error_counts[category] = self.error_counts.get(category, 0) + 1
        if category == "header":
            self.header_errors += 1
        elif category == "count":
            self.count_errors += 1
        elif category == "payload":
            self.payload_errors += 1

    def snapshot(self) -> dict[str, Any]:
        return {
            "frames_received": self.frames_received,
            "frames_parsed_ok": self.frames_parsed_ok,
            "frames_invalid": self.frames_invalid,
            "header_errors": self.header_errors,
            "count_errors": self.count_errors,
            "payload_errors": self.payload_errors,
            "sequence_gaps": self.sequence_gaps,
            "last_seq": self.last_seq,
            "last_timestamp_host_ns": self.last_timestamp_host_ns,
            "source_counts": dict(self.source_counts),
            "error_counts": dict(self.error_counts),
        }
