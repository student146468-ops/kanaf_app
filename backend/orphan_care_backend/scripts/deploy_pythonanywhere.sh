#!/usr/bin/env bash
set -euo pipefail

# Run after git pull, using the same virtualenv configured on the Web tab.
if [[ -z "${VIRTUAL_ENV:-}" && -z "${KANAF_PYTHON:-}" ]]; then
    echo 'Activate the web app virtualenv first, or set KANAF_PYTHON to its Python executable.' >&2
    exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."
kanaf_python="${KANAF_PYTHON:-python}"

# Back up the active database before changing its schema. The rename command
# takes an additional backup and never creates or replaces a care-home record.
"$kanaf_python" manage.py backup_database
"$kanaf_python" manage.py migrate --noinput
"$kanaf_python" manage.py rename_care_home "$@" --apply
"$kanaf_python" manage.py collectstatic --noinput
"$kanaf_python" manage.py check

echo 'Deployment commands succeeded. Click Reload on the PythonAnywhere Web tab.'
