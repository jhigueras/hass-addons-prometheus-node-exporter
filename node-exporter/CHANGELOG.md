### CHANGELOG

## 2026.1.3

### Fixed

- Add-on failed to start: `install` could not create web config because `/addon_config`
  directory did not exist inside the container. Added `mkdir -p` on the parent path
  before writing.

---

## 2026.1.2

### Changed

- Dropped deprecated `advanced` config field (ignored by supervisor)
- Dropped `armv7` arch (deprecated by HA; supported arches: amd64, aarch64)

---

## 2026.1.1

### Fixed

- SHA256 verification failed at build time: tarball was saved as `node_exporter.tar.gz`
  but `sha256sum -c` looked up the original filename from the checksums file.
  Fixed by downloading with the canonical filename and verifying via full path.

---

## 2026.1.0

### Security hardening (fork baseline)

- Replaced `basic_auth_pass` (plaintext) with `basic_auth_bcrypt_hash`; add-on refuses to start without a valid bcrypt hash
- Basic Auth is now mandatory — add-on exits on startup if disabled
- Added username allowlist validation and YAML single-quote escaping to prevent injection
- Removed `SUPERVISOR_TOKEN` write to `/run/`; no Supervisor token is used at runtime
- Removed `cmdline_extra_args` option (shell injection risk)
- Disabled `auth_api` (was enabled upstream)
- Node Exporter binary now SHA256-verified against upstream release checksums
- Node Exporter runs as `prometheus:prometheus` via `su-exec` (not root)
- Switched to `--collector.disable-defaults` with explicit collector whitelist
- Added `--collector.filesystem.mount-points-exclude` and `--collector.netdev.device-exclude` to drop container/virtual noise
- Replaced broad `config:rw` mount with `addon_config:rw`; removed `share:ro`
- Added CI: shellcheck, hadolint, yaml-lint, unit tests (auth/bcrypt/TLS/collector flags)

### Updated

- Node Exporter: 1.8.2 → **1.11.1**

---

## 2025.11.2

### Bug Fixes
  - Fixed configuration schema for custom_collectors, ignore_mount_points, and ignore_network_devices
  - Corrected Home Assistant add-on schema format from list(str)? to proper YAML list format
  - Resolves configuration validation errors on add-on startup

## 2025.11.1

### Release Notes
  - Major security improvements with AppArmor enabled and minimal API permissions
  - Added configurable collectors for fine-grained metrics control (cpu, meminfo, diskstats, netdev, etc.)
  - Enhanced configuration options including log levels and ignore lists
  - Updated Node Exporter to version 1.8.2 for latest features and security
  - Improved multi-architecture support (amd64, aarch64, armv7)
  - Added comprehensive documentation and translations
  - Source-to-monorepo architecture with automated deployment
  - Enhanced TLS and authentication support
  - Added hardware monitoring capabilities (hwmon collector)
  - Improved overall security posture and performance
  - Updated GitHub workflow for source-to-monorepo architecture
  - Fixed monorepo sync to target correct node-exporter directory
  - Added configuration validation before sync to monorepo
  - Updated repository URLs to reflect correct deployment target
  - Enhanced version tagging and release management

## 2023.10.1

### Release Notes
  - First Release




