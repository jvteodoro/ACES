# WaveForms SPI FFT Pipeline

## Final Architecture

The solution is split into four layers:

1. `windows_bridge/`
   Uses the WaveForms SDK on Windows only. It owns the hardware session, captures SPI bus activity, and runs synthetic SPI generation through the WaveForms Pattern Generator.

2. `core/`
   Owns protocol packing, frame parsing, validation, telemetry, and publication. This layer is WaveForms-agnostic and runs cleanly inside WSL.

3. `core/publisher.py`
   Publishes parsed `FFTFrame` objects to queue, callback, or JSONL sinks without coupling publication to capture or parsing.

4. `tests/`
   Separates parser-level validation from end-to-end validation. The end-to-end suite contains a software loopback path that always runs locally and an opt-in real WaveForms loopback test for Windows hardware validation.

## Windows <-> WSL Bridge

The Windows process is `windows_bridge/bridge_server.py`.

- Transport: `TCP localhost` with `NDJSON`.
- Server side: Windows.
- Client side: WSL.
- Message shape:
  - `hello`: bridge handshake
  - `ack`: command accepted
  - `spi_transaction`: one SPI transaction, one FFT frame candidate
  - `telemetry`: bridge counters
  - `error`: bridge failure
  - `end`: stream completed

Each `spi_transaction` carries:

- `timestamp_host_ns`
- `source`
- `words`
- `metadata`

That keeps the bridge dumb and stable: WaveForms-specific logic stays in Windows, protocol semantics stay in `core/`.

## Modules

- `core/models.py`: `RawSPITransaction`, `FFTBin`, `FFTFrame`, parser telemetry
- `core/protocol.py`: formal bit packing/unpacking for headers and payload words
- `core/parser.py`: strict production parser with validation and telemetry
- `core/publisher.py`: queue/callback/JSONL publishers
- `core/bridge_client.py`: WSL client for the Windows bridge
- `core/pipeline.py`: orchestrates bridge input -> parser -> publisher
- `windows_bridge/waveforms_sdk.py`: lazy `dwf.dll` loading plus shared WaveForms helpers
- `windows_bridge/waveforms_spi_capture.py`: digital capture and SPI transaction reconstruction
- `windows_bridge/waveforms_spi_pattern_test.py`: Pattern Generator emission and loopback harness
- `windows_bridge/bridge_server.py`: TCP bridge process

## FPGA Side Expectations

The production decoder assumes the FPGA is the SPI master and the Analog Discovery only observes the bus:

- one `CS` low pulse corresponds to one FFT frame
- the frame layout is `header0, header1, header2, payload...`
- words are emitted MSB-first with `byteorder="big"`
- SPI timing is mode 0 by default
- idle bus must remain quiescent between FFT frames

The matching RTL transport is documented in `docs/spi_fft_frame_master_protocol.md`.

In `rtl/top/top_level_test.sv`, the intended board wiring for that path is:

- `GPIO_1_D30` -> Analog Discovery digital input used as `SCLK`
- `GPIO_1_D32` -> Analog Discovery digital input used as `CS`
- `GPIO_1_D34` -> Analog Discovery digital input used as `MOSI`
- `GPIO_1_D21` -> optional `frame_pending` monitor
- `GPIO_1_D23` -> optional overflow monitor

## Execution

### 1. Start the bridge on Windows

From a Windows shell in the project root, inside the environment where WaveForms SDK is available:

```powershell
python -m windows_bridge.bridge_server --host 0.0.0.0 --port 9100
```

If `dwf.dll` is not on `PATH`, set:

```powershell
$env:DWF_LIBRARY_PATH="C:\Program Files (x86)\Digilent\WaveFormsSDK"
```

The loader also accepts the full DLL path directly, for example:

```powershell
$env:DWF_LIBRARY_PATH="C:\Program Files (x86)\Digilent\WaveFormsSDK\lib\x64\dwf.dll"
```

### 2. Discover the Windows host from WSL

Typical WSL lookup:

```bash
WINDOWS_HOST="$(awk '/nameserver / {print $2; exit}' /etc/resolv.conf)"
```

### 3. Consume frames from WSL

Example capture flow:

```python
from core.bridge_client import WindowsBridgeClient
from core.parser import SPIFrameParser
from core.pipeline import FramePipeline
from core.publisher import JsonlFilePublisher

client = WindowsBridgeClient(host="WINDOWS_HOST", port=9100)
parser = SPIFrameParser(include_raw_words=True)
publisher = JsonlFilePublisher("sim/local/fft_frames.jsonl", include_raw_words=True)
pipeline = FramePipeline(client=client, parser=parser, publisher=publisher)

frames = pipeline.run_capture(
    capture_config={
        "cs_pin": 0,
        "clk_pin": 1,
        "data_pin": 2,
        "sample_rate_hz": 40_000_000,
        "buffer_size": 131072,
        "source": "real",
    },
    max_frames=10,
)
print(len(frames))
pipeline.close()
```

Example pattern-test flow:

```python
from core.models import FFTBin
from core.protocol import build_frame_words

frames = [
    build_frame_words(
        seq=1,
        bins=(
            FFTBin(bin_id=0, real=7, imag=-9),
            FFTBin(bin_id=1, real=123, imag=-321),
        ),
        flags=0x10,
        exp=0x02,
    )
]

parsed = pipeline.run_pattern_test(
    frames=frames,
    pattern_config={
        "cs_pin": 0,
        "clk_pin": 1,
        "data_pin": 2,
        "sample_rate_hz": 20_000_000,
        "spi_clock_hz": 1_000_000,
    },
    capture_config={
        "cs_pin": 0,
        "clk_pin": 1,
        "data_pin": 2,
        "sample_rate_hz": 20_000_000,
        "source": "test",
    },
    max_frames=1,
    use_hardware=True,
)
```

## Wiring For Real Pattern Tests

For the real WaveForms end-to-end pattern test, wire the Pattern Generator outputs back into the Digital Input channels used by the capture config:

- CS output pin -> CS capture pin
- CLK output pin -> CLK capture pin
- DATA output pin -> DATA capture pin
- Common ground between the participating channels

The current code assumes a single data line and mode-0 style timing by default. If your bench uses different SPI timing, set `cpol` and `cpha` consistently in both `PatternConfig` and `CaptureConfig`.

## Tests

Parser-only tests:

```bash
python3 -m unittest tests.test_parser_unit
```

WaveForms decoder reconstruction tests:

```bash
python3 -m unittest tests.test_waveforms_spi_capture
```

Bridge + parser end-to-end with software loopback:

```bash
python3 -m unittest tests.test_end_to_end_waveforms
```

Real hardware Pattern Generator validation on Windows:

```powershell
$env:RUN_WAVEFORMS_E2E="1"
python -m unittest tests.test_end_to_end_waveforms
```

## Notes

- `COUNT` is treated as payload-word count, not bin count.
- The parser enforces `real, imag` alternation and monotonically increasing `BIN_ID`.
- `VALUE` uses correct signed 18-bit sign extension.
- `FLAGS_LOCAL` is preserved separately for real and imaginary words.
- Sequence gaps are reported as telemetry, not parse failures.
