from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


@dataclass(frozen=True)
class IndexedRecipe:
    recipe_id: str
    data: dict[str, Any]
    meal_types: frozenset[str]
    search_text: str


class RecipeStore:
    def __init__(self, data_file: Path) -> None:
        self._data_file = data_file
        self._recipes: list[IndexedRecipe] = []
        self._by_id: dict[str, IndexedRecipe] = {}

    @property
    def data_file(self) -> Path:
        return self._data_file

    @property
    def count(self) -> int:
        return len(self._recipes)

    def load(self) -> None:
        if not self._data_file.exists():
            raise FileNotFoundError(f"Recipe data file was not found: {self._data_file}")

        with self._data_file.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)

        if not isinstance(payload, list):
            raise ValueError("Recipe data file must contain a JSON array.")

        indexed: list[IndexedRecipe] = []
        by_id: dict[str, IndexedRecipe] = {}
        for row in payload:
            if not isinstance(row, dict):
                continue

            recipe_id = self._normalize_text(row.get("recipe_id"))
            if not recipe_id:
                continue

            indexed_recipe = IndexedRecipe(
                recipe_id=recipe_id,
                data=row,
                meal_types=frozenset(self._normalize_strings(row.get("meal_type"))),
                search_text=self._build_search_text(row),
            )
            indexed.append(indexed_recipe)
            by_id[recipe_id] = indexed_recipe

        self._recipes = indexed
        self._by_id = by_id

    def list_recipes(
        self,
        *,
        limit: int,
        meal_type: str | None = None,
    ) -> list[dict[str, Any]]:
        filtered = self._filter_by_meal_type(meal_type)
        return [recipe.data for recipe in filtered[:limit]]

    def search_recipes(
        self,
        query: str,
        *,
        limit: int,
        meal_type: str | None = None,
    ) -> list[dict[str, Any]]:
        normalized_query = self._normalize_text(query)
        if not normalized_query:
            return self.list_recipes(limit=limit, meal_type=meal_type)

        filtered = self._filter_by_meal_type(meal_type)
        matches = [
            recipe.data
            for recipe in filtered
            if normalized_query in recipe.search_text
        ]
        return matches[:limit]

    def get_recipe(self, recipe_id: str) -> dict[str, Any] | None:
        normalized_id = self._normalize_text(recipe_id)
        recipe = self._by_id.get(normalized_id)
        return recipe.data if recipe is not None else None

    def _filter_by_meal_type(self, meal_type: str | None) -> list[IndexedRecipe]:
        normalized_meal_type = self._normalize_text(meal_type)
        if not normalized_meal_type or normalized_meal_type == "all":
            return list(self._recipes)

        return [
            recipe
            for recipe in self._recipes
            if normalized_meal_type in recipe.meal_types
        ]

    def _build_search_text(self, row: dict[str, Any]) -> str:
        values = [
            row.get("recipe_name"),
            row.get("cuisine_type"),
            row.get("ingredient_lines"),
        ]
        parts: list[str] = []
        for value in values:
            parts.extend(self._normalize_strings(value))
        return " ".join(parts)

    def _normalize_strings(self, value: Any) -> list[str]:
        if value is None:
            return []
        if isinstance(value, str):
            normalized = self._normalize_text(value)
            return [normalized] if normalized else []
        if isinstance(value, Iterable):
            normalized_items = [
                normalized
                for item in value
                if (normalized := self._normalize_text(item))
            ]
            return normalized_items
        normalized = self._normalize_text(value)
        return [normalized] if normalized else []

    def _normalize_text(self, value: Any) -> str:
        if value is None:
            return ""
        return " ".join(str(value).strip().lower().split())
