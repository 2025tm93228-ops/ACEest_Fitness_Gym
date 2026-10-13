"""Unit tests for the pure domain logic in models.py."""
import pytest

from models import (
    PROGRAMS,
    WORKOUT_TYPES,
    adherence_score,
    bmi_category,
    calculate_bmi,
    get_program,
    list_programs,
    recommend_program,
    validate_workout,
)


class TestPrograms:
    def test_three_programs_are_defined(self):
        assert len(list_programs()) == 3

    def test_every_program_has_required_fields(self):
        for program in list_programs():
            assert {"code", "name", "calories", "workout", "diet"} <= set(program)
            assert program["workout"] and program["diet"]
            assert program["calories"] > 0

    @pytest.mark.parametrize("code,name", [("FL", "Fat Loss"), ("MG", "Muscle Gain"), ("BG", "Beginner")])
    def test_lookup_by_code(self, code, name):
        assert get_program(code)["name"] == name

    def test_lookup_is_case_insensitive_and_trims(self):
        assert get_program("  fl ") is PROGRAMS["FL"]

    @pytest.mark.parametrize("code", ["XX", "", None])
    def test_unknown_code_returns_none(self, code):
        assert get_program(code) is None


class TestBmi:
    def test_known_value(self):
        # 70 kg at 175 cm -> 22.86
        assert calculate_bmi(70, 175) == 22.86

    def test_accepts_numeric_strings(self):
        assert calculate_bmi("70", "175") == 22.86

    @pytest.mark.parametrize("weight,height", [(0, 175), (70, 0), (-5, 175), ("abc", 175), (None, 175)])
    def test_invalid_input_raises(self, weight, height):
        with pytest.raises(ValueError):
            calculate_bmi(weight, height)

    @pytest.mark.parametrize(
        "bmi,expected",
        [(17.0, "Underweight"), (18.5, "Normal"), (22.0, "Normal"),
         (25.0, "Overweight"), (27.5, "Overweight"), (30.0, "Obese"), (35.0, "Obese")],
    )
    def test_category_boundaries(self, bmi, expected):
        assert bmi_category(bmi) == expected

    @pytest.mark.parametrize("bmi,code", [(17.0, "MG"), (22.0, "BG"), (27.0, "FL"), (33.0, "FL")])
    def test_recommendation_matches_category(self, bmi, code):
        assert recommend_program(bmi) == code


class TestWorkoutValidation:
    def test_valid_payload_is_cleaned(self):
        cleaned, errors = validate_workout(
            {"client": "  Ravi ", "workout_type": "Cardio", "duration_min": "30", "notes": " run "}
        )
        assert errors == []
        assert cleaned == {"client": "Ravi", "workout_type": "Cardio",
                           "duration_min": 30, "notes": "run"}

    def test_missing_client_is_rejected(self):
        cleaned, errors = validate_workout({"workout_type": "Cardio", "duration_min": 30})
        assert cleaned is None
        assert "client is required" in errors

    def test_unknown_type_is_rejected(self):
        _, errors = validate_workout({"client": "A", "workout_type": "Yoga", "duration_min": 30})
        assert any("workout_type" in e for e in errors)

    @pytest.mark.parametrize("duration", [0, -10, 301, "abc", None])
    def test_out_of_range_duration_is_rejected(self, duration):
        _, errors = validate_workout(
            {"client": "A", "workout_type": "Cardio", "duration_min": duration}
        )
        assert any("duration_min" in e for e in errors)

    def test_non_dict_payload_collects_all_errors(self):
        cleaned, errors = validate_workout("not-a-dict")
        assert cleaned is None
        assert len(errors) == 3

    def test_all_declared_types_validate(self):
        for workout_type in WORKOUT_TYPES:
            _, errors = validate_workout(
                {"client": "A", "workout_type": workout_type, "duration_min": 45}
            )
            assert errors == []


class TestAdherence:
    def test_partial_completion(self):
        assert adherence_score(4, 5) == 80.0

    def test_caps_at_one_hundred(self):
        assert adherence_score(7, 5) == 100.0

    def test_zero_completed(self):
        assert adherence_score(0, 5) == 0.0

    @pytest.mark.parametrize("completed,planned", [(1, 0), (-1, 5)])
    def test_invalid_input_raises(self, completed, planned):
        with pytest.raises(ValueError):
            adherence_score(completed, planned)
