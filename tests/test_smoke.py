"""Smoke test: the package imports and settings resolve without a real environment."""

from pdp.config import get_settings


def test_package_imports() -> None:
    """The pdp package and its submodules import cleanly."""
    import pdp.db  # noqa: F401
    import pdp.pipeline  # noqa: F401
    import pdp.validation  # noqa: F401

    assert pdp.__doc__


def test_settings_have_defaults() -> None:
    """Settings resolve to usable defaults even without a .env file."""
    settings = get_settings()
    assert settings.database_url.startswith("postgresql://")
