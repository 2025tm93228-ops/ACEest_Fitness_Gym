"""ACEest Fitness & Gym - Flask web application.

Exposes an HTML dashboard plus a JSON API for programs, BMI assessment
and workout logging. Created with an application factory so Pytest can
spin up isolated instances against a temporary database.
"""
import os

from flask import Flask, jsonify, render_template, request

from db import close_db, get_db, init_db
from models import (
    GYM_METRICS,
    WORKOUT_TYPES,
    adherence_score,
    bmi_category,
    calculate_bmi,
    get_program,
    list_programs,
    recommend_program,
    validate_workout,
)

APP_VERSION = "1.0.0"


def create_app(database=None):
    """Build and configure a Flask application instance."""
    app = Flask(__name__)
    app.config["DATABASE"] = database or os.environ.get("ACEEST_DB", "aceest_fitness.db")
    app.config["JSON_SORT_KEYS"] = False

    app.teardown_appcontext(close_db)

    with app.app_context():
        init_db()

    # ---------------- HTML ----------------

    @app.route("/")
    def index():
        return render_template(
            "index.html",
            programs=list_programs(),
            metrics=GYM_METRICS,
            workout_types=WORKOUT_TYPES,
            version=APP_VERSION,
        )

    # ---------------- Health ----------------

    @app.route("/health")
    def health():
        return jsonify(status="healthy", service="aceest-fitness", version=APP_VERSION)

    # ---------------- Programs ----------------

    @app.route("/api/programs")
    def api_programs():
        return jsonify(count=len(list_programs()), programs=list_programs())

    @app.route("/api/programs/<code>")
    def api_program(code):
        program = get_program(code)
        if program is None:
            return jsonify(error=f"unknown program '{code}'"), 404
        return jsonify(program)

    # ---------------- BMI assessment ----------------

    @app.route("/api/bmi", methods=["POST"])
    def api_bmi():
        payload = request.get_json(silent=True) or request.form or {}
        try:
            bmi = calculate_bmi(payload.get("weight"), payload.get("height"))
        except ValueError as exc:
            return jsonify(error=str(exc)), 400
        code = recommend_program(bmi)
        return jsonify(
            bmi=bmi,
            category=bmi_category(bmi),
            recommended_program=get_program(code),
        )

    # ---------------- Adherence ----------------

    @app.route("/api/adherence", methods=["POST"])
    def api_adherence():
        payload = request.get_json(silent=True) or request.form or {}
        try:
            score = adherence_score(
                payload.get("completed_sessions"), payload.get("planned_sessions")
            )
        except (ValueError, TypeError) as exc:
            return jsonify(error=str(exc)), 400
        return jsonify(adherence_pct=score, on_track=score >= 80)

    # ---------------- Workouts ----------------

    @app.route("/api/workouts", methods=["GET"])
    def api_list_workouts():
        rows = get_db().execute(
            "SELECT id, client, workout_type, duration_min, notes, logged_at"
            " FROM workouts ORDER BY id DESC"
        ).fetchall()
        workouts = [dict(row) for row in rows]
        return jsonify(count=len(workouts), workouts=workouts)

    @app.route("/api/workouts", methods=["POST"])
    def api_add_workout():
        payload = request.get_json(silent=True) or request.form or {}
        cleaned, errors = validate_workout(payload)
        if errors:
            return jsonify(errors=errors), 400

        conn = get_db()
        cursor = conn.execute(
            "INSERT INTO workouts (client, workout_type, duration_min, notes)"
            " VALUES (?, ?, ?, ?)",
            (
                cleaned["client"],
                cleaned["workout_type"],
                cleaned["duration_min"],
                cleaned["notes"],
            ),
        )
        conn.commit()
        cleaned["id"] = cursor.lastrowid
        return jsonify(message="workout logged", workout=cleaned), 201

    @app.route("/api/workouts/summary")
    def api_workout_summary():
        rows = get_db().execute(
            "SELECT workout_type, COUNT(*) AS sessions, SUM(duration_min) AS minutes"
            " FROM workouts GROUP BY workout_type ORDER BY workout_type"
        ).fetchall()
        by_type = {r["workout_type"]: {"sessions": r["sessions"], "minutes": r["minutes"]} for r in rows}
        return jsonify(
            total_sessions=sum(v["sessions"] for v in by_type.values()),
            total_minutes=sum(v["minutes"] for v in by_type.values()),
            by_type=by_type,
        )

    @app.route("/api/workouts/<int:workout_id>", methods=["DELETE"])
    def api_delete_workout(workout_id):
        conn = get_db()
        cursor = conn.execute("DELETE FROM workouts WHERE id = ?", (workout_id,))
        conn.commit()
        if cursor.rowcount == 0:
            return jsonify(error=f"workout {workout_id} not found"), 404
        return jsonify(message=f"workout {workout_id} deleted")

    # ---------------- Error handlers ----------------

    @app.errorhandler(404)
    def not_found(error):  # noqa: ARG001
        if request.path.startswith("/api/"):
            return jsonify(error="resource not found", path=request.path), 404
        return render_template("404.html"), 404

    @app.errorhandler(405)
    def method_not_allowed(error):  # noqa: ARG001
        return jsonify(error="method not allowed"), 405

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)), debug=False)
