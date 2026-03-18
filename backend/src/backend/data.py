"""Demo data for patients, devices, and prescriptions. Aligned with simulation IDs and README domain."""

import json
from backend.config import get_settings


def _patient_ids(n: int) -> list[str]:
    return [f"P{i:03d}" for i in range(1, n + 1)]


def _device_id(patient_id: str) -> str:
    return f"DEV-{patient_id}"


# Static names/demographics for demo (same order as _patient_ids(5))
_PATIENT_NAMES = [
    ("Alice Smith", "F", "1980-05-12", "15201"),
    ("Bob Jones", "M", "1975-11-03", "15206"),
    ("Carol White", "F", "1990-02-28", "15217"),
    ("Lindsay Lee", "M", "1988-07-19", "15222"),
    ("Eve Brown", "F", "1982-09-05", "15232"),
]


def get_patients() -> list[dict]:
    """Return list of patients aligned with simulation_num_patients."""
    s = get_settings()
    n = s.simulation_num_patients
    ids = _patient_ids(n)
    # Extend names if n > 5
    names = _PATIENT_NAMES + [
        (f"Patient {i}", "F" if i % 2 == 0 else "M", "1985-01-01", "15200")
        for i in range(6, n + 1)
    ]
    return [
        {
            "patientId": pid,
            "name": names[i - 1][0],
            "gender": names[i - 1][1],
            "birthDate": names[i - 1][2],
            "zipCode": names[i - 1][3],
        }
        for i, pid in enumerate(ids, start=1)
    ]


def get_devices() -> list[dict]:
    """Return list of devices (one per patient) aligned with simulation."""
    patients = get_patients()
    # Default settings similar to README Device class
    return [
        {
            "device_id": _device_id(p["patientId"]),
            "patientId": p["patientId"],
            "pressureSetting": 10.0 + (i % 3),
            "flowRateSetting": 2.5 + (i % 3) * 0.2,
            "motorSpeedSetting": 60 + (i % 3),
        }
        for i, p in enumerate(patients)
    ]


def get_prescriptions() -> list[dict]:
    """Return one prescription per patient; parameters as JSON string (array of parameter_name, value, type, tolerance)."""
    patients = get_patients()
    devices = get_devices()
    device_by_patient = {d["patientId"]: d for d in devices}
    base_ts = 1710000000000
    end_ts = 1741536000000
    metrics = [
        ("Pressure", "pressureSetting", 1.0),
        ("FlowRate", "flowRateSetting", 0.5),
        ("MotorSpeed", "motorSpeedSetting", 50.0),
    ]
    out = []
    for p in patients:
        patient_id = p["patientId"]
        d = device_by_patient.get(patient_id)
        if not d:
            continue
        params = []
        for metric_name, key, tolerance in metrics:
            target = d[key] if key else 100.0
            params.append({
                "parameter_name": metric_name,
                "parameter_value": target,
                "parameter_type": "float",
                "parameter_tolerance": tolerance,
            })
        out.append({
            "prescriptionId": f"RX-{d['device_id']}",
            "patientId": patient_id,
            "deviceId": d["device_id"],
            "medicationOrTherapy": "CPAP Oxygen Flow",
            "startDate": base_ts,
            "endDate": end_ts,
            "parameters": json.dumps(params),
        })
    return out
