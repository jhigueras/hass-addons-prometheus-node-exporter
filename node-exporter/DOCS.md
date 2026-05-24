# Hardened Node Exporter

Exposes Home Assistant OS host metrics (CPU, memory, disk, network, hardware
sensors) on port `9100/tcp` for scraping by Prometheus.

> **This add-on runs in non-protected mode** (`host_pid: true`,
> `host_network: true`). Port `9100/tcp` is bound directly on the Home
> Assistant host network. Read the Security tab before installing.

---

## Before you start

You need:

1. A Prometheus instance on your LAN that will scrape this add-on.
2. Your router or firewall configured to block port `9100/tcp` from IoT and
   guest network segments. The add-on cannot enforce this on its own.
3. A bcrypt hash of a scrape password (instructions below).

---

## Step 1 — Generate a bcrypt hash

On any Linux machine with `apache2-utils` installed:

```bash
htpasswd -nBC 12 '' | tr -d ':\n'
```

This prints a hash starting with `$2b$12$...`. Copy it — you will paste it
into the add-on configuration. **Keep the original plaintext password
somewhere safe** (your password manager or secrets manager); you will need it
to configure Prometheus.

If you do not have `apache2-utils`, install it:
- Debian/Ubuntu: `sudo apt install apache2-utils`
- Fedora/RHEL: `sudo dnf install httpd-tools`
- macOS (Homebrew): `brew install httpd`

---

## Step 2 — Configure the add-on

Open the **Configuration** tab and set:

```yaml
enable_basic_auth: true
basic_auth_user: "prometheus"
basic_auth_bcrypt_hash: "$2b$12$..."   # paste your hash here
enable_tls: false
```

The add-on **will not start** if `enable_basic_auth` is `false` or if the
hash field is empty or invalid.

### Optional: TLS

If you have a certificate (e.g. from Let's Encrypt via the Home Assistant SSL
integration), you can enable TLS:

```yaml
enable_tls: true
cert_file: "/ssl/fullchain.pem"
cert_key: "/ssl/privkey.pem"
```

Change `cert_file` and `cert_key` to match your actual certificate file names
under `/ssl/`.

### Optional: collectors

You can disable collectors you do not need. All are enabled by default except
`wifi`.

```yaml
collectors:
  cpu: true
  meminfo: true
  loadavg: true
  time: true
  filesystem: true
  diskstats: true
  netdev: true
  netstat: true
  hwmon: true       # hardware temperature sensors
  wifi: false
```

---

## Step 3 — Start the add-on

Click **Start**. Check the **Log** tab to confirm startup succeeded. You should
see a line like:

```
Starting Prometheus Node Exporter as prometheus:prometheus...
```

---

## Step 4 — Verify

From any machine on the same LAN:

```bash
# Should return 401 (endpoint is protected)
curl -s -o /dev/null -w "%{http_code}" http://<HA_IP>:9100/metrics

# Should return metrics (replace with your actual username and password)
curl -u prometheus:<plaintext-password> http://<HA_IP>:9100/metrics | head
```

---

## Step 5 — Configure Prometheus

Add a scrape job to your Prometheus configuration:

```yaml
scrape_configs:
  - job_name: "node-homeassistant"
    scrape_interval: 30s
    static_configs:
      - targets: ["<HA_IP>:9100"]
        labels:
          instance: "homeassistant"
    basic_auth:
      username: "prometheus"
      password: "<plaintext-password>"   # or use password_file with a secrets manager
```

**Do not commit the plaintext password to version control.** Use
`password_file` pointing to a file managed by your secrets manager (SOPS,
Vault, etc.).

---

## Metrics exposed

| Collector | Key metrics |
|---|---|
| cpu | `node_cpu_seconds_total` |
| meminfo | `node_memory_*` |
| loadavg | `node_load*` |
| time | `node_time_seconds` |
| filesystem | `node_filesystem_*` |
| diskstats | `node_disk_*` |
| netdev | `node_network_*` |
| netstat | `node_netstat_*` |
| hwmon | `node_hwmon_temp_celsius` |

Virtual interfaces (`veth*`, `docker*`, `br-*`, `lo`) and container/system
mounts are excluded automatically.

---

## Troubleshooting

**Add-on fails to start with "Basic Auth is required"**
→ Make sure `enable_basic_auth: true` in the configuration.

**Add-on fails to start with "not a valid bcrypt hash"**
→ The hash must start with `$2a$`, `$2b$`, or `$2y$`. Re-run the
`htpasswd` command and copy the full output.

**`curl` returns 401 even with credentials**
→ Check that the username in the curl command matches `basic_auth_user`
exactly, and that the password is the plaintext password (not the hash).

**Metrics show only container filesystem, not HAOS storage**
→ The filesystem collector relies on `host_pid: true` and the default
mount exclusions. If you see only a small overlay filesystem, check that the
add-on is actually running in non-protected mode (visible in the Info tab).
