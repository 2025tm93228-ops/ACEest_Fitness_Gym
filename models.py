"""Domain logic for ACEest Fitness & Gym.

Kept free of Flask imports so it can be unit-tested in isolation.
Ported from the ACEest Tkinter prototypes (Aceestver-1.0 .. 3.2.4).
"""

WORKOUT_TYPES = ("Strength", "Hypertrophy", "Cardio", "Mobility", "HIIT")

PROGRAMS = {
    "FL": {
        "code": "FL",
        "name": "Fat Loss",
        "calories": 2000,
        "workout": [
            "Mon: 5x5 Back Squat + AMRAP",
            "Tue: EMOM 20min Assault Bike",
            "Wed: Bench Press + 21-15-9",
            "Thu: 10 RFT Deadlifts / Box Jumps",
            "Fri: 30min Active Recovery",
        ],
        "diet": [
            "Breakfast: 3 egg whites + oats idli",
            "Lunch: Grilled chicken + brown rice",
            "Dinner: Fish curry + millet roti",
        ],
    },
    "MG": {
        "code": "MG",
        "name": "Muscle Gain",
        "calories": 3200,
        "workout": [
            "Mon: Squat 5x5",
            "Tue: Bench Press 5x5",
            "Wed: Deadlift 4x6",
            "Thu: Front Squat 4x8",
            "Fri: Incline Press 4x10",
            "Sat: Barbell Rows 4x10",
        ],
        "diet": [
            "Breakfast: 4 eggs + peanut butter oats",
            "Lunch: Chicken biryani (250g chicken)",
            "Dinner: Mutton curry + jeera rice",
        ],
    },
    "BG": {
        "code": "BG",
        "name": "Beginner",
        "calories": 2400,
        "workout": [
            "Circuit: Air squats, ring rows, push-ups",
            "Focus: technique mastery and form (90% threshold)",
        ],
        "diet": [
            "Balanced meals: idli-sambar, rice-dal, chapati",
            "Protein target: 120g/day",
        ],
    },
}

GYM_METRICS = {"capacity_users": 150, "area_sqft": 10000, "break_even_members": 250}


def list_programs():
    """Return every program, ordered by code."""
    return [PROGRAMS[code] for code in sorted(PROGRAMS)]


def get_program(code):
    """Look up one program by code. Returns None when unknown."""
    if not code:
        return None
    return PROGRAMS.get(str(code).strip().upper())


def calculate_bmi(weight_kg, height_cm):
    """Body Mass Index rounded to 2 decimals.

    Raises ValueError for non-numeric or non-positive input.
    """
    try:
        weight = float(weight_kg)
        height = float(height_cm)
    except (TypeError, ValueError):
        raise ValueError("weight and height must be numeric")
    if weight <= 0 or height <= 0:
        raise ValueError("weight and height must be greater than zero")
    return round(weight / ((height / 100) ** 2), 2)


def bmi_category(bmi):
    """Map a BMI value onto the WHO category labels."""
    bmi = float(bmi)
    if bmi < 18.5:
        return "Underweight"
    if bmi < 25:
        return "Normal"
    if bmi < 30:
        return "Overweight"
    return "Obese"


def recommend_program(bmi):
    """Pick the program code best suited to a BMI value."""
    category = bmi_category(bmi)
    if category == "Underweight":
        return "MG"
    if category == "Normal":
        return "BG"
    return "FL"


def validate_workout(payload):
    """Validate a workout submission.

    Returns (cleaned_dict, errors_list). ``cleaned_dict`` is None when
    ``errors_list`` is non-empty.
    """
    errors = []
    data = payload if isinstance(payload, dict) else {}

    client = str(data.get("client", "")).strip()
    if not client:
        errors.append("client is required")

    workout_type = str(data.get("workout_type", "")).strip()
    if workout_type not in WORKOUT_TYPES:
        errors.append("workout_type must be one of: " + ", ".join(WORKOUT_TYPES))

    duration = data.get("duration_min")
    try:
        duration = int(duration)
        if duration <= 0 or duration > 300:
            errors.append("duration_min must be between 1 and 300")
    except (TypeError, ValueError):
        errors.append("duration_min must be an integer")

    if errors:
        return None, errors

    return {
        "client": client,
        "workout_type": workout_type,
        "duration_min": duration,
        "notes": str(data.get("notes", "")).strip(),
    }, []


def adherence_score(completed_sessions, planned_sessions):
    """Percentage of planned sessions actually completed, capped at 100."""
    planned = int(planned_sessions)
    completed = int(completed_sessions)
    if planned <= 0:
        raise ValueError("planned_sessions must be greater than zero")
    if completed < 0:
        raise ValueError("completed_sessions cannot be negative")
    return min(round(completed / planned * 100, 1), 100.0)
