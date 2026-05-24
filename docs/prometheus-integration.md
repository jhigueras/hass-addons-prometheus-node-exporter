# Prometheus integration guide

Reference for connecting this add-on to a Prometheus stack, managing secrets
securely, and setting up dashboards and alerts.

---

## Scrape configuration

### Generic YAML

```yaml
scrape_configs:
  - job_name: "node-homeassistant"
    scrape_interval: 30s
    scrape_timeout: 10s
    static_configs:
      - targets: ["<HA_IP>:9100"]
        labels:
          instance: "homeassistant"
    basic_auth:
      username: "prometheus"
      password_file: "/run/secrets/ha-node-exporter-password"
```

`password_file` should point to a file containing only the plaintext password,
managed by your secrets tool (SOPS, Vault, systemd credentials, etc.).

### NixOS (prometheus2 / prometheus module)

```nix
{
  job_name = "node-homeassistant";
  scrape_interval = "30s";
  static_configs = [{
    targets = [ "<HA_IP>:9100" ];
    labels = { instance = "homeassistant"; };
  }];
  basic_auth = {
    username = "prometheus";
    password_file = config.sops.secrets."monitoring/HA_NODE_EXPORTER_PASS".path;
  };
}
```

---

## Secret management with SOPS (NixOS example)

The plaintext scrape password belongs in SOPS, not in `configuration.nix` or
any version-controlled file.

```bash
# Add the secret to your SOPS-encrypted file
sops secrets.yaml
# Add entry: monitoring/HA_NODE_EXPORTER_PASS: "your-plaintext-password"
```

Reference it in NixOS:

```nix
sops.secrets."monitoring/HA_NODE_EXPORTER_PASS" = {
  owner = "prometheus";
};
```

The add-on receives only the bcrypt hash (set in the HA add-on configuration).
The plaintext password stays on the Prometheus host only.

If your add-on configuration is version-controlled (e.g. in a Home Assistant
config repo), consider managing the bcrypt hash through SOPS as well, since a
weak password can be brute-forced from its hash.

---

## Validation

```bash
# Endpoint must return 401 without credentials
curl -s -o /dev/null -w "%{http_code}\n" http://<HA_IP>:9100/metrics

# Endpoint must return 200 with credentials
curl -s -u prometheus:<plaintext-password> http://<HA_IP>:9100/metrics | head -20

# Verify filesystem metrics cover HAOS host storage (not only the container overlay)
curl -s -u prometheus:<plaintext-password> http://<HA_IP>:9100/metrics \
  | grep 'node_filesystem_size_bytes{' | grep -v 'overlay\|tmpfs'

# Check that Prometheus target is UP
curl -s http://<PROMETHEUS_HOST>:9090/api/v1/targets \
  | python3 -m json.tool | grep -A3 '"job":"node-homeassistant"'
```

---

## Grafana dashboard

No pre-built dashboard JSON is included. The community **Node Exporter Full**
dashboard (Grafana ID **1860**) works with this add-on's default collector set.

Import it via: **Dashboards → Import → ID 1860**.

Filter panels to the Home Assistant instance with the variable:
`instance = "homeassistant"` (or set this as a dashboard variable).

### Useful panel queries

| Panel | PromQL |
|---|---|
| CPU usage % | `100 * (1 - avg(rate(node_cpu_seconds_total{instance="homeassistant",mode="idle"}[5m])))` |
| Memory used % | `100 * (1 - node_memory_MemAvailable_bytes{instance="homeassistant"} / node_memory_MemTotal_bytes{instance="homeassistant"})` |
| Filesystem used % | `100 * (1 - node_filesystem_avail_bytes{instance="homeassistant",fstype!~"tmpfs\|overlay"} / node_filesystem_size_bytes{instance="homeassistant",fstype!~"tmpfs\|overlay"})` |
| Load average (1m) | `node_load1{instance="homeassistant"}` |
| CPU temperature | `node_hwmon_temp_celsius{instance="homeassistant"}` |
| Clock offset | `node_timex_offset_seconds{instance="homeassistant"}` |

---

## Alert rules

```yaml
groups:
  - name: homeassistant-host
    rules:

      - alert: HAOSNodeExporterDown
        expr: up{job="node-homeassistant"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Home Assistant node exporter is unreachable"

      - alert: HAOSFilesystemAlmostFull
        expr: |
          (1 - node_filesystem_avail_bytes{instance="homeassistant",fstype!~"tmpfs|overlay"}
               / node_filesystem_size_bytes{instance="homeassistant",fstype!~"tmpfs|overlay"}) > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "HAOS filesystem {{ $labels.mountpoint }} is {{ humanizePercentage $value }} full"

      - alert: HAOSHighMemoryPressure
        expr: |
          (1 - node_memory_MemAvailable_bytes{instance="homeassistant"}
               / node_memory_MemTotal_bytes{instance="homeassistant"}) > 0.90
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "HAOS memory usage above 90% for 10 minutes"

      - alert: HAOSSustainedHighLoad
        expr: node_load1{instance="homeassistant"} > 4
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "HAOS 1-minute load average is {{ $value }} — sustained for 15 minutes"

      - alert: HAOSClockDrift
        expr: abs(node_timex_offset_seconds{instance="homeassistant"}) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "HAOS clock offset is {{ $value }}s — check NTP sync"
```

Adjust thresholds (load `> 4`, filesystem `> 0.85`, etc.) to match your
hardware. On a Raspberry Pi 4 with 4 cores a sustained load of 4 is very high;
you may want to alert at 2.
