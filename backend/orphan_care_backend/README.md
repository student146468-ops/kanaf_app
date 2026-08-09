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
