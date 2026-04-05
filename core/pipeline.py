from __future__ import annotations

import logging
from typing import Iterable, Optional, Sequence

from .bridge_client import WindowsBridgeClient
from .models import FFTFrame
from .parser import FrameParseError, SPIFrameParser
from .publisher import FramePublisher, NullPublisher


class FramePipeline:
    def __init__(
        self,
        *,
        client: WindowsBridgeClient,
        parser: SPIFrameParser | None = None,
        publisher: FramePublisher | None = None,
        stop_on_parse_error: bool = False,
        logger: Optional[logging.Logger] = None,
    ) -> None:
        self.client = client
        self.parser = parser or SPIFrameParser()
        self.publisher = publisher or NullPublisher()
        self.stop_on_parse_error = stop_on_parse_error
        self.logger = logger or logging.getLogger(__name__)

    def run_capture(
        self,
        *,
        capture_config: dict[str, object],
        max_frames: int | None = None,
    ) -> list[FFTFrame]:
        with self.client:
            self.client.start_capture(capture_config, max_transactions=max_frames)
            return self._consume(max_frames=max_frames)

    def run_pattern_test(
        self,
        *,
        frames: Sequence[Sequence[int]],
        pattern_config: dict[str, object] | None = None,
        capture_config: dict[str, object] | None = None,
        max_frames: int | None = None,
        use_hardware: bool = True,
    ) -> list[FFTFrame]:
        with self.client:
            self.client.start_pattern_test(
                frames=[list(frame) for frame in frames],
                pattern_config=dict(pattern_config or {}),
                capture_config=dict(capture_config or {}),
                max_transactions=max_frames,
                use_hardware=use_hardware,
            )
            return self._consume(max_frames=max_frames)

    def _consume(self, *, max_frames: int | None) -> list[FFTFrame]:
        frames: list[FFTFrame] = []
        for transaction in self.client.iter_transactions():
            try:
                frame = self.parser.parse_transaction(transaction)
            except FrameParseError:
                if self.stop_on_parse_error:
                    raise
                continue

            self.publisher.publish(frame)
            frames.append(frame)
            if max_frames is not None and len(frames) >= max_frames:
                break
        return frames

    def close(self) -> None:
        self.publisher.close()
