#!/usr/bin/env python3
"""PostgreSQL integration checks for the guarded monthly importer."""

from __future__ import annotations

import argparse
import csv
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
IMPORTER = ROOT / "scripts" / "import_divvy_month.py"
HEADER = [
    "ride_id", "rideable_type", "started_at", "ended_at", "start_station_name",
    "start_station_id", "end_station_name", "end_station_id", "start_lat",
    "start_lng", "end_lat", "end_lng", "member_casual",
]
ROW = ["ride", "classic_bike", "2022-08-01 09:00:00", "2022-08-01 09:30:00",
       "Start", "s", "End", "e", "41.0", "-87.0", "41.1", "-87.1", "member"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--database", required=True)
    return parser.parse_args()


class ImporterIntegrationTests(unittest.TestCase):
    database: str

    @classmethod
    def setUpClass(cls) -> None:
        cls.tempdir = tempfile.TemporaryDirectory(prefix="divvy import ' spaces ")
        cls.directory = pathlib.Path(cls.tempdir.name) / "nested ' folder with spaces"
        cls.directory.mkdir()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tempdir.cleanup()

    def setUp(self) -> None:
        self.psql("TRUNCATE raw_divvy_rides, source_imports;")

    def psql(self, sql: str) -> str:
        return subprocess.run(
            ["psql", "-X", "-v", "ON_ERROR_STOP=1", "-d", self.database, "-Atqc", sql],
            check=True, text=True, capture_output=True,
        ).stdout.strip()

    def import_file(self, path: pathlib.Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(IMPORTER), "--database", self.database, str(path)],
            text=True, capture_output=True,
        )

    def assert_import_failure(self, path: pathlib.Path, reason: str) -> None:
        result = self.import_file(path)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(reason, result.stderr)

    def write_csv(self, name: str, header: list[str] = HEADER, rows: list[list[str]] | None = None) -> pathlib.Path:
        path = self.directory / name
        with path.open("w", encoding="utf-8", newline="") as target:
            writer = csv.writer(target)
            writer.writerow(header)
            writer.writerows(rows or [])
        return path

    def counts(self) -> tuple[str, str]:
        return self.psql("SELECT COUNT(*) FROM raw_divvy_rides"), self.psql("SELECT COUNT(*) FROM source_imports")

    def test_path_spaces_and_quotes_and_duplicate_rollback(self) -> None:
        path = self.write_csv("202208-divvy-tripdata.csv", rows=[ROW])
        self.assertEqual(self.import_file(path).returncode, 0)
        self.assertEqual(self.counts(), ("1", "1"))
        receipt = self.psql("SELECT row_count FROM source_imports WHERE source_month = DATE '2022-08-01'")
        self.assertEqual(receipt, "1")
        self.assert_import_failure(path, "refusing duplicate import")
        self.assertEqual(self.counts(), ("1", "1"))

    def test_header_empty_mixed_month_and_malformed_files_rollback(self) -> None:
        wrong_header = self.write_csv("202208-divvy-tripdata.csv", header=HEADER[:-1], rows=[ROW[:-1]])
        self.assert_import_failure(wrong_header, "CSV header must exactly match")
        self.assertEqual(self.counts(), ("0", "0"))

        empty = self.write_csv("202208-divvy-tripdata.csv")
        self.assert_import_failure(empty, "refusing empty source file")
        self.assertEqual(self.counts(), ("0", "0"))

        mixed_row = ROW.copy()
        mixed_row[2] = "2022-09-01 09:00:00"
        mixed = self.write_csv("202208-divvy-tripdata.csv", rows=[mixed_row])
        self.assert_import_failure(mixed, "null or other-month started_at rows")
        self.assertEqual(self.counts(), ("0", "0"))

        malformed = self.write_csv("202208-divvy-tripdata.csv")
        with malformed.open("a", encoding="utf-8", newline="") as target:
            target.write('ride,"unterminated\n')
        self.assert_import_failure(malformed, "unterminated CSV quoted field")
        self.assertEqual(self.counts(), ("0", "0"))


if __name__ == "__main__":
    arguments = parse_args()
    ImporterIntegrationTests.database = arguments.database
    unittest.main(argv=["test_importer.py"])
