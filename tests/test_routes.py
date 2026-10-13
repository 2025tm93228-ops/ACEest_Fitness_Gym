"""Integration tests for the Flask routes using the test client."""


class TestHealthAndPages:
    def test_health_endpoint(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        assert response.get_json()["status"] == "healthy"

    def test_dashboard_renders(self, client):
        response = client.get("/")
        assert response.status_code == 200
        assert b"ACEest Functional Fitness" in response.data
        assert b"Fat Loss" in response.data

    def test_unknown_page_returns_404(self, client):
        assert client.get("/no-such-page").status_code == 404

    def test_unknown_api_path_returns_json_404(self, client):
        response = client.get("/api/nope")
        assert response.status_code == 404
        assert response.get_json()["error"] == "resource not found"


class TestProgramEndpoints:
    def test_list_programs(self, client):
        payload = client.get("/api/programs").get_json()
        assert payload["count"] == 3
        assert {p["code"] for p in payload["programs"]} == {"FL", "MG", "BG"}

    def test_single_program(self, client):
        payload = client.get("/api/programs/MG").get_json()
        assert payload["name"] == "Muscle Gain"
        assert payload["calories"] == 3200

    def test_unknown_program_returns_404(self, client):
        response = client.get("/api/programs/ZZ")
        assert response.status_code == 404
        assert "unknown program" in response.get_json()["error"]


class TestBmiEndpoint:
    def test_valid_assessment(self, client):
        response = client.post("/api/bmi", json={"weight": 70, "height": 175})
        assert response.status_code == 200
        payload = response.get_json()
        assert payload["bmi"] == 22.86
        assert payload["category"] == "Normal"
        assert payload["recommended_program"]["code"] == "BG"

    def test_obese_input_recommends_fat_loss(self, client):
        payload = client.post("/api/bmi", json={"weight": 110, "height": 170}).get_json()
        assert payload["category"] == "Obese"
        assert payload["recommended_program"]["code"] == "FL"

    def test_invalid_input_returns_400(self, client):
        response = client.post("/api/bmi", json={"weight": 0, "height": 175})
        assert response.status_code == 400
        assert "error" in response.get_json()

    def test_empty_body_returns_400(self, client):
        assert client.post("/api/bmi", json={}).status_code == 400

    def test_get_is_not_allowed(self, client):
        assert client.get("/api/bmi").status_code == 405


class TestAdherenceEndpoint:
    def test_on_track(self, client):
        payload = client.post(
            "/api/adherence", json={"completed_sessions": 9, "planned_sessions": 10}
        ).get_json()
        assert payload["adherence_pct"] == 90.0
        assert payload["on_track"] is True

    def test_off_track(self, client):
        payload = client.post(
            "/api/adherence", json={"completed_sessions": 2, "planned_sessions": 10}
        ).get_json()
        assert payload["on_track"] is False

    def test_invalid_input_returns_400(self, client):
        response = client.post(
            "/api/adherence", json={"completed_sessions": 1, "planned_sessions": 0}
        )
        assert response.status_code == 400


class TestWorkoutEndpoints:
    def test_list_is_empty_initially(self, client):
        payload = client.get("/api/workouts").get_json()
        assert payload == {"count": 0, "workouts": []}

    def test_log_workout_returns_201(self, client):
        response = client.post(
            "/api/workouts",
            json={"client": "Ravi", "workout_type": "Strength", "duration_min": 45},
        )
        assert response.status_code == 201
        workout = response.get_json()["workout"]
        assert workout["client"] == "Ravi"
        assert workout["id"] == 1

    def test_logged_workout_is_persisted(self, client, logged_workout):
        payload = client.get("/api/workouts").get_json()
        assert payload["count"] == 1
        assert payload["workouts"][0]["client"] == logged_workout["client"]

    def test_invalid_workout_returns_400_and_is_not_stored(self, client):
        response = client.post("/api/workouts", json={"client": "", "duration_min": -1})
        assert response.status_code == 400
        assert response.get_json()["errors"]
        assert client.get("/api/workouts").get_json()["count"] == 0

    def test_summary_aggregates_by_type(self, client):
        for workout_type, minutes in [("Cardio", 30), ("Cardio", 20), ("Strength", 60)]:
            client.post(
                "/api/workouts",
                json={"client": "Ravi", "workout_type": workout_type, "duration_min": minutes},
            )
        payload = client.get("/api/workouts/summary").get_json()
        assert payload["total_sessions"] == 3
        assert payload["total_minutes"] == 110
        assert payload["by_type"]["Cardio"] == {"sessions": 2, "minutes": 50}

    def test_summary_is_zeroed_when_empty(self, client):
        payload = client.get("/api/workouts/summary").get_json()
        assert payload["total_sessions"] == 0
        assert payload["total_minutes"] == 0

    def test_delete_workout(self, client, logged_workout):
        response = client.delete(f"/api/workouts/{logged_workout['id']}")
        assert response.status_code == 200
        assert client.get("/api/workouts").get_json()["count"] == 0

    def test_delete_missing_workout_returns_404(self, client):
        assert client.delete("/api/workouts/999").status_code == 404

    def test_databases_are_isolated_between_tests(self, client):
        assert client.get("/api/workouts").get_json()["count"] == 0
