#!/usr/bin/env bash
# Installs uv, the Ansible dev tools, checkov and the required collections into the current user's home.
# Run inside the WSL distro as a normal user. No sudo is used.
set -euo pipefail

UV_VERSION=0.13.7
ADT_VERSION=26.11.0
MOLECULE_PLUGINS_VERSION=26.11.0
CHECKOV_VERSION=3.4.3
COLLECTIONS=("ansible.posix:>=1.5.0" "community.general:>=8.0.0" "community.docker:>=3.10.2")

export PATH="$HOME/.local/bin:$PATH"

[ "$(id -u)" -ne 0 ] || { echo "Run as a normal user, not root." >&2; exit 1; }
[ "$(uname -m)" = "x86_64" ] || { echo "Only x86_64 is covered by this script." >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required." >&2; exit 1; }

# 1. uv, from the official release tarball with a SHA256 check
if [ "$(uv --version 2>/dev/null | cut -d' ' -f2)" != "$UV_VERSION" ]; then
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  base="https://github.com/astral-sh/uv/releases/download/$UV_VERSION"
  asset=uv-x86_64-unknown-linux-gnu.tar.gz
  ( cd "$work" && curl -fsSLO "$base/$asset" && curl -fsSLO "$base/$asset.sha256" && sha256sum -c "$asset.sha256" )
  mkdir -p "$HOME/.local/bin"
  tar -xzf "$work/$asset" --strip-components=1 -C "$HOME/.local/bin" uv-x86_64-unknown-linux-gnu/uv uv-x86_64-unknown-linux-gnu/uvx
fi
uv --version

# 2. Ansible dev tools bundle. Without --with-executables-from, uv exposes only `adt`.
uv tool install --force "ansible-dev-tools==$ADT_VERSION" \
  --with "molecule-plugins[docker]==$MOLECULE_PLUGINS_VERSION" \
  --with-executables-from ansible-core,ansible-lint,molecule,ansible-navigator,ansible-creator,yamllint

# 3. Security scanner used by the validator
uv tool install --force "checkov==$CHECKOV_VERSION"

# 4. Collections used by the generator templates and the Molecule docker driver
ansible-galaxy collection install "${COLLECTIONS[@]}"

echo
for t in ansible ansible-playbook ansible-lint yamllint molecule checkov; do
  printf '%-18s %s\n' "$t" "$(command -v "$t" || echo 'NOT FOUND')"
done
