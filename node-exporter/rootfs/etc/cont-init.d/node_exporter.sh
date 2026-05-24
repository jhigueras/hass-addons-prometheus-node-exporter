#!/usr/bin/env bashio
# ==============================================================================
# Prometheus Node Exporter add-on — configuration phase
# ==============================================================================
bashio::require.unprotected

# Basic Auth is mandatory. Refuse to start if disabled.
if bashio::config.false 'enable_basic_auth'; then
    bashio::log.fatal "Basic Auth is required and cannot be disabled."
    bashio::log.fatal "Set enable_basic_auth: true and provide basic_auth_user and basic_auth_bcrypt_hash."
    exit 1
fi

bashio::config.require 'basic_auth_user' "basic_auth_user must not be empty"
bashio::config.require 'basic_auth_bcrypt_hash' "basic_auth_bcrypt_hash must not be empty"

basic_auth_user="$(bashio::config 'basic_auth_user')"
basic_auth_bcrypt_hash="$(bashio::config 'basic_auth_bcrypt_hash')"

# Validate username — restrict to safe chars to prevent YAML injection.
if [[ ! "${basic_auth_user}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    bashio::log.fatal "basic_auth_user must only contain letters, digits, hyphens, and underscores."
    exit 1
fi

# Validate bcrypt prefix — node-exporter web config requires a bcrypt hash.
if [[ ! "${basic_auth_bcrypt_hash}" =~ ^\$2[aby]\$ ]]; then
    bashio::log.fatal "basic_auth_bcrypt_hash is not a valid bcrypt hash."
    bashio::log.fatal "It must start with \$2a\$, \$2b\$, or \$2y\$."
    bashio::log.fatal "Generate one with: htpasswd -nBC 12 '' | tr -d ':\\n'"
    exit 1
fi

# Create web config file with restricted permissions.
# WEB_CONFIG_FILE can be overridden in tests; when set, permission hardening is skipped
# because tests run as an unprivileged user without the prometheus group.
web_config_file="${WEB_CONFIG_FILE:-/addon_config/node_exporter_web.yml}"
mkdir -p "$(dirname "${web_config_file}")"
rm -f "${web_config_file}"
if [[ -z "${WEB_CONFIG_FILE:-}" ]]; then
    install -m 640 /dev/null "${web_config_file}" \
        || { bashio::log.fatal "Failed to create web config at ${web_config_file}"; exit 1; }
    chown root:prometheus "${web_config_file}" \
        || { bashio::log.fatal "Failed to set ownership on ${web_config_file}"; exit 1; }
else
    touch "${web_config_file}" \
        || { bashio::log.fatal "Failed to create web config at ${web_config_file}"; exit 1; }
fi

bashio::log.info "Writing web config with Basic Auth..."

# Use YAML single-quoted strings to prevent injection. Escape internal ' to ''.
# Username is already restricted to [a-zA-Z0-9_-] so escaping is a safety net only.
user_yaml="${basic_auth_user//\'/\'\'}"
hash_yaml="${basic_auth_bcrypt_hash//\'/\'\'}"

printf 'basic_auth_users:\n  '"'"'%s'"'"': '"'"'%s'"'"'\n' \
    "${user_yaml}" "${hash_yaml}" > "${web_config_file}" \
    || { bashio::log.fatal "Failed to write basic_auth_users to web config"; exit 1; }

# Optional TLS.
if bashio::config.true 'enable_tls'; then
    bashio::log.info "TLS is enabled."
    bashio::config.require 'cert_file' "cert_file required when enable_tls is true"
    bashio::config.require 'cert_key' "cert_key required when enable_tls is true"
    cert_file="$(bashio::config 'cert_file')"
    cert_key="$(bashio::config 'cert_key')"

    cert_file_yaml="${cert_file//\'/\'\'}"
    cert_key_yaml="${cert_key//\'/\'\'}"

    printf 'tls_server_config:\n  cert_file: '"'"'%s'"'"'\n  key_file: '"'"'%s'"'"'\n' \
        "${cert_file_yaml}" "${cert_key_yaml}" >> "${web_config_file}" \
        || { bashio::log.fatal "Failed to write tls_server_config to web config"; exit 1; }
else
    bashio::log.warning "TLS is disabled. Ensure port 9100 is not reachable from IoT or guest VLANs."
fi

bashio::log.info "Configuration complete."
