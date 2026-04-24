# NutriMind Backend API

This backend serves recipe data from a configured local JSON file.

The bundled `backend/data/recipes_sample/recipes_sample.json` file is a
prototype/non-production sample created from `datahiveai/recipes-with-nutrition`.
Do not treat it as a production recipe database.

## Install

```bash
pip install -r backend/requirements.txt
```

## Run the API

From the repository root:

```bash
python -m uvicorn backend.app.main:app --reload
```

For local development, the API reads recipe data from:

- `backend/data/recipes_sample/recipes_sample.json`

You can point to a different cleaned file by setting:

```bash
set RECIPE_API_DATA_FILE=backend/data/recipes_sample/recipes_sample.json
```

For production, `RECIPE_API_DATA_FILE` must point to a verified production
dataset. If `RECIPE_API_ENV=production` and the bundled sample file is still
being used, the backend refuses to start unless the prototype override is set:

```bash
set RECIPE_API_ENV=production
set RECIPE_API_DATA_FILE=C:\path\to\verified_recipes.json
```

Only for an explicit prototype deployment:

```bash
set RECIPE_API_ALLOW_SAMPLE_DATA=true
```

## Endpoints

- `GET /health`
- `GET /recipes?limit=50&meal_type=breakfast`
- `GET /recipes/search?q=chicken&limit=25`
- `GET /recipes/{recipe_id}`

## Flutter local development

The Flutter recipe browser is configured for local development like this by default:

- Android emulator: `http://10.0.2.2:8000`
- Web/desktop: `http://localhost:8000`

To override the API URL, run Flutter with:

```bash
flutter run --dart-define=RECIPE_API_BASE_URL=http://localhost:8000
```

For Android emulator:

```bash
flutter run --dart-define=RECIPE_API_BASE_URL=http://10.0.2.2:8000
```

Production Flutter builds must set `RECIPE_API_BASE_URL`. Without it, the app
shows a configuration error instead of silently trying `localhost` or
`10.0.2.2`.

Flutter should consume this backend API, not the raw Hugging Face dataset directly.
