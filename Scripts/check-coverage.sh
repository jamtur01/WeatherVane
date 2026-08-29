#!/bin/bash
set -euo pipefail

readonly minimum_line_coverage=60
ignored_files='Tests/|\.build/|Sources/(AppDelegate|CitySelectionView|CombinedPopoverView|'
ignored_files+='CombinedStatusBarController|DayNightBar|SettingsWindowDelegate|TimezoneRow|'
ignored_files+='VisualEffectBackground|main)\.swift'
readonly ignored_files

swift test --enable-code-coverage -Xswiftc -warnings-as-errors

binary_path=$(swift build --show-bin-path)
readonly binary_path
readonly test_binary="$binary_path/WeathervanePackageTests.xctest/Contents/MacOS/WeathervanePackageTests"
readonly profile="$binary_path/codecov/default.profdata"

if [[ ! -x "$test_binary" ]]; then
  echo "Coverage test binary is missing: $test_binary" >&2
  exit 1
fi
if [[ ! -r "$profile" ]]; then
  echo "Coverage profile is missing: $profile" >&2
  exit 1
fi

report=$(xcrun llvm-cov report "$test_binary" \
  -instr-profile="$profile" \
  -ignore-filename-regex="$ignored_files")
readonly report
printf '%s\n' "$report"

line_coverage=$(printf '%s\n' "$report" | awk '$1 == "TOTAL" { gsub("%", "", $10); print $10 }')
readonly line_coverage
if [[ -z "$line_coverage" ]]; then
  echo "Could not read total line coverage from llvm-cov output." >&2
  exit 1
fi

if ! awk -v actual="$line_coverage" -v minimum="$minimum_line_coverage" \
  'BEGIN { exit actual >= minimum ? 0 : 1 }'; then
  echo "Core line coverage is ${line_coverage}%; required: ${minimum_line_coverage}%." >&2
  exit 1
fi

echo "Core line coverage is ${line_coverage}% (minimum ${minimum_line_coverage}%)."
