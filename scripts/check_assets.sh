#!/usr/bin/env bash
# R8: 자산 0바이트 검사 스크립트
# 사용법: bash scripts/check_assets.sh
# commit 전 실행하여 0바이트 파일 유무 확인
set -e
echo "Checking zero-byte files..."
EMPTY_FILES=$(find android/app/src/main/res assets -type f -size 0 ! -name '.gitkeep' -print 2>/dev/null || true)
if [ -n "$EMPTY_FILES" ]; then
  echo "ERROR: Zero-byte files found:"
  echo "$EMPTY_FILES"
  exit 1
fi
echo "Asset check passed."
