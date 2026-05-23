#!/usr/bin/env bash
# Tests for node-exporter/rootfs/etc/cont-init.d/node_exporter.sh
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INIT_SCRIPT="${SCRIPT_DIR}/../node-exporter/rootfs/etc/cont-init.d/node_exporter.sh"
MOCK="${SCRIPT_DIR}/mock_bashio.sh"

PASS=0
FAIL=0

# Export config key=value pairs as __TEST_CONFIG_* env vars so the mock can read
# them without any string injection. Must be called in the current shell (not a
# subshell) so exports are visible to child bash -c processes.
_set_config() {
    local env_vars=()
    for kv in "$@"; do
        local k="${kv%%=*}"
        local v="${kv#*=}"
        local env_key="__TEST_CONFIG_${k//./_}"
        export "${env_key}=${v}"
        env_vars+=("${env_key}")
    done
    # Return var names via a global to avoid process substitution subshell
    _SET_CONFIG_VARS=("${env_vars[@]}")
}

_clear_config() {
    for var in "${_SET_CONFIG_VARS[@]+"${_SET_CONFIG_VARS[@]}"}"; do
        unset "${var}"
    done
    _SET_CONFIG_VARS=()
}

declare -a _SET_CONFIG_VARS=()

run_test() {
    local name="$1"
    local expected_exit="$2"
    shift 2

    local tmpdir
    tmpdir="$(mktemp -d)"
    local web_config="${tmpdir}/node_exporter_web.yml"

    _set_config "$@"

    local actual_exit=0
    WEB_CONFIG_FILE="${web_config}" bash -c "
        source '${MOCK}'
        source '${INIT_SCRIPT}'
    " >/dev/null 2>&1 || actual_exit=$?

    _clear_config
    rm -rf "${tmpdir}"

    if [[ "${actual_exit}" -eq "${expected_exit}" ]]; then
        printf 'PASS: %s\n' "${name}"
        PASS=$(( PASS + 1 ))
    else
        printf 'FAIL: %s (expected exit %s, got %s)\n' "${name}" "${expected_exit}" "${actual_exit}"
        FAIL=$(( FAIL + 1 ))
    fi
}

run_test_with_output() {
    local name="$1"
    local expected_exit="$2"
    local check_fn="$3"
    shift 3

    local tmpdir
    tmpdir="$(mktemp -d)"
    local web_config="${tmpdir}/node_exporter_web.yml"

    _set_config "$@"

    local actual_exit=0
    WEB_CONFIG_FILE="${web_config}" bash -c "
        source '${MOCK}'
        source '${INIT_SCRIPT}'
    " >/dev/null 2>&1 || actual_exit=$?

    _clear_config

    if [[ "${actual_exit}" -ne "${expected_exit}" ]]; then
        printf 'FAIL: %s (expected exit %s, got %s)\n' "${name}" "${expected_exit}" "${actual_exit}"
        FAIL=$(( FAIL + 1 ))
    elif ! "${check_fn}" "${web_config}"; then
        printf 'FAIL: %s (output check failed)\n' "${name}"
        FAIL=$(( FAIL + 1 ))
    else
        printf 'PASS: %s\n' "${name}"
        PASS=$(( PASS + 1 ))
    fi
    rm -rf "${tmpdir}"
}

# ── Tests ──────────────────────────────────────────────────────────────────

run_test "auth disabled exits 1" 1 \
    "enable_basic_auth=false"

run_test "empty bcrypt hash exits 1" 1 \
    "enable_basic_auth=true" \
    "basic_auth_user=prometheus" \
    "basic_auth_bcrypt_hash="

run_test "plaintext password rejected" 1 \
    "enable_basic_auth=true" \
    "basic_auth_user=prometheus" \
    "basic_auth_bcrypt_hash=hunter2"

run_test "md5crypt hash rejected" 1 \
    "enable_basic_auth=true" \
    "basic_auth_user=prometheus" \
    "basic_auth_bcrypt_hash=\$1\$somesalt\$XXXXXXXXXXXXXXXXXXXXXXXXXX"

run_test "username with illegal chars rejected" 1 \
    "enable_basic_auth=true" \
    "basic_auth_user=prom:etheus" \
    "basic_auth_bcrypt_hash=\$2y\$12\$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

check_web_config_content() {
    local web_config="$1"
    grep -q "basic_auth_users:" "${web_config}" && grep -q "prometheus" "${web_config}"
}
run_test_with_output "valid \$2a\$ hash writes web config" 0 check_web_config_content \
    "enable_basic_auth=true" \
    "basic_auth_user=prometheus" \
    "basic_auth_bcrypt_hash=\$2a\$12\$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
    "enable_tls=false"

run_test "valid \$2b\$ hash accepted" 0 \
    "enable_basic_auth=true" \
    "basic_auth_user=prometheus" \
    "basic_auth_bcrypt_hash=\$2b\$12\$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
    "enable_tls=false"

run_test "valid \$2y\$ hash accepted" 0 \
    "enable_basic_auth=true" \
    "basic_auth_user=prometheus" \
    "basic_auth_bcrypt_hash=\$2y\$12\$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
    "enable_tls=false"

run_test "TLS enabled without cert_file exits 1" 1 \
    "enable_basic_auth=true" \
    "basic_auth_user=prometheus" \
    "basic_auth_bcrypt_hash=\$2y\$12\$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
    "enable_tls=true" \
    "cert_file=" \
    "cert_key=/ssl/privkey.pem"

check_tls_in_web_config() {
    local web_config="$1"
    grep -q "tls_server_config:" "${web_config}"
}
run_test_with_output "TLS enabled with certs writes tls_server_config" 0 check_tls_in_web_config \
    "enable_basic_auth=true" \
    "basic_auth_user=prometheus" \
    "basic_auth_bcrypt_hash=\$2y\$12\$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
    "enable_tls=true" \
    "cert_file=/ssl/fullchain.pem" \
    "cert_key=/ssl/privkey.pem"

# ── Summary ─────────────────────────────────────────────────────────────────
printf '\nResults: %s passed, %s failed\n' "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
