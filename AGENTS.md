# AGENTS.md

## Secrets

Secrets must never pass through the prompt or the harness.

When a task requires generating or rotating a secret (bcrypt hash, PAT token):
- Explain the exact steps for the user to run themselves.
- Show the correct command without including the secret value.

## Validation

**Never commit without running CI checks locally first.**

```sh
# Lint shell scripts
shellcheck tests/*.sh node-exporter/rootfs/etc/cont-init.d/*.sh \
           node-exporter/rootfs/etc/services.d/node_exporter/run \
           node-exporter/rootfs/run.sh

# Lint Dockerfile
docker run --rm -i hadolint/hadolint < node-exporter/Dockerfile

# Lint YAML
yamllint node-exporter/config.yaml node-exporter/build.yaml repository.yaml

# Unit tests
bash tests/test_init.sh && bash tests/test_collectors.sh
```

If any check fails → stop. No commit. Report the exact error.

## Skill routing

| Change in... | Skill |
|---|---|
| Shell scripts (`.sh`, `run` scripts) | `bash-pro` |

## Documentation

Before committing, check whether changes affect existing docs:
- Does it change behavior described in `README.md` or `node-exporter/README.md`?
- Does it change security posture described in `SECURITY.md`?
- Does it add or remove config options (schema in `config.yaml`)?

If yes → update affected docs in the same commit.

## Continuous improvement

After closing a task, reflect on whether the work reveals something AGENTS.md doesn't cover.
If yes → propose the specific change. Never apply without explicit confirmation.
AGENTS.md changes go in their own commit.

## CLI tools

Prefer modern replacements over POSIX defaults:

| Avoid | Use instead |
|---|---|
| `ls` | `eza` |
| `find` | `fd` |
| `grep` | `rg` (ripgrep) |
| `cat` | `bat` |

## Commits

- Concise message in English describing the change and its reason.
- No `Co-authored-by` or agent attribution.
