from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from .recipe_store import RecipeStore


APP_DIR = Path(__file__).resolve().parent
BACKEND_DIR = APP_DIR.parent
DEFAULT_DATA_FILE = BACKEND_DIR / "data" / "recipes_sample" / "recipes_sample.json"
SAMPLE_DATA_WARNING = (
    "Prototype recipe backend: using sample/non-production recipe data. "
    "Set RECIPE_API_DATA_FILE to a verified production dataset before release."
)


def _runtime_environment() -> str:
    return (
        os.environ.get("RECIPE_API_ENV")
        or os.environ.get("APP_ENV")
        or os.environ.get("ENV")
        or "development"
    ).strip().lower()


def _is_truthy(value: str | None) -> bool:
    return (value or "").strip().lower() in {"1", "true", "yes", "on"}


def _is_sample_data_path(path: Path) -> bool:
    try:
        return path.resolve() == DEFAULT_DATA_FILE.resolve()
    except FileNotFoundError:
        return path == DEFAULT_DATA_FILE


def _data_file_path() -> Path:
    configured = os.environ.get("RECIPE_API_DATA_FILE", "").strip()
    path = Path(configured).expanduser() if configured else DEFAULT_DATA_FILE
    is_sample_data = not configured or _is_sample_data_path(path)
    is_production = _runtime_environment() in {"production", "prod"}
    sample_allowed = _is_truthy(os.environ.get("RECIPE_API_ALLOW_SAMPLE_DATA"))
    if is_production and is_sample_data and not sample_allowed:
        raise RuntimeError(
            "RECIPE_API_DATA_FILE must point to a verified production recipe "
            "dataset in production. Set RECIPE_API_ALLOW_SAMPLE_DATA=true only "
            "for an explicit prototype deployment."
        )
    return path


def _data_disclosure(data_file: Path) -> dict[str, Any]:
    is_sample_data = _is_sample_data_path(data_file)
    return {
        "environment": _runtime_environment(),
        "data_mode": "prototype_sample" if is_sample_data else "configured_file",
        "is_sample_data": is_sample_data,
        "data_warning": SAMPLE_DATA_WARNING if is_sample_data else "",
    }


@lru_cache(maxsize=1)
def get_recipe_store() -> RecipeStore:
    store = RecipeStore(_data_file_path())
    store.load()
    return store


app = FastAPI(
    title="NutriMind Recipe API",
    version="0.1.0",
    description=(
        "Recipe API over a configured local JSON file. The bundled sample "
        "dataset is prototype/non-production data."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, Any]:
    store = get_recipe_store()
    return {
        "status": "ok",
        "recipe_count": store.count,
        "data_file": store.data_file.as_posix(),
        **_data_disclosure(store.data_file),
    }


@app.get("/recipes")
def list_recipes(
    limit: int = Query(default=50, ge=1, le=1000),
    meal_type: str | None = Query(default=None),
) -> list[dict[str, Any]]:
    store = get_recipe_store()
    return store.list_recipes(limit=limit, meal_type=meal_type)


@app.get("/recipes/search")
def search_recipes(
    q: str = Query(..., min_length=1),
    limit: int = Query(default=50, ge=1, le=1000),
    meal_type: str | None = Query(default=None),
) -> list[dict[str, Any]]:
    query = q.strip()
    if not query:
        raise HTTPException(
            status_code=400,
            detail="Query parameter `q` must not be blank.",
        )

    store = get_recipe_store()
    return store.search_recipes(query, limit=limit, meal_type=meal_type)


@app.get("/recipes/{recipe_id}")
def get_recipe(recipe_id: str) -> dict[str, Any]:
    store = get_recipe_store()
    recipe = store.get_recipe(recipe_id)
    if recipe is None:
        raise HTTPException(
            status_code=404,
            detail=f"Recipe `{recipe_id}` was not found.",
        )
    return recipe
