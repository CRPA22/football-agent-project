set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

# Lista los comandos disponibles
default:
    @just --list

# Prepara el entorno: dependencias + hooks de git (una vez por clon del repo)
setup:
    uv sync
    uv run pre-commit install

# Corrige automáticamente lint y formato
fix:
    uv run ruff check --fix .
    uv run ruff format .

# Lint + formato (sin modificar archivos)
lint:
    uv run ruff check .
    uv run ruff format --check .

# Verificación de tipos
typecheck:
    uv run mypy

# Tests (acepta argumentos extra, p. ej.: just test -k nombre)
test *args:
    uv run pytest {{args}}

# Todo lo que valida CI: lint, tipos y tests
check: lint typecheck test
