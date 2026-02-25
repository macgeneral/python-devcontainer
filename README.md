# Python DevContainer

Sample Python project using `uv` and an Alpine-based Dev Container.

## Features

- Multi-stage Docker setup with dedicated `dev_image` and `release` targets
- Dev Container ready for VS Code (`.devcontainer/devcontainer.json`)
- Tooling preinstalled in container: `uv`, `ruff`, `ty`, `trivy`, `prek`
- Simple app entrypoint exposed as `app`

## Project Layout

```text
.
├── .devcontainer/
├── src/
│   └── example/
│       ├── __init__.py
│       └── main.py
├── tests/
├── Dockerfile
├── pyproject.toml
└── README.md
```

## Requirements

- Docker (for Dev Container workflow)
- VS Code + Dev Containers extension
- Optional local workflow: `uv`

## Getting Started

### Option 1: Use the Dev Container (recommended)

1. Open this folder in VS Code.
2. Run **Dev Containers: Reopen in Container**.
3. Wait for the image to build and attach.

When attached, dependencies are synced automatically via `postAttachCommand`.

### Option 2: Run locally with `uv`

From the repository root:

```bash
uv sync
uv run app
```

Expected output:

```text
Hello World
```

## Development Commands

- Run app: `uv run app`
- Run tests: `uv run pytest`
- Lint/format check: `uv run ruff check .`
- Type check: `uv run ty check`
- Run all pre-commit hooks: `prek run --all-files`

## Docker Build Targets

The `Dockerfile` defines multiple targets:

- `dev_image`: full development environment used by the Dev Container
- `release`: runtime-oriented image for deployment

Example build:

```bash
docker build --target dev_image -t python-devcontainer:dev .
```

## Entry Point

The script command `app` maps to:

- module: `example.main`
- function: `entrypoint`

Defined in `pyproject.toml` under `[project.scripts]`.

## License

MIT (see `LICENSE`).
