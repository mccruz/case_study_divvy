#!/usr/bin/env python3
"""Safely import one expected Divvy monthly CSV through psql.

The script validates the filename and exact header before opening psql. The SQL
script then loads the file, checks its timestamps, and writes the raw rows plus
the source receipt atomically.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import os
import pathlib
import re
import subprocess
import sys
import tempfile


EXPECTED_HEADER = [
    "ride_id", "rideable_type", "started_at", "ended_at", "start_station_name",
    "start_station_id", "end_station_name", "end_station_id", "start_lat",
    "start_lng", "end_lat", "end_lng", "member_casual",
]
MONTH_FILE = re.compile(r"^(2022(?:08|09|10|11|12)|2023(?:01|02|03|04|05|06|07))-divvy-tripdata\.csv$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Atomically import one approved Divvy monthly CSV.")
    parser.add_argument("csv_file", type=pathlib.Path)
    parser.add_argument("--database", required=True, help="psql database name or connection string")
    return parser.parse_args()


def source_month(path: pathlib.Path) -> dt.date:
    match = MONTH_FILE.fullmatch(path.name)
    if match is None:
        raise ValueError("filename must be YYYYMM-divvy-tripdata.csv for Aug 2022 through Jul 2023")
    return dt.datetime.strptime(match.group(1), "%Y%m").date().replace(day=1)


def validate_header(path: pathlib.Path) -> None:
    with path.open("r", encoding="utf-8-sig", newline="") as source:
        header = next(csv.reader(source), None)
    if header != EXPECTED_HEADER:
        raise ValueError("CSV header must exactly match the documented 13-column Divvy schema")


def snapshot_and_sha256(path: pathlib.Path) -> tuple[pathlib.Path, str]:
    """Copy the source once, hashing the exact bytes later sent to psql."""
    digest = hashlib.sha256()
    snapshot_path: pathlib.Path | None = None
    try:
        with tempfile.NamedTemporaryFile(prefix="divvy-import-", suffix=".csv", delete=False) as snapshot:
            snapshot_path = pathlib.Path(snapshot.name)
            with path.open("rb") as source:
                while chunk := source.read(1024 * 1024):
                    snapshot.write(chunk)
                    digest.update(chunk)
            snapshot.flush()
            os.fsync(snapshot.fileno())
        return snapshot_path, digest.hexdigest()
    except BaseException:
        if snapshot_path is not None:
            snapshot_path.unlink(missing_ok=True)
        raise


def main() -> int:
    args = parse_args()
    path = args.csv_file.expanduser().resolve()
    if not path.is_file():
        raise ValueError(f"CSV file does not exist: {path}")
    month = source_month(path)
    snapshot, checksum = snapshot_and_sha256(path)
    try:
        validate_header(snapshot)
        script = pathlib.Path(__file__).resolve().parents[1] / "sql" / "00_import_month.sql"
        command = [
            "psql", "-X", "-v", "ON_ERROR_STOP=1", "-d", args.database,
            "-v", f"source_month={month.isoformat()}", "-v", f"filename={path.name}",
            "-v", f"sha256={checksum}", "-f", str(script),
        ]
        with snapshot.open("rb") as source:
            subprocess.run(command, stdin=source, check=True)
    finally:
        snapshot.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"import failed: {error}", file=sys.stderr)
        raise SystemExit(1)
