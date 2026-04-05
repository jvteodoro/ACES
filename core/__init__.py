"""Core building blocks for the SPI FFT frame pipeline."""

from .models import FFTBin, FFTFrame, ParserTelemetry, RawSPITransaction
from .parser import (
    CountMismatchError,
    FrameParseError,
    HeaderValidationError,
    PayloadValidationError,
    SPIFrameParser,
)

__all__ = [
    "CountMismatchError",
    "FFTBin",
    "FFTFrame",
    "FrameParseError",
    "HeaderValidationError",
    "ParserTelemetry",
    "PayloadValidationError",
    "RawSPITransaction",
    "SPIFrameParser",
]
