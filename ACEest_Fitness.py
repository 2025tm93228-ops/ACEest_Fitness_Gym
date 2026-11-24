"""
ACEest Fitness & Gym - application entry point.

The assignment brief refers to the Flask application as ACEest_Fitness.py, so this
module is the named entry point. The implementation is split across three modules
for testability and to keep responsibilities separate:

    models.py  - pure domain logic (no Flask imports, unit-tested in isolation)
    db.py      - SQLite persistence bound to the Flask request lifecycle
    app.py     - the application factory, routes and error handlers

Run directly:
    python3 ACEest_Fitness.py

Run under a production WSGI server (as the Docker image does):
    gunicorn --bind 0.0.0.0:5000 ACEest_Fitness:app

The original Tkinter prototypes this service was ported from are preserved in
versions/ with a mapping of which prototype concept became which module.
"""
import os

from app import APP_VERSION, APP_VARIANT, create_app

# Module-level WSGI callable, so `gunicorn ACEest_Fitness:app` works.
app = create_app()

if __name__ == "__main__":
    print(f"ACEest Fitness & Gym  version={APP_VERSION}  variant={APP_VARIANT}")
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)), debug=False)
