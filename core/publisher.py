from __future__ import annotations

import json
from abc import ABC, abstractmethod
from pathlib import Path
from queue import Queue
from typing import Callable, Iterable

from .models import FFTFrame


class FramePublisher(ABC):
    @abstractmethod
    def publish(self, frame: FFTFrame) -> None:
        raise NotImplementedError

    def close(self) -> None:
        return None


class NullPublisher(FramePublisher):
    def publish(self, frame: FFTFrame) -> None:
        return None


class QueuePublisher(FramePublisher):
    def __init__(self, queue: Queue[FFTFrame] | None = None) -> None:
        self.queue = queue or Queue()

    def publish(self, frame: FFTFrame) -> None:
        self.queue.put(frame)


class CallbackPublisher(FramePublisher):
    def __init__(self, callback: Callable[[FFTFrame], None]) -> None:
        self.callback = callback

    def publish(self, frame: FFTFrame) -> None:
        self.callback(frame)


class MultiPublisher(FramePublisher):
    def __init__(self, publishers: Iterable[FramePublisher]) -> None:
        self.publishers = list(publishers)

    def publish(self, frame: FFTFrame) -> None:
        for publisher in self.publishers:
            publisher.publish(frame)

    def close(self) -> None:
        for publisher in self.publishers:
            publisher.close()


class JsonlFilePublisher(FramePublisher):
    def __init__(self, path: str | Path, *, include_raw_words: bool = False) -> None:
        self.path = Path(path)
        self.include_raw_words = include_raw_words
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._handle = self.path.open("a", encoding="utf-8")

    def publish(self, frame: FFTFrame) -> None:
        payload = frame.to_dict(include_raw_words=self.include_raw_words)
        self._handle.write(json.dumps(payload, sort_keys=True) + "\n")
        self._handle.flush()

    def close(self) -> None:
        self._handle.close()
