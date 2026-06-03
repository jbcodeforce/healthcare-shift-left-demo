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
            "timezone": "America/Chicago",
        }
        for i, pid in enumerate(ids, start=1)
    ]


# Chicago-area lifecycle state per patient (aligned with device_event_simulation geofences)
_CHICAGO_DEFAULT_LAT = 41.8781
_CHICAGO_DEFAULT_LNG = -87.6298
_SW_VERSIONS = ("1.2.0", "2.0.0")

# softwareVersion, latitude, longitude, batteryLevel (33–90), plugged
_DEVICE_LIFECYCLE: dict[str, dict] = {
    "P001": {
        "sw_version": "1.2.0",
        "latitude": 41.8786,
        "longitude": -87.6293,
        "batteryLevel": 87,
        "plugged": False,
        "hw_model": "RMD-100",
    },
    "P002": {
        "sw_version": "2.0.0",
        "latitude": 41.9219,
        "longitude": -87.6508,
        "batteryLevel": 72,
        "plugged": False,
        "hw_model": "RMD-100",
    },
    "P003": {
        "sw_version": "1.2.0",
        "latitude": 41.9489,
        "longitude": -87.6558,
        "batteryLevel": 45,
        "plugged": False,
        "hw_model": "RMD-110",
    },
    "P004": {
        "sw_version": "2.0.0",
        "latitude": 41.7948,
        "longitude": -87.5901,
        "batteryLevel": 90,
        "plugged": True,
        "hw_model": "RMD-110",
    },
    "P005": {
        "sw_version": "1.2.0",
        "latitude": 41.8566,
        "longitude": -87.6244,
        "batteryLevel": 33,
        "plugged": False,
        "hw_model": "RMD-110",
    },
}


def _lifecycle_for_patient(patient_id: str, index: int) -> dict:
    """Return device lifecycle fields; use defaults for patients beyond the demo set."""
    if patient_id in _DEVICE_LIFECYCLE:
        return dict(_DEVICE_LIFECYCLE[patient_id])
    battery = min(90, max(33, 33 + (index * 11) % 58))
    return {
        "sw_version": _SW_VERSIONS[index % len(_SW_VERSIONS)],
        "latitude": _CHICAGO_DEFAULT_LAT,
        "longitude": _CHICAGO_DEFAULT_LNG,
        "batteryLevel": battery,
        "plugged": battery >= 50,
    }


def get_devices() -> list[dict]:
    """Return list of devices (one per patient) aligned with simulation and BBH device events."""
    patients = get_patients()
    out: list[dict] = []
    for i, p in enumerate(patients):
        pid = p["patientId"]
        lifecycle = _lifecycle_for_patient(pid, i)
        out.append(
            {
                "device_id": _device_id(pid),
                "patientId": pid,
                "pressureSetting": 10.0 + (i % 3),
                "flowRateSetting": 2.5 + (i % 3) * 0.2,
                "flowLevelSetting": 120.0 + (i % 4) * 40.0,
                "flowLevel": 120.0 + (i % 4) * 40.0,
                **lifecycle,
            }
        )
    return out


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
        ("FlowLevel", "flowLevelSetting", 50.0),
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
