# VPN TUI knowledge base

This project is a standalone Mihomo/ClashTUI setup utility. It is not part of
the Golden Aid, AIOS, or product-engineer projects.

## Components

- `install-ubuntu.sh` installs Mihomo and ClashTUI, configures the systemd
  service, downloads Iran routing rules, and installs a user-supplied
  subscription profile.
- `scripts/merge.py` combines a local or remote Mihomo subscription with this
  project's routing rules and writes a local generated configuration.
- `bin/` contains downloaded executable binaries and is local-only.
- `data/ruleset/` and `data/geoip.metadb` are downloaded runtime data.
- `data/config.yaml` is generated and may contain proxy credentials. Never
  commit or share it.

## Configuration lifecycle

Keep the subscription private. The Ubuntu installer accepts it as a command
argument and stores it in the local ClashTUI profile and Mihomo profile. For
local config generation, `merge.py` accepts either a subscription URL or a
local file; prefer a protected local file when shell history or process
arguments may be visible to other users.

Generated configuration, binaries, and downloaded rule databases are excluded
from version control. The repository should contain only the installer,
configuration-building source, and documentation—not a user's proxy nodes or
subscription.

## Safe maintenance

- Do not paste subscription URLs, proxy links, UUIDs, passwords, or generated
  Mihomo configs into issues, logs, or commits.
- Downloaded rule-set files are runtime inputs; refresh them from their
  configured upstream rather than committing copies.
- Review the staged file list and run a secret scan before publishing changes.
- Keep system-service installation and routing changes limited to the explicit
  Ubuntu installer; inspect it before running with `sudo`.

## Source-of-truth map

- [Project README](../../README.md) — scope, components, and local usage.
- [Ubuntu installer](../../install-ubuntu.sh) — system installation behavior.
- [Config merger](../../scripts/merge.py) — subscription parsing and config
  generation.
