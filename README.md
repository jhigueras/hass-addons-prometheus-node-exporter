# Hardened Node Exporter — HAOS Add-on

A hardened fork of [racksync/hass-addons-prometheus-node-exporter][upstream].

Exposes HAOS host health metrics (CPU, memory, disk, network, hardware sensors)
on port `9100/tcp` for scraping by a Prometheus-compatible monitoring stack.

## What this fork changes

| Area | Upstream | This fork |
|---|---|---|
| node-exporter version | 1.8.2 | 1.11.1 |
| Binary integrity | No checksum | SHA256 verified against upstream release |
| Basic Auth | Optional, off by default | **Mandatory** — add-on refuses to start without it |
| Auth credential field | `basic_auth_pass` (plaintext) | `basic_auth_bcrypt_hash` (bcrypt only) |
| Shell injection guard | None | Username allowlist + YAML single-quoting |
| Token write to disk | `SUPERVISOR_TOKEN` written to `/run/` | Removed |
| Extra CLI args | `cmdline_extra_args` (shell injection risk) | Removed |
| HA API surface | auth\_api, hassio\_api enabled | All disabled |
| Collector config | `ignore_mount_points`, `ignore_network_devices` lists | Removed; sensible excludes hardcoded |
| CI | Publish-only sync | shellcheck + hadolint + yaml-lint + unit tests |

## Security posture

This add-on requires `host_pid: true` and `host_network: true` — it runs in
**non-protected mode**. Read [SECURITY.md][security] before installing.

Key controls in this fork: Basic Auth mandatory, bcrypt-only hashes, no HA API
access, no SUPERVISOR_TOKEN on disk, SHA256 binary verification.

Required operator controls: firewall blocking port `9100/tcp` from untrusted network segments;
do not expose through a reverse proxy or WAN.

## Installation

1. Add this repository to your Home Assistant add-on store:
   ```
   https://github.com/jhigueras/hass-addons-prometheus-node-exporter
   ```
   Go to **Settings** → **Add-ons** → **Add-on Store** → ⋮ → **Repositories**

2. Install **Hardened Node Exporter**.

3. Generate a bcrypt hash for your scrape password:
   ```
   htpasswd -nBC 12 '' | tr -d ':\n'
   ```

4. Configure the add-on:
   ```yaml
   enable_basic_auth: true
   basic_auth_user: "prometheus"
   basic_auth_bcrypt_hash: "$2b$12$..."   # output of htpasswd above
   enable_tls: false
   ```

5. Start the add-on.

6. Verify: `curl -u prometheus:<plaintext-password> http://<HA_IP>:9100/metrics | head`

## Configuration reference

| Option | Required | Default | Description |
|---|---|---|---|
| `enable_basic_auth` | yes | `true` | Must be `true`. Add-on exits if false. |
| `basic_auth_user` | yes | `prometheus` | Username. Letters, digits, `-`, `_` only. |
| `basic_auth_bcrypt_hash` | yes | — | bcrypt hash starting with `$2a$`, `$2b$`, or `$2y$`. |
| `enable_tls` | no | `false` | Enable HTTPS. Requires `cert_file` and `cert_key`. |
| `cert_file` | conditional | — | Path under `/ssl/`, e.g. `/ssl/fullchain.pem`. |
| `cert_key` | conditional | — | Path under `/ssl/`, e.g. `/ssl/privkey.pem`. |
| `log_level` | no | `info` | `trace`, `debug`, `info`, `warn`, or `error`. |
| `collectors.*` | no | see below | Enable/disable individual collectors. |

### Default collectors

| Collector | Default | Key metrics |
|---|---|---|
| cpu | ✅ | `node_cpu_seconds_total` |
| meminfo | ✅ | `node_memory_*` |
| loadavg | ✅ | `node_load*` |
| time | ✅ | `node_time_seconds` |
| filesystem | ✅ | `node_filesystem_*` |
| diskstats | ✅ | `node_disk_*` |
| netdev | ✅ | `node_network_*` |
| netstat | ✅ | `node_netstat_*` |
| hwmon | ✅ | `node_hwmon_temp_celsius` |
| wifi | ❌ | disabled |

Virtual interfaces (`veth*`, `docker*`, `br-*`, `lo`) and container/system mounts
are excluded regardless of collector settings.

## Prometheus integration

See [docs/prometheus-integration.md](docs/prometheus-integration.md) for:
- Scrape configuration examples (YAML and NixOS)
- SOPS secret management
- Grafana dashboard setup
- Alert rules (target down, filesystem full, memory pressure, high load, clock drift)

## Version

**Current version**: `2026.1.0` — node-exporter `1.11.1`

## Upstream

Forked from [racksync/hass-addons-prometheus-node-exporter][upstream].

[upstream]: https://github.com/racksync/hass-addons-prometheus-node-exporter
[security]: https://github.com/jhigueras/hass-addons-prometheus-node-exporter/blob/main/SECURITY.md
