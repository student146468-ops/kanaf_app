# Kanaf Backend

## Overview

Django REST backend for the Kanaf orphan-care platform. The active API supports JWT authentication, user profile lookup, CRUD endpoints for orphans, donations, volunteers, sponsors, inventory, dashboard statistics, reports, OpenAPI schema, Swagger UI, and health checks.

## Local Setup

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py test
python manage.py runserver 0.0.0.0:8000
```

## Required Environment

Copy `.env.example` to `.env` for container deployments and set:

- `SECRET_KEY`: long random value, at least 50 characters.
- `DEBUG`: `False` outside local development.
- `ALLOWED_HOSTS`: API hostnames.
- `CSRF_TRUSTED_ORIGINS`: trusted HTTPS origins.
- `CORS_ALLOWED_ORIGINS`: frozen frontend origins.
- `DATABASE_URL`: PostgreSQL URL for production.
- `LOG_LEVEL`: normally `INFO`.

## API Contract

- `POST /api/auth/register/`
- `POST /api/auth/login/`
- `POST /api/auth/refresh/`
- `POST /api/auth/logout/`
- `GET /api/auth/me/`
- `GET /api/health/`
- `GET /api/health/live/`
- `GET /api/health/ready/`
- `GET /api/schema/`
- `GET /api/docs/`
- `GET|POST /api/orphans/`
- `GET|POST /api/donations/`
- `GET /api/donations/my-donations/`
- `GET|POST /api/volunteers/`
- `POST /api/volunteers/apply/`
- `GET|POST /api/volunteer-opportunities/`
- `POST /api/volunteer-opportunities/{id}/apply/`
- `GET|POST /api/volunteer-applications/`
- `POST /api/volunteer-applications/{id}/approve/`
- `POST /api/volunteer-applications/{id}/reject/`
- `GET|POST /api/sponsors/`
- `GET|POST /api/inventory/`
- `GET|POST /api/care-homes/`
- `GET|POST /api/notifications/`
- `GET /api/notifications/unread_count/`
- `POST /api/notifications/{id}/mark_as_read/`
- `GET /api/profiles/`
- `GET /api/stats/dashboard/`
- `GET /api/reports/`

List endpoints intentionally return arrays for frozen Flutter compatibility.

## Production Deployment

```bash
cp .env.example .env
# edit .env secrets and domains
docker compose up --build -d
docker compose exec web python manage.py migrate
docker compose exec web python manage.py collectstatic --noinput
docker compose exec web python manage.py check --deploy
```

The compose stack includes Django/Gunicorn, PostgreSQL, nginx, persistent media/static/log volumes, and health checks.

## Quality Gates

```bash
python manage.py check
python manage.py check --deploy
python manage.py makemigrations --check --dry-run
python manage.py spectacular --validate --file schema.yml
python manage.py test
```

## Backup

Use `scripts/backup_db.py` and `scripts/restore_db.py`. See `backup_restore.md`.

## PythonAnywhere: care-home identity update

The target care-home name is `دار الطفل أبوهريدة` and its address is `طرابلس`.
The existing record must be updated in the database used by the web app; do not
upload a local SQLite file over production. The rename preserves its primary key,
manager, contacts and linked needs, donations, volunteer opportunities and visits.

In a Bash console, activate the same virtualenv configured on the **Web** tab and
use the same environment variables / private `.env` as the web app. Then run:

```bash
cd /home/kanafapp/kanaf-app
git status --short
git pull --ff-only origin main
bash backend/orphan_care_backend/scripts/deploy_pythonanywhere.sh
```

The script backs up the active SQLite or PostgreSQL database, runs migrations,
renames the existing home, collects static files and runs Django checks. It stops
if any step fails. A PostgreSQL backup requires `pg_dump` installed on the server.
Preserve server-local code changes before pulling; do not use a hard reset or
replace the database. If this checkout lives at another path, use that path.

When multiple homes exist, the command lists them and stops without renaming one.
Select the correct existing record explicitly and rerun the script:

```bash
bash backend/orphan_care_backend/scripts/deploy_pythonanywhere.sh --care-home-id 7
```

Replace `7` with the actual record ID. To inspect the selected home before applying:

```bash
cd backend/orphan_care_backend
python manage.py rename_care_home --care-home-id 7
```

Finally click **Reload** on the PythonAnywhere **Web** tab. Sign in and check
`/settings/`, linked donations, opportunities and a completed volunteer certificate.
Rebuild/install the Flutter app to receive its updated screens; a backend reload
does not update an installed APK. `جامعة غريان` remains the university affiliation.

Certificate dates are persisted on the first completion. For historical completed
applications, migration `0020` freezes their previously recorded `updated_at` as
the best available historical date; the original completion time was not stored
separately. Later ratings or edits no longer change the displayed issue date.
