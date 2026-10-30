#!/usr/bin/env bash
# Exercise the actual replacement binary, including gosu's exec semantics.
set -euo pipefail
image=${1:?usage: bash test/gosu.sh IMAGE}
docker run --rm --network none --entrypoint bash "$image" -euc '
  gosu --version | grep -F "1.20 (go1.27.2 on "
  expected=$(id postgres)
  test "$(gosu postgres id)" = "$expected"
  test "$(gosu 12345:23456 id -u)" = 12345
  test "$(gosu 12345:23456 id -g)" = 23456
  ! gosu postgres gosu root true
'
# With gosu as the container entrypoint, the target must retain PID 1.
docker run --rm --network none --entrypoint gosu "$image" \
  postgres sh -ec 'test "$$" -eq 1'
echo "gosu version, UID/GID/groups, privilege drop and exec checks passed"
