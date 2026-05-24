# Hardened Node Exporter for Home Assistant OS

Exposes HAOS host health metrics (CPU, memory, disk, network, hardware sensors)
for scraping by a Prometheus-compatible monitoring stack.

This is a hardened fork of the [RACKSYNC community add-on][upstream].

## ⚠ Non-protected mode warning

This add-on requires `host_pid: true` and `host_network: true`. It runs in
**non-protected mode**. Read [SECURITY.md][security] before installing.

## Requirements

- Home Assistant OS on amd64, aarch64, or armv7
- A Prometheus scraper with Basic Auth support on the same LAN
- Untrusted network segments blocked from port `9100/tcp` at the router

## Installation

1. Add this repository to your Home Assistant add-on store:
   `https://github.com/jhigueras/hass-addons-prometheus-node-exporter`
2. Install **Hardened Node Exporter**.
3. Generate a bcrypt hash for your scrape password:
   ```
   htpasswd -nBC 12 '' | tr -d ':\n'
   ```
4. Set `basic_auth_user` and `basic_auth_bcrypt_hash` in the add-on configuration.
5. Start the add-on.
6. Verify: `curl -u <user>:<plaintext-password> http://<HA_IP>:9100/metrics | head`

## Prometheus scrape configuration (NixOS example)

```nix
{
  job_name = "node-homeassistant";
  static_configs = [{
    targets = [ "<HA_IP>:9100" ];
    labels = { instance = "homeassistant"; };
  }];
  basic_auth = {
    username = "prometheus";
    password_file = config.sops.secrets."monitoring/HA_NODE_EXPORTER_PASS".path;
  };
  scrape_interval = "30s";
}
```

The Prometheus scraper uses the **plaintext password**. The add-on stores and
validates only the **bcrypt hash**. These are two separate values for the same
credential.

## Default collectors

| Collector | Enabled | Key metrics |
|---|---|---|
| cpu | ✅ | `node_cpu_seconds_total` |
| meminfo | ✅ | `node_memory_*` |
| loadavg | ✅ | `node_load*` |
| time | ✅ | `node_time_seconds` |
| filesystem | ✅ | `node_filesystem_*` |
| diskstats | ✅ | `node_disk_*` |
| netdev | ✅ | `node_network_*` |
| netstat | ✅ | `node_netstat_*` |
| hwmon | ✅ | `node_hwmon_temp_celsius` (RPi CPU temp) |
| boottime | ✅ | `node_boot_time_seconds` |
| wifi | ❌ | disabled |

Virtual interfaces (`veth*`, `docker*`, `br-*`, `lo`) and container/system
mounts are excluded by default.

## Security posture

See [SECURITY.md][security] for full details and required operator controls.

[upstream]: https://github.com/racksync/hass-addons-prometheus-node-exporter
[security]: https://github.com/jhigueras/hass-addons-prometheus-node-exporter/blob/main/SECURITY.md
