# Claude Docker Development Environment

Containerized Claude CLI dev environment. Mounts a project from `~/repo/` as `/workspace`.

## Prerequisites

- Docker + Docker Compose
- GNU Make

## Quick Start

```bash
make shell
```

First run prompts workspace selection from `~/repo/`. Selection saved to `.workspace`.

## Commands

| Command | Description |
|---------|-------------|
| `make build` | Build the Docker image |
| `make start` | Start container (prompts workspace selection if not set) |
| `make shell` | Open interactive shell (auto-starts if needed) — **default** |
| `make bash` | Open bash shell (falls back to sh) |
| `make stop` | Stop the running container |
| `make restart` | Full rebuild: stop → clean → build → start |
| `make clean` | Remove container and clear saved workspace |
| `make status` | Show container status |
| `make logs` | Follow container logs |
| `make select-workspace` | Re-select workspace from `~/repo/` |
| `make exec cmd="..."` | Run arbitrary command inside container |

## Secrets

Create `.secret` with `KEY=value` pairs (lines starting with `#` ignored). Values are injected as env vars at container start.

## How It Works

- Workspace selected from `~/repo/` subdirs, saved to `.workspace`
- Selected workspace mounted at `/workspace` inside container
- Host UID/GID/DOCKER_GID auto-matched to avoid permission issues
- Container name: `claude`
