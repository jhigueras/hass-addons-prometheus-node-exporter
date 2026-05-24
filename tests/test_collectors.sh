#!/usr/bin/env bash
# Tests for collector flag generation in services.d/node_exporter/run
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
RUN_SCRIPT="${SCRIPT_DIR}/../node-exporter/rootfs/etc/services.d/node_exporter/run"
MOCK="${SCRIPT_DIR}/mock_bashio.sh"

PASS=0
FAIL=0

declare -a _SET_CONFIG_VARS=()

_set_config() {
    local env_vars=()
    for kv in "$@"; do
        local k="${kv%%=*}"
        local v="${kv#*=}"
        local env_key="__TEST_CONFIG_${k//./_}"
        export "${env_key}=${v}"
        env_vars+=("${env_key}")
    done
    _SET_CONFIG_VARS=("${env_vars[@]}")
}

_clear_config() {
    for var in "${_SET_CONFIG_VARS[@]+"${_SET_CONFIG_VARS[@]}"}"; do
        unset "${var}"
    done
    _SET_CONFIG_VARS=()
}

collect_flags() {
    _set_config "$@"

    local output
    output="$(WEB_CONFIG_FILE='/dev/null' bash -c "
        source '${MOCK}'
        su-exec() { shift 2; printf '%s ' \"\$@\"; }
        exec() { su-exec \"\$@\"; }
        source '${RUN_SCRIPT}'
    " 2>/dev/null)"

    _clear_config
    printf '%s' "${output}"
}

run_test() {
    local name="$1"
    local expected_contains="$2"
    local expected_absent="${3:-}"
    shift 3

    local output
    output="$(collect_flags "$@")"
    local ok=true

    if [[ -n "${expected_contains}" ]] && ! grep -Fqe "${expected_contains}" <<< "${output}"; then
        printf 'FAIL: %s — expected %q in output\n  got: %s\n' "${name}" "${expected_contains}" "${output}"
        ok=false
    fi
    if [[ -n "${expected_absent}" ]] && grep -Fqe "${expected_absent}" <<< "${output}"; then
        printf 'FAIL: %s — expected %q to be absent\n  got: %s\n' "${name}" "${expected_absent}" "${output}"
        ok=false
    fi

    if "${ok}"; then
        printf 'PASS: %s\n' "${name}"
        PASS=$(( PASS + 1 ))
    else
        FAIL=$(( FAIL + 1 ))
    fi
}

# ── Tests ──────────────────────────────────────────────────────────────────

run_test "disable-defaults always set" "--collector.disable-defaults" "" \
    "collectors.cpu=true" "collectors.meminfo=true" "collectors.loadavg=true" \
    "collectors.time=true" "collectors.filesystem=true" "collectors.diskstats=true" \
    "collectors.netdev=true" "collectors.netstat=true" "collectors.hwmon=true" \
    "collectors.wifi=false"

run_test "cpu enabled when true"  "--collector.cpu" "" "collectors.cpu=true"
run_test "cpu absent when false"  "" "--collector.cpu"  "collectors.cpu=false"
run_test "hwmon enabled when true" "--collector.hwmon" "" "collectors.hwmon=true"
run_test "hwmon absent when false" "" "--collector.hwmon" "collectors.hwmon=false"
run_test "wifi absent when false"  "" "--collector.wifi" "collectors.wifi=false"
run_test "wifi present when true"  "--collector.wifi" "" "collectors.wifi=true"

run_test "mount-points-exclude always present" \
    "--collector.filesystem.mount-points-exclude" "" "collectors.filesystem=true"

run_test "netdev device-exclude always present" \
    "--collector.netdev.device-exclude" "" "collectors.netdev=true"

# ── Summary ─────────────────────────────────────────────────────────────────
printf '\nResults: %s passed, %s failed\n' "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
