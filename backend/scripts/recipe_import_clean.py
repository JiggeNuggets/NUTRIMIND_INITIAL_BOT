#!/usr/bin/env python3
"""Deterministically clean and export a sample of recipes-with-nutrition.

Dependencies:
    pip install datasets pandas

Auth:
    `datahiveai/recipes-with-nutrition` is public, so Hugging Face auth is not
    required. If you hit Hub rate limits, set `HF_TOKEN` or log in with the
    Hugging Face CLI before rerunning the script.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence
from urllib.parse import urlsplit, urlunsplit

try:
    import pandas as pd
    from datasets import load_dataset
except ImportError as exc:  # pragma: no cover - dependency failure is runtime only
    raise SystemExit(
        "Missing dependency. Install with: pip install datasets pandas"
    ) from exc


DATASET_NAME = "datahiveai/recipes-with-nutrition"
DATASET_SPLIT = "train"
DEFAULT_SAMPLE_SIZE = 1000
DEFAULT_SEED = 42
DEFAULT_OUT_DIR = Path("backend/data/recipes_sample")

FIELD_ALIASES = {
    "daily_values": "total_daily",
    "image_url": "image",
}

PREFERRED_FIELD_ORDER = [
    "recipe_id",
    "recipe_name",
    "ingredient_lines",
    "ingredients",
    "total_nutrients",
    "total_daily",
    "calories",
    "cuisine_type",
    "meal_type",
    "dish_type",
    "diet_labels",
    "health_labels",
    "total_time",
    "servings",
    "yield",
    "source",
    "url",
    "image",
    "total_weight_g",
    "cautions",
    "digest",
]

DEDUPLICATION_SCORE = {
    "recipe_name": 8,
    "url": 8,
    "ingredient_lines": 6,
    "ingredients": 6,
    "total_nutrients": 5,
    "total_daily": 5,
    "calories": 4,
    "servings": 3,
    "source": 3,
    "image": 2,
    "meal_type": 2,
    "dish_type": 2,
    "cuisine_type": 2,
    "diet_labels": 1,
    "health_labels": 1,
}


@dataclass(frozen=True)
class ExportPaths:
    out_dir: Path
    json_path: Path
    csv_path: Path
    schema_path: Path


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Download, clean, deduplicate, and export a deterministic sample "
            "from the Hugging Face dataset "
            f"`{DATASET_NAME}`."
        )
    )
    parser.add_argument(
        "--sample-size",
        type=int,
        default=DEFAULT_SAMPLE_SIZE,
        help=f"Number of cleaned recipes to export (default: {DEFAULT_SAMPLE_SIZE}).",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=DEFAULT_SEED,
        help=f"Seed used for deterministic sampling (default: {DEFAULT_SEED}).",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=DEFAULT_OUT_DIR,
        help=f"Directory to receive exported files (default: {DEFAULT_OUT_DIR}).",
    )
    args = parser.parse_args(argv)
    if args.sample_size < 1:
        parser.error("--sample-size must be at least 1.")
    return args


def snake_case(value: str) -> str:
    text = value.strip()
    text = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", text)
    text = re.sub(r"[^0-9A-Za-z]+", "_", text)
    text = re.sub(r"_+", "_", text)
    return text.strip("_").lower()


def canonicalize_column_name(name: str) -> str:
    normalized = snake_case(name)
    return FIELD_ALIASES.get(normalized, normalized)


def unique_preserve_order(items: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    ordered: list[str] = []
    for item in items:
        if not item or item in seen:
            continue
        seen.add(item)
        ordered.append(item)
    return ordered


def collapse_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip())


def parse_maybe_structured(value: Any) -> Any:
    if not isinstance(value, str):
        return value

    text = value.strip()
    if not text:
        return ""

    lowered = text.lower()
    if lowered in {"none", "null", "nan", "n/a"}:
        return None

    if (text.startswith("[") and text.endswith("]")) or (
        text.startswith("{") and text.endswith("}")
    ):
        for parser in (json.loads, ast.literal_eval):
            try:
                return parser(text)
            except (ValueError, SyntaxError):
                continue

    return text


def is_empty_value(value: Any) -> bool:
    if value is None:
        return True
    if isinstance(value, str):
        return value.strip() == ""
    if isinstance(value, float):
        return not math.isfinite(value)
    if isinstance(value, Mapping):
        return not value or all(is_empty_value(item) for item in value.values())
    if isinstance(value, (list, tuple, set)):
        return not value or all(is_empty_value(item) for item in value)
    return False


def dedupe_scalar_list(values: list[Any]) -> list[Any]:
    seen: set[tuple[str, str]] = set()
    deduped: list[Any] = []
    for value in values:
        marker = (type(value).__name__, json.dumps(value, ensure_ascii=False, sort_keys=True))
        if marker in seen:
            continue
        seen.add(marker)
        deduped.append(value)
    return deduped


def make_json_compatible(value: Any) -> Any:
    value = parse_maybe_structured(value)

    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        if not math.isfinite(value):
            return None
        return int(value) if value.is_integer() else value
    if isinstance(value, str):
        text = collapse_whitespace(value)
        return text or None
    if hasattr(value, "item") and callable(value.item):
        try:
            return make_json_compatible(value.item())
        except (TypeError, ValueError):
            pass
    if isinstance(value, Mapping):
        cleaned: dict[str, Any] = {}
        for key, item in value.items():
            key_text = collapse_whitespace(str(key))
            cleaned_item = make_json_compatible(item)
            if is_empty_value(cleaned_item):
                continue
            cleaned[key_text] = cleaned_item
        return cleaned
    if isinstance(value, (list, tuple, set)):
        cleaned_list = [
            cleaned_item
            for cleaned_item in (make_json_compatible(item) for item in value)
            if not is_empty_value(cleaned_item)
        ]
        if all(not isinstance(item, (Mapping, list)) for item in cleaned_list):
            return dedupe_scalar_list(cleaned_list)
        return cleaned_list
    if isinstance(value, Path):
        return value.as_posix()
    return collapse_whitespace(str(value))


def normalize_row(raw_row: Mapping[str, Any]) -> dict[str, Any]:
    normalized: dict[str, Any] = {}
    for raw_key, raw_value in raw_row.items():
        column_name = canonicalize_column_name(raw_key)
        cleaned_value = make_json_compatible(raw_value)
        if is_empty_value(cleaned_value):
            continue
        if column_name not in normalized:
            normalized[column_name] = cleaned_value
            continue
        if is_empty_value(normalized[column_name]) and not is_empty_value(cleaned_value):
            normalized[column_name] = cleaned_value
    return normalized


def row_has_meaningful_content(row: Mapping[str, Any]) -> bool:
    if not row:
        return False
    meaningful_fields = (
        "recipe_name",
        "ingredient_lines",
        "ingredients",
        "url",
        "calories",
        "source",
    )
    return any(not is_empty_value(row.get(field)) for field in meaningful_fields)


def normalize_identity_text(value: Any) -> str:
    if value is None:
        return ""
    return collapse_whitespace(str(value)).lower()


def canonicalize_url(value: Any) -> str:
    text = normalize_identity_text(value)
    if not text:
        return ""

    try:
        split = urlsplit(text)
    except ValueError:
        return text

    scheme = split.scheme.lower()
    netloc = split.netloc.lower()
    path = split.path.rstrip("/")
    return urlunsplit((scheme, netloc, path, split.query, ""))


def build_dedupe_key(row: Mapping[str, Any]) -> str:
    name = normalize_identity_text(row.get("recipe_name"))
    url = canonicalize_url(row.get("url"))
    source = normalize_identity_text(row.get("source"))
    ingredient_lines = row.get("ingredient_lines")

    ingredient_marker = ""
    if isinstance(ingredient_lines, list):
        ingredient_marker = "|".join(
            normalize_identity_text(item) for item in ingredient_lines[:5]
        )
    elif ingredient_lines is not None:
        ingredient_marker = normalize_identity_text(ingredient_lines)

    components: list[str] = []
    if name:
        components.append(f"name={name}")
    if url:
        components.append(f"url={url}")
    if not url and ingredient_marker:
        components.append(f"ingredients={ingredient_marker}")
    if not name and source:
        components.append(f"source={source}")

    if not components:
        fallback = json.dumps(
            row,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        components.append(f"fallback={fallback}")

    return "||".join(components)


def build_recipe_id(dedupe_key: str) -> str:
    digest = hashlib.sha1(dedupe_key.encode("utf-8")).hexdigest()
    return f"recipe_{digest[:16]}"


def completeness_score(row: Mapping[str, Any]) -> int:
    score = 0
    for field, weight in DEDUPLICATION_SCORE.items():
        if not is_empty_value(row.get(field)):
            score += weight

    ingredient_lines = row.get("ingredient_lines")
    if isinstance(ingredient_lines, list):
        score += min(len(ingredient_lines), 10)
    ingredients = row.get("ingredients")
    if isinstance(ingredients, list):
        score += min(len(ingredients), 10)

    score += len(row)
    return score


def deduplicate_rows(rows: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    deduped: dict[str, dict[str, Any]] = {}
    for row in rows:
        dedupe_key = build_dedupe_key(row)
        row_with_id = dict(row)
        row_with_id["recipe_id"] = build_recipe_id(dedupe_key)

        existing = deduped.get(dedupe_key)
        if existing is None or completeness_score(row_with_id) > completeness_score(existing):
            deduped[dedupe_key] = row_with_id

    return list(deduped.values())


def deterministic_sample(rows: Sequence[dict[str, Any]], sample_size: int, seed: int) -> list[dict[str, Any]]:
    actual_size = min(sample_size, len(rows))
    ranked = sorted(
        rows,
        key=lambda row: (
            hashlib.sha256(f"{seed}:{row['recipe_id']}".encode("utf-8")).hexdigest(),
            row["recipe_id"],
        ),
    )
    return ranked[:actual_size]


def build_field_order(dataset_columns: Sequence[str], rows: Sequence[Mapping[str, Any]]) -> list[str]:
    normalized_dataset_columns = unique_preserve_order(
        canonicalize_column_name(column) for column in dataset_columns
    )
    discovered_columns = unique_preserve_order(
        key for row in rows for key in row.keys()
    )
    available = unique_preserve_order(
        ["recipe_id", *normalized_dataset_columns, *discovered_columns]
    )

    ordered = [field for field in PREFERRED_FIELD_ORDER if field in available]
    ordered.extend(field for field in available if field not in ordered)
    return ordered


def ordered_row(row: Mapping[str, Any], field_order: Sequence[str]) -> dict[str, Any]:
    return {
        field: row[field]
        for field in field_order
        if field in row and not is_empty_value(row[field])
    }


def csv_safe_value(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, (Mapping, list)):
        return json.dumps(value, ensure_ascii=False, sort_keys=True)
    return value


def infer_json_type(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, Mapping):
        return "object"
    return type(value).__name__


def build_schema(
    sample_rows: Sequence[Mapping[str, Any]],
    field_order: Sequence[str],
    *,
    sample_size_requested: int,
    seed: int,
    original_row_count: int,
    cleaned_row_count: int,
    paths: ExportPaths,
) -> dict[str, Any]:
    fields: list[dict[str, Any]] = []
    total_rows = len(sample_rows)

    for field in field_order:
        present_values = [
            row[field]
            for row in sample_rows
            if field in row and not is_empty_value(row[field])
        ]
        observed_types = unique_preserve_order(
            infer_json_type(value) for value in present_values
        )
        fields.append(
            {
                "name": field,
                "observed_types": observed_types or ["null"],
                "nullable": len(present_values) < total_rows,
                "present_in_rows": len(present_values),
            }
        )

    return {
        "dataset": DATASET_NAME,
        "split": DATASET_SPLIT,
        "sampling": {
            "requested_sample_size": sample_size_requested,
            "exported_sample_size": len(sample_rows),
            "seed": seed,
            "strategy": (
                "Deterministic hash sort by sha256(f'{seed}:{recipe_id}') "
                "after cleaning and deduplication."
            ),
        },
        "row_counts": {
            "original": original_row_count,
            "cleaned": cleaned_row_count,
            "exported": len(sample_rows),
        },
        "output_dir": paths.out_dir.as_posix(),
        "output_files": {
            "json": paths.json_path.name,
            "csv": paths.csv_path.name,
            "schema": paths.schema_path.name,
        },
        "field_order": list(field_order),
        "fields": fields,
    }


def export_files(
    sample_rows: Sequence[Mapping[str, Any]],
    field_order: Sequence[str],
    paths: ExportPaths,
    schema: Mapping[str, Any],
) -> None:
    json_rows = [ordered_row(row, field_order) for row in sample_rows]
    csv_rows = [
        {field: csv_safe_value(row.get(field)) for field in field_order}
        for row in json_rows
    ]

    paths.out_dir.mkdir(parents=True, exist_ok=True)

    with paths.json_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(json_rows, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    dataframe = pd.DataFrame(csv_rows, columns=field_order)
    dataframe.to_csv(paths.csv_path, index=False, encoding="utf-8")

    with paths.schema_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(schema, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def load_and_clean_dataset() -> tuple[list[dict[str, Any]], int, list[str]]:
    try:
        dataset = load_dataset(DATASET_NAME, split=DATASET_SPLIT)
    except Exception as exc:  # pragma: no cover - network/dataset runtime failure
        raise RuntimeError(
            f"Failed to load `{DATASET_NAME}` from Hugging Face: {exc}"
        ) from exc

    original_row_count = len(dataset)
    dataset_columns = list(dataset.column_names)

    cleaned_rows = [
        normalize_row(row)
        for row in dataset
    ]
    non_empty_rows = [
        row for row in cleaned_rows
        if row_has_meaningful_content(row)
    ]
    deduped_rows = deduplicate_rows(non_empty_rows)
    return deduped_rows, original_row_count, dataset_columns


def resolve_paths(out_dir: Path) -> ExportPaths:
    return ExportPaths(
        out_dir=out_dir,
        json_path=out_dir / "recipes_sample.json",
        csv_path=out_dir / "recipes_sample.csv",
        schema_path=out_dir / "schema.json",
    )


def run(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    out_dir = args.out_dir.expanduser()
    paths = resolve_paths(out_dir)

    cleaned_rows, original_row_count, dataset_columns = load_and_clean_dataset()
    cleaned_row_count = len(cleaned_rows)
    if cleaned_row_count == 0:
        raise RuntimeError("No usable rows remained after cleaning and deduplication.")

    sample_rows = deterministic_sample(cleaned_rows, args.sample_size, args.seed)
    field_order = build_field_order(dataset_columns, cleaned_rows)
    schema = build_schema(
        sample_rows,
        field_order,
        sample_size_requested=args.sample_size,
        seed=args.seed,
        original_row_count=original_row_count,
        cleaned_row_count=cleaned_row_count,
        paths=paths,
    )
    export_files(sample_rows, field_order, paths, schema)

    print(f"Original row count: {original_row_count}")
    print(f"Cleaned row count: {cleaned_row_count}")
    print(f"Final exported sample count: {len(sample_rows)}")
    print(f"JSON export: {paths.json_path.resolve()}")
    print(f"CSV export: {paths.csv_path.resolve()}")
    print(f"Schema export: {paths.schema_path.resolve()}")
    return 0


def main() -> None:
    try:
        raise SystemExit(run())
    except Exception as exc:
        print(f"Import failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
