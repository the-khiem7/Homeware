# Ansible dev tools in WSL2 (lint, validate, Molecule)

| Field | Value |
|---|---|
| Tool | [Ansible Development Tools](https://docs.ansible.com/projects/dev-tools/) (`ansible-dev-tools`: ansible-core, ansible-lint, Molecule, ansible-navigator, ansible-creator) plus [Checkov](https://www.checkov.io/) and [uv](https://docs.astral.sh/uv/), installed inside a WSL2 Linux distro, with the `ansible-generator` and `ansible-validator` agent skills on top |
| Tested version | uv `0.13.7`, `ansible-dev-tools` `26.11.0` (ansible-core `2.21.6`, ansible-lint `26.11.0`, Molecule `26.11.0`, molecule-plugins `26.11.0`, yamllint `1.38.0`), Checkov `3.4.3`, collections `ansible.posix 2.2.2`, `community.general 14.0.0`, `community.docker 5.4.0`, Ubuntu `24.04` with Python `3.12.3`, Docker Engine `29.9.2`, skills from `akin-ozer/cc-devops-skills` commit `276af75` |
| Method | `uv` from the official release tarball (SHA256 verified), then `uv tool install` into the user profile of the distro |
| Admin needed | No, provided WSL2 and an Ubuntu distro already exist |
| Install location | Inside the distro: `~/.local/bin`, `~/.local/share/uv/tools`, `~/.ansible/collections` |
| Scripts | [`install-tools.sh`](install-tools.sh) - installs everything, safe to re-run. [`Invoke-AnsibleValidator.ps1`](Invoke-AnsibleValidator.ps1) - runs a validator script on a throwaway copy of your content inside the distro |

## Why the default installer needs admin

Ansible's control node (the machine that runs `ansible-playbook`, `ansible-lint` and Molecule) is a Linux or macOS machine. The usual answer on Windows is WSL2, which is a Windows feature that needs administrator rights once, so this guide treats an already enabled WSL2 and an Ubuntu distro as a prerequisite. See the [Docker Engine in WSL2](../docker-engine-wsl/README.md) guide for the distro.

Inside the distro the vendor route is `sudo apt install python3-venv python3-pip` and then `pip install`. Ubuntu ships `venv` and `pip` as separate apt packages, and `sudo` inside the distro needs the distro user's password, which a locked-down setup may not hand out. `uv` needs neither.

## Rejected approaches

| Approach | Why rejected |
|---|---|
| `pip install ansible-core` on Windows | Not tested. The Ansible installation docs state that Windows is not supported as a control node. |
| `sudo apt install ansible python3-venv python3-pip` | Needs `sudo`. The Ubuntu `ansible` package is also older than the PyPI release. |
| `curl ... \| sh` uv installer | Pipes a remote script straight into a shell. This guide downloads the tarball, checks the SHA256, then unpacks it. |
| `python3 -m venv` + `pip install` | Fails on a fresh Ubuntu 24.04 distro: `No module named 'ensurepip'` until `python3-venv` is installed with `sudo`. The validator scripts fall back to exactly this when a tool is missing, so install the tools first. |
| `uv tool install ansible-dev-tools` alone | Exposes only the `adt` command. `ansible-lint`, `molecule` and the rest stay inside the tool environment and are not on `PATH`. Add `--with-executables-from`. |
| Ansible MCP server (`@ansible/ansible-mcp-server`) | Technical preview and needs Node.js 24 in the distro. Its docs list lint, playbook creation, collection scaffolding and playbook execution, but not syntax-check, check mode, Molecule or security scanning. It also contains tools that run `sudo apt-get install` and `ansible-navigator`, and the documented `npx -y` command is unpinned. The skills cover more of the validation pipeline. |
| Docker Desktop or Podman Desktop for Molecule | Needs elevation or a licence. Use the Docker Engine already running in the distro. |
| Running the skill scripts straight from `/mnt/c/...` | The Windows checkout has CRLF line endings and bash stops with `$'\r': command not found`. The helper script works on a converted copy instead. Slower file access and `ansible.cfg` being ignored in a world-writable folder are expected from Ansible and WSL behaviour but were not tested here. |

## Prerequisites

- A Windows standard user account.
- WSL2 with an Ubuntu 24.04 distro. Check with `wsl -l -v`: the distro must show version `2`. If WSL is not enabled, ask IT and stop here.
- `curl` and `git` in the distro (present on a default Ubuntu image).
- Docker Engine running in the distro, with your distro user in the `docker` group, if you want Molecule. Check with `wsl -d Ubuntu-24.04 -- docker version`.
- Node.js on Windows (for `npx skills`) if you install the agent skills.
- Network access to `github.com`, `pypi.org`, `files.pythonhosted.org` and `galaxy.ansible.com`. Molecule also pulls its images from the registry named in the scenario.

## Install

### 1. Install the tools in the distro

Run from the folder that contains the scripts. `wslpath` converts the Windows path, and `--exec` passes arguments to Linux without a shell, so backslashes survive.

```powershell
$distro = "Ubuntu-24.04"
$script = wsl -d $distro --exec wslpath -a (Resolve-Path .\install-tools.sh).Path
wsl -d $distro --exec bash $script
```

The script refuses to run as root, installs `uv` only when the pinned version is not already present, installs the tool set with `uv tool install`, and installs the three collections into `~/.ansible/collections`. Edit the version variables at the top of the script to move to newer releases.

### 2. Install the agent skills (optional)

Run from the project folder that should carry the skills. `-a claude-code` limits the install to one agent and `-y` skips the prompts. Without them the CLI asks for scope and agents.

```powershell
npx --yes skills add https://github.com/akin-ozer/cc-devops-skills --skill ansible-generator --skill ansible-validator -a claude-code -y
```

The CLI copies the skills into `.claude\skills` of the current project and prints a third-party risk summary. The tested run reported `ansible-validator` as medium risk and `ansible-generator` as safe. Read the validator's `scripts\` folder before first use. In the tested version, `rm -rf` is only applied to directories the scripts create with `mktemp`, and `pip install` only runs when a tool is missing.

## Integrate

Login shells in Ubuntu add `~/.local/bin` to `PATH` when the folder exists. Commands started as `wsl -d <distro> --exec ...` or `wsl -d <distro> -- bash script` are not login shells, so add the folder in any script you write:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

The helper script already does this. `Invoke-AnsibleValidator.ps1` finds the skill under `.claude\skills\ansible-validator` in the current folder or in your user profile. Pass `-SkillRoot` to point elsewhere.

## Verify

| Check | Command | Expected |
|---|---|---|
| Tools on PATH | `wsl -d Ubuntu-24.04 --exec bash -c 'export PATH=$HOME/.local/bin:$PATH; command -v ansible-playbook ansible-lint yamllint molecule checkov'` | Five paths under `~/.local/bin` |
| Versions | `wsl -d Ubuntu-24.04 --exec bash -c 'export PATH=$HOME/.local/bin:$PATH; ansible --version \| head -1; ansible-lint --version \| head -1; checkov --version'` | `ansible [core 2.21.6]`, `ansible-lint 26.11.0 ...`, `3.4.3` |
| Docker driver known to Molecule | `molecule --version` | A `docker` line from `molecule_plugins` in the driver list |
| Collections | `ansible-galaxy collection list` | `ansible.posix`, `community.general`, `community.docker` |
| Validator pipeline | Run the checks under Use against the skill's own `test\playbooks\good-playbook.yml` and `bad-playbook.yml` | Good file: `All checks passed successfully!`, exit `0`. Bad file: lint errors (FQCN, truthy, file permissions), 2 hardcoded secrets, 1 Checkov failure, exit `1` |

## Use

Run the validator scripts through the helper. It copies the skill and your content into a new `~/work/validate.*` folder in the distro, converts CRLF to LF in the copy, runs the script, prints the result and deletes the copy. Your Windows files are not changed. When `-Path` is a file, the whole parent folder is copied (without `.git`), because a playbook usually needs the templates and variables next to it.

```powershell
.\Invoke-AnsibleValidator.ps1 -Path .\site.yml -Check playbook
.\Invoke-AnsibleValidator.ps1 -Path .\roles\web -Check role
.\Invoke-AnsibleValidator.ps1 -Path .\site.yml -Check secret-scan
```

| `-Check` | Script run | What it does |
|---|---|---|
| `playbook` | `validate_playbook.sh` | YAML check, `ansible-playbook --syntax-check`, `ansible-lint` |
| `role` | `validate_role.sh` | Structure, syntax, lint, and reports whether a Molecule scenario exists |
| `inventory` | `validate_inventory.sh` | Inventory parse and YAML check |
| `playbook-security`, `role-security` | `validate_*_security.sh` | Checkov policies |
| `secret-scan` | `scan_secrets.sh` | Hardcoded password, key and token patterns |
| `fqcn` | `check_fqcn.sh` | Short module names that need a fully qualified collection name |
| `molecule` | `test_role.sh` | Full Molecule sequence: syntax, create, converge, idempotence, verify, destroy |

Exit code `0` means pass, `1` means findings, `2` means a tool or runtime was missing. The helper passes the exit code through.

Not tested: `inventory` and `fqcn` through the helper.

### Molecule scenario requirements

The `molecule` check ran a full sequence (create, converge, idempotence, verify, destroy) on a small role that writes one file, using the Docker engine in the distro. The scenario needs two settings that the `ansible-generator` role template does not provide:

```yaml
driver:
  name: docker

platforms:
  - name: instance
    image: python:3.12-slim
    pre_build_image: true

provisioner:
  name: ansible
  env:
    ANSIBLE_ROLES_PATH: "${MOLECULE_PROJECT_DIRECTORY}/.."
```

| Setting | Why |
|---|---|
| `provisioner.env.ANSIBLE_ROLES_PATH` | Molecule `26.11.0` does not put the parent folder of the role on the roles path. Without it, a `converge.yml` that says `role: <name>` fails at the syntax stage with `The role '<name>' was not found`. |
| An image that contains Python | The Ansible modules run inside the container. `python:3.12-slim` is a small image that has it. |

The role template in `ansible-generator` was not run as is. Its scenario starts two containers with `privileged: true` and a host cgroup mount on the shared Docker engine. Review that scenario before running it, remove those settings unless the role needs systemd, and run it from a copy inside the distro. Molecule removes its own instances in the destroy step, and the pulled image stays in the engine until you run `docker rmi <image>`.

Direct use of the tools needs the distro shell:

```powershell
wsl -d Ubuntu-24.04
```

Then, inside the distro, `ansible-lint site.yml`, `yamllint .`, `ansible-playbook site.yml --syntax-check`, `checkov -d . --framework ansible` and `molecule test` are available. Work inside the distro's own file system (`~/work`), not under `/mnt/c`.

## Uninstall

Not tested: these steps follow the install layout above but were not run, because running them removes the working install. Run inside the distro as the same user.

```bash
export PATH="$HOME/.local/bin:$PATH"
uv tool uninstall ansible-dev-tools
uv tool uninstall checkov
rm -f ~/.local/bin/uv ~/.local/bin/uvx
rm -rf ~/.local/share/uv ~/.cache/uv
rm -rf ~/.ansible/collections/ansible_collections/ansible/posix \
       ~/.ansible/collections/ansible_collections/community/general \
       ~/.ansible/collections/ansible_collections/community/docker \
       ~/.ansible/collections/ansible_collections/community/library_inventory_filtering_v1
rm -rf ~/work/validate.*
```

Remove the agent skills from the project folder:

```powershell
npx --yes skills remove ansible-generator ansible-validator
```

Run it from the same project folder, or add `-g` for a global install. The command syntax comes from `npx skills remove --help` and was not run. If the project also holds a `.agents\skills` copy created by the installer, delete `.agents\skills\ansible-generator` and `.agents\skills\ansible-validator` by hand. No `PATH` entry, Start Menu shortcut or `HKCU` key is created on the Windows side.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `$'\r': command not found`, `set: -: invalid option` | A skill script has CRLF line endings after a Windows checkout | Run it through `Invoke-AnsibleValidator.ps1`, or convert a copy: `sed -i 's/\r$//' scripts/*.sh`. |
| `ansible-lint: command not found` right after install | `uv tool install ansible-dev-tools` was run without `--with-executables-from`, or the shell is not a login shell | Re-run `install-tools.sh`, and add `~/.local/bin` to `PATH` in non-login scripts. |
| `No module named 'ensurepip'` | A validator script fell back to `python3 -m venv` because a tool was missing | Run `install-tools.sh` so every tool is already on `PATH`. |
| Helper prints `ansible-lint not found in the distro` and exits `2` | Tools not installed in the chosen distro | Run `install-tools.sh`, or pass `-Distro <name>`. |
| `wslpath: C:Users...` with the backslashes removed | `wsl -- cmd` runs the command through a shell that eats backslashes | Use `wsl --exec`, or convert the path to forward slashes. |
| Lint warning `Another version of 'community.general' was found installed in ...ansible-lint-mocks` | ansible-lint creates a mock collections folder next to the content | Seen in the tested run, with the pass or fail result unchanged. |
| Lint warning `Ignored exception from NameRule.matchtasks ...: 'path'` | An ansible-lint 26.11.0 rule raised and was skipped | Seen in the tested run, with the pass or fail result unchanged. |
| `validate_role.sh` fails on the unmodified `ansible-generator` role template | The template still holds placeholders such as `role_name`, which fail the role-name rule | Replace the placeholders before validating. |
| `The role '<name>' was not found` in the Molecule syntax stage | Molecule 26.11.0 does not add the parent folder of the role to the roles path, and the scenario does not set it | Add `provisioner.env.ANSIBLE_ROLES_PATH: "${MOLECULE_PROJECT_DIRECTORY}/.."` to `molecule.yml`, and keep the role folder name equal to the role name. |
| Molecule cannot reach Docker | Your distro user is not in the `docker` group, or the engine is not running | `wsl -d Ubuntu-24.04 -- docker version` must print a server version. |
