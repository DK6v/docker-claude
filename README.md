# Claude Docker Development Environment

Containerized Claude CLI dev environment. Mounts a project as `/workspace`.

## Prerequisites

- Docker + Docker Compose
- GNU Make

## Quick Start

```bash
make shell
```

First run prompts workspace selection from `WORKSPACE_ROOT` (`~/repo` by default). Selection saved to `.workspace`.

## Commands

| Command | Description |
|---------|-------------|
| `make build` | Build the Docker image |
| `make start` | Start container (prompts workspace selection if not set) |
| `make shell` | Open interactive shell as host user (auto-starts if needed) — **default** |
| `make root` | Open interactive shell as root (auto-starts if needed) |
| `make stop` | Stop the running container |
| `make restart` | Full rebuild: stop → clean → build → start |
| `make clean` | Remove container and clear saved workspace |
| `make status` | Show container status |
| `make logs` | Follow container logs |
| `make select-workspace` | Re-select workspace — pick from list or `[0]` to enter path manually |
| `make exec <cmd>` | Run command inside container: `make exec ls -al` |

## Workspace Root

Workspaces are listed from `~/repo` by default. Override with `WORKSPACE_ROOT`:

```bash
make shell WORKSPACE_ROOT=~/projects
make select-workspace WORKSPACE_ROOT=/mnt/data
```

## Secrets

Create `.secret` with `KEY=value` pairs (lines starting with `#` ignored). Values are injected as env vars at container start.

## How It Works

- Workspace selected from `WORKSPACE_ROOT` subdirs, saved to `.workspace`
- Absolute paths entered manually are supported directly
- Selected workspace mounted at `/workspace` inside container
- Host UID/GID/DOCKER_GID auto-matched to avoid permission issues
- Container waits until user setup is complete before allowing shell access
- Container name: `claude`
