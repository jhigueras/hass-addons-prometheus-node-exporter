# Security

## Residual risk

This add-on requires `host_network: true` and `host_pid: true` because
Prometheus Node Exporter needs access to the host network stack and host
process table to collect accurate system metrics. These cannot be removed
without breaking the core functionality.

This means the add-on runs in **non-protected mode**. Understand what that
means before installing:

- The add-on process can observe all processes running on the HAOS host.
- Port `9100/tcp` is bound directly on the Home Assistant host network, not
  in a container-isolated network.
- Local network clients that can reach the host can attempt to connect to
  port `9100/tcp`.

**Risk level after hardening: medium. This is not a low-risk add-on.**

## Security controls in this fork

The following controls reduce but do not eliminate the risk:

- Basic Auth is mandatory. The add-on refuses to start without it.
- Passwords are stored as bcrypt hashes only. No plaintext passwords in config.
- No Home Assistant API access (`homeassistant_api: false`).
- No Supervisor API access (`hassio_api: false`).
- No Auth API access (`auth_api: false`).
- No Docker API access (`docker_api: false`).
- AppArmor is enabled (`apparmor: true`).
- Node Exporter runs as `prometheus:prometheus`, not root.
- Collector set is minimal and explicitly whitelisted.
- Virtual network interfaces and container mounts are excluded by default.
- Upstream Node Exporter binary is verified against the official SHA256 checksum.

## Network controls required from the operator

This add-on cannot enforce network-level isolation on its own. The operator
must configure the router or firewall to block port `9100/tcp` from any
untrusted network segments. Same-LAN clients are not blocked by the router and rely on
Basic Auth for access control.

Do not expose port `9100/tcp` through Caddy, WAN port forwarding, or any
public reverse proxy.

### Firewall rules (generic examples)

These examples assume:
- `<HA_IP>` is the Home Assistant host address.
- `<PROMETHEUS_IP>` is the Prometheus scraper host address (on the trusted LAN).
- `<UNTRUSTED_SUBNET>` is a network segment to block (repeat the rule for each untrusted segment).

**iptables / nftables (Linux router or firewall host)**

```bash
# Allow Prometheus scraper
iptables -A FORWARD -s <PROMETHEUS_IP> -d <HA_IP> -p tcp --dport 9100 -j ACCEPT

# Block untrusted segments (add one rule per segment)
iptables -A FORWARD -s <UNTRUSTED_SUBNET> -d <HA_IP> -p tcp --dport 9100 -j DROP
```

**EdgeOS / VyOS (EdgeRouter-style CLI)**

```
firewall {
    name UNTRUSTED_TO_LAN {
        rule 10 {
            action drop
            destination {
                address <HA_IP>
                port 9100
            }
            protocol tcp
        }
    }
}
```

Apply the ruleset on untrusted interfaces toward the LAN. Adapt rule
numbers and interface names to your environment.

## Reporting a vulnerability

Open a private issue or contact the maintainer directly via GitHub.
