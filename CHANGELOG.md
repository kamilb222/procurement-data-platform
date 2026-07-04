# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Repository scaffolding: directory layout, Docker Compose (Postgres 16 with
  healthcheck + named volume), `pyproject.toml` (uv-managed, ruff configured),
  pre-commit hooks (ruff, detect-secrets, hygiene checks), GitHub Actions CI
  (ruff + pytest), `.env.example`, and manual data-download instructions.
