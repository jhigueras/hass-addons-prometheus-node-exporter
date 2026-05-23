#!/usr/bin/env bash
# Minimal bashio mock for unit testing.
#
# Config values are passed via environment variables prefixed with __TEST_CONFIG_.
# Dots in keys are replaced with underscores.
# Example: collectors.cpu=true → export __TEST_CONFIG_collectors_cpu=true
#
# This avoids string injection that occurs when building bash -c snippets with
# arbitrary values.

bashio::require.unprotected() { return 0; }

bashio::log.info()    { printf '[INFO] %s\n' "$*" >&2; }
bashio::log.warning() { printf '[WARN] %s\n' "$*" >&2; }
bashio::log.fatal()   { printf '[FATAL] %s\n' "$*" >&2; }

_bashio_env_key() {
    local key="${1//./_}"
    printf '__TEST_CONFIG_%s' "${key}"
}

bashio::config() {
    local env_key
    env_key="$(_bashio_env_key "${1}")"
    printf '%s' "${!env_key:-}"
}

bashio::config.true() {
    local env_key
    env_key="$(_bashio_env_key "${1}")"
    [[ "${!env_key:-}" == "true" ]]
}

bashio::config.false() {
    local env_key
    env_key="$(_bashio_env_key "${1}")"
    [[ "${!env_key:-}" == "false" ]]
}

bashio::config.require() {
    local env_key
    env_key="$(_bashio_env_key "${1}")"
    local val="${!env_key:-}"
    if [[ -z "${val}" ]]; then
        bashio::log.fatal "${2:-Required config missing: ${1}}"
        exit 1
    fi
}
