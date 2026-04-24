# Recipe Import Pipeline

## What this script does

`backend/scripts/recipe_import_clean.py` downloads the public Hugging Face dataset `datahiveai/recipes-with-nutrition`, cleans and normalizes its columns, removes obviously empty rows, deduplicates recipes, and exports a deterministic sample for backend/API or database import workflows.

The script is designed for backend prep work, not direct Flutter ingestion of the raw Hugging Face dataset.

## Dependencies

Install the required Python packages before running:

```bash
pip install datasets pandas
```

Hugging Face auth is not required for this public dataset. Only add `HF_TOKEN` or log in if you run into Hub rate limits or later switch to a gated dataset.

## How to run it

Run the script from the repository root:

```bash
python backend/scripts/recipe_import_clean.py
```

Available CLI flags:

- `--sample-size` default `1000`
- `--seed` default `42`
- `--out-dir` default `backend/data/recipes_sample`

## Example commands

Default export:

```bash
python backend/scripts/recipe_import_clean.py
```

Smaller test sample:

```bash
python backend/scripts/recipe_import_clean.py --sample-size 100 --seed 42
```

Custom output directory:

```bash
python backend/scripts/recipe_import_clean.py --sample-size 500 --seed 7 --out-dir backend/data/recipes_v2
```

## Expected output files

By default the script writes these files under `backend/data/recipes_sample/`:

- `recipes_sample.json`
- `recipes_sample.csv`
- `schema.json`

### File notes

- `recipes_sample.json`: cleaned nested JSON records that are safe to seed into a backend service or document database.
- `recipes_sample.csv`: tabular export of the same sample. Nested fields are serialized as JSON strings so the file stays CSV-compatible.
- `schema.json`: metadata about row counts, deterministic sampling settings, field order, and observed top-level field types.

## Backend usage guidance

Flutter should not load the Hugging Face dataset directly. The backend should ingest the cleaned output from `backend/data/recipes_sample/`, then expose recipe data through your API or database layer.

In this repo, that means the Flutter app should read recipe data indirectly from backend-served endpoints or seeded storage, not from the raw Hugging Face source.

The existing Flutter asset sample at `assets/data/recipes_nutrition_sample.json` can remain a separate client-side prototype fixture. This new script is meant for backend-facing import and normalization work.
