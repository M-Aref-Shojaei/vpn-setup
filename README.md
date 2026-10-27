# VPN TUI

This project combines Mihomo with ClashTUI for local proxy routing. It is a
standalone utility; it is not part of the Golden Aid, AIOS, or product-engineer
projects. See the [VPN TUI knowledge base](docs/knowledge-base/README.md) for
the component map and configuration-safety guidance.

## Layout

- `install-ubuntu.sh` installs Mihomo and ClashTUI and configures the systemd
  service on Ubuntu 20.04+ (amd64 or arm64). It requires a subscription URL.
- `bin/` contains local downloaded executables; it is not committed.
- `scripts/merge.py` builds a Mihomo config from a subscription and the Iran
  bypass rules.
- `data/ruleset/` and `data/geoip.metadb` contain downloaded runtime data; they
  are not committed.
- `data/config.yaml` is generated local configuration and can contain working
  proxy credentials. It is ignored by Git and must never be shared or committed.

## Local configuration

Generate a local configuration from a private subscription URL or local
subscription file:

```bash
python3 scripts/merge.py /path/to/private-subscription.txt
```

The command writes `data/config.yaml`. Keep subscription files and generated
configs private. Avoid passing a live subscription URL directly on a shared
machine, where shell history or process listings may expose it.

## Ubuntu installation

```bash
sudo bash install-ubuntu.sh '<private-subscription-url>'
```

The installer stores the subscription locally in the ClashTUI profile and
downloads its profile. Do not copy the resulting system configuration into
this repository.
