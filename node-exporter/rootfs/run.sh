#!/usr/bin/env bashio
# ==============================================================================
# Prometheus Node Exporter add-on — entrypoint
#
# Runs in the host PID namespace; S6-Overlay cannot be used here.
# ==============================================================================

if ! /etc/cont-init.d/node_exporter.sh; then
    bashio::log.fatal "Initialization failed. Refusing to start node_exporter."
    exit 1
fi

exec /etc/services.d/node_exporter/run
