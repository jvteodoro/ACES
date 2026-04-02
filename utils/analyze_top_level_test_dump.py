#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import math
from collections import Counter
from pathlib import Path
from typing import Iterable


def _load_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def _as_int(value: str) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    return int(str(value), 0)


def _as_float(value: str) -> float:
    return float(value)


def _expected_example_names(meta_path: Path) -> dict[int, str]:
    result: dict[int, str] = {}
    if not meta_path.exists():
        return result
    for line in meta_path.read_text().splitlines():
        if not line.startswith("example_"):
            continue
        key, value = line.split("=", 1)
        try:
            idx = int(key.split("_", 1)[1])
        except ValueError:
            continue
        result[idx] = value.strip()
    return result


def _top_bins(values: Iterable[float], limit: int = 8) -> list[tuple[int, float]]:
    indexed = list(enumerate(values))
    indexed.sort(key=lambda item: item[1], reverse=True)
    return [(idx, mag) for idx, mag in indexed[:limit]]


def _frontend_summary(
    rows: list[dict[str, str]],
    *,
    idx_key: str,
    got_key: str,
    expected_key: str,
) -> tuple[int, list[int]]:
    mismatch_indices: list[int] = []
    valid_rows = 0
    for row in rows:
        if row["in_expected_window"] != "1":
            continue
        valid_rows += 1
        if _as_int(row[got_key]) != _as_int(row[expected_key]):
            mismatch_indices.append(_as_int(row[idx_key]))
    return valid_rows, mismatch_indices


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze tb_top_level_test diagnostic CSV dumps.")
    parser.add_argument(
        "--dump-dir",
        type=Path,
        default=Path("sim/local/questa/top_level_test_real"),
        help="Directory where tb_top_level_test wrote the diagnostic CSV files",
    )
    parser.add_argument("--example", type=int, default=0, help="Example index to analyze")
    parser.add_argument(
        "--fail-on-issues",
        action="store_true",
        help="Exit with code 1 if mismatches are detected",
    )
    args = parser.parse_args()

    dump_dir = args.dump_dir.resolve()
    prefix = dump_dir / f"top_level_test_example_{args.example}"

    sample24_path = prefix.with_name(prefix.name + "_sample24.csv")
    fft_input_path = prefix.with_name(prefix.name + "_fft_input.csv")
    fft_output_path = prefix.with_name(prefix.name + "_fft_output.csv")
    tx_frames_path = prefix.with_name(prefix.name + "_tx_frames.csv")

    missing = [path for path in (sample24_path, fft_input_path, fft_output_path, tx_frames_path) if not path.exists()]
    if missing:
        for path in missing:
            print(f"Missing dump file: {path}")
        return 1

    example_names = _expected_example_names(Path("tb/data/top_level_test_expected_meta.txt"))
    example_name = example_names.get(args.example, f"example_{args.example}")

    sample24_rows = _load_csv(sample24_path)
    fft_input_rows = _load_csv(fft_input_path)
    fft_output_rows = _load_csv(fft_output_path)
    tx_frame_rows = _load_csv(tx_frames_path)

    sample24_count, sample24_mismatches = _frontend_summary(
        sample24_rows,
        idx_key="sample24_idx",
        got_key="got_sample24",
        expected_key="expected_sample24",
    )
    fft_input_count, fft_input_mismatches = _frontend_summary(
        fft_input_rows,
        idx_key="sample18_idx",
        got_key="got_sample18",
        expected_key="expected_sample18",
    )

    fft_valid_rows = [row for row in fft_output_rows if row["in_expected_window"] == "1"]
    fft_abs_err = [_as_float(row["abs_err"]) for row in fft_valid_rows]
    fft_rmse = math.sqrt(sum(err * err for err in fft_abs_err) / len(fft_abs_err)) if fft_abs_err else float("nan")
    fft_max = max(fft_abs_err) if fft_abs_err else float("nan")
    measured_mag = [
        math.hypot(_as_float(row["corrected_real"]), _as_float(row["corrected_imag"]))
        for row in fft_valid_rows
    ]
    expected_mag = [
        math.hypot(_as_float(row["expected_real"]), _as_float(row["expected_imag"]))
        for row in fft_valid_rows
    ]

    tx_event_counts = Counter(row["event"] for row in tx_frame_rows)
    tx_tag_counts = Counter(_as_int(row["actual_tag"]) for row in tx_frame_rows)
    tx_mismatches = [
        row
        for row in tx_frame_rows
        if row["event"] == "matched"
        and _as_int(row["expected_idx"]) >= 0
        and (
            _as_int(row["actual_tag"]) != _as_int(row["expected_tag"])
            or _as_int(row["actual_left"]) != _as_int(row["expected_left"])
            or _as_int(row["actual_right"]) != _as_int(row["expected_right"])
        )
    ]

    print(f"Dump dir: {dump_dir}")
    print(f"Example {args.example}: {example_name}")
    print()

    print("Frontend")
    print(f"  sample24 rows in expected window: {sample24_count}")
    print(f"  sample24 mismatches: {len(sample24_mismatches)}")
    if sample24_mismatches:
        print(f"  first sample24 mismatch indices: {sample24_mismatches[:8]}")
    print(f"  fft_input rows in expected window: {fft_input_count}")
    print(f"  fft_input mismatches: {len(fft_input_mismatches)}")
    if fft_input_mismatches:
        print(f"  first fft_input mismatch indices: {fft_input_mismatches[:8]}")
    print()

    print("FFT Output")
    print(f"  valid bins dumped: {len(fft_valid_rows)}")
    print(f"  rmse: {fft_rmse:.3f}")
    print(f"  max abs err: {fft_max:.3f}")
    print(f"  measured top bins: {_top_bins(measured_mag)}")
    print(f"  expected top bins: {_top_bins(expected_mag)}")
    print()

    print("TX Frames")
    print(f"  decoded frames: {len(tx_frame_rows)}")
    print(f"  events: {dict(tx_event_counts)}")
    print(f"  tags: {dict(tx_tag_counts)}")
    print(f"  frame mismatches vs expected: {len(tx_mismatches)}")
    if tx_mismatches:
        preview = tx_mismatches[:5]
        for row in preview:
            print(
                "  mismatch"
                f" frame_seq={row['frame_seq']}"
                f" expected_idx={row['expected_idx']}"
                f" actual=({row['actual_tag']},{row['actual_left']},{row['actual_right']})"
                f" expected=({row['expected_tag']},{row['expected_left']},{row['expected_right']})"
            )

    has_issues = any(
        [
            sample24_mismatches,
            fft_input_mismatches,
            tx_mismatches,
        ]
    )
    if args.fail_on_issues and has_issues:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
