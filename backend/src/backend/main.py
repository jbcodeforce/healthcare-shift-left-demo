"""Demo backend: REST API for patients, devices, prescriptions; simulation and telemetry SSE."""

import asyncio
import json
import logging
import queue
from contextlib import asynccontextmanager
from typing import Literal

import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, model_validator

from backend.analytics import (
    get_config_changes_over_time,
    get_dashboard_data,
    get_new_devices_over_time,
    get_anomalies_per_device,
    _is_configured as analytics_configured,
)
from backend.data import get_devices, get_patients, get_prescriptions
from backend.db import (
    count_prescriptions,
    create_prescription,
    delete_prescription,
    ensure_prescriptions_table,
    get_prescription_by_id,
    get_prescriptions_from_db,
    seed_prescriptions,
    update_prescription,
)
from backend.simulation import (
    get_cached_telemetry,
    is_simulation_running,
    set_telemetry_sink,
    start_simulation,
    stop_simulation,
)
from backend.simulator import (
    run_flow_rate_down,
    run_pressure_oscillate,
    run_flow_level_down,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

_telemetry_queue: queue.Queue = queue.Queue(maxsize=2000)
_sse_subscribers: set[asyncio.Queue] = set()
_sse_subscribers_lock: asyncio.Lock | None = None


async def _broadcast_telemetry() -> None:
    """Drain _telemetry_queue and push each record to all SSE subscriber queues."""
    lock = _sse_subscribers_lock
    if lock is None:
        return
    while True:
        try:
            rec = _telemetry_queue.get_nowait()
        except queue.Empty:
            await asyncio.sleep(0.05)
            continue
        async with lock:
            for q in _sse_subscribers:
                try:
                    q.put_nowait(rec)
                except asyncio.QueueFull:
                    pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _sse_subscribers_lock
    _sse_subscribers_lock = asyncio.Lock()
    set_telemetry_sink(_telemetry_queue)
    task = asyncio.create_task(_broadcast_telemetry())
    # Seed prescriptions table if PostgreSQL is configured and empty
    try:
        ensure_prescriptions_table()
        n = count_prescriptions()
        if n == 0:
            seed_prescriptions(get_prescriptions())
            logger.info("Seeded one prescription per patient to PostgreSQL")
        elif n > 0:
            logger.info("Prescriptions table already has %d rows", n)
    except Exception as e:
        logger.debug("Prescriptions seed skipped or failed: %s", e)
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
    set_telemetry_sink(None)


app = FastAPI(
    title="Healthcare Demo Backend",
    description="REST API for patients, devices, prescriptions; device telemetry simulation and SSE stream.",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS so frontend on another origin (e.g. port) can POST; avoids 405 on OPTIONS preflight
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000", "http://127.0.0.1:5173", "http://127.0.0.1:3000"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log each request method, path, and response status (no body/PII)."""
    response = await call_next(request)
    logger.info("%s %s %s", request.method, request.url.path, response.status_code)
    return response


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


# ---------- Patients, Devices, Prescriptions (REST) ----------


@app.get("/patients")
def list_patients() -> list[dict]:
    """List patients (demo data aligned with simulation)."""
    return get_patients()


@app.get("/devices")
def list_devices() -> list[dict]:
    """List devices (demo data aligned with simulation)."""
    return get_devices()


@app.get("/prescriptions")
def list_prescriptions() -> list[dict]:
    """List prescriptions from PostgreSQL if configured, else in-memory demo data."""
    rows = get_prescriptions_from_db()
    if rows is not None:
        return rows
    return get_prescriptions()


def _prescriptions_db_required():
    """Raise 503 if prescriptions are not backed by DB (CRUD not available)."""
    if get_prescriptions_from_db() is None:
        raise HTTPException(
            status_code=503,
            detail="Prescriptions CRUD requires PostgreSQL; configure DATABASE_URL.",
        )


class PrescriptionParameter(BaseModel):
    parameter_name: str
    parameter_value: float
    parameter_type: str = "float"
    parameter_tolerance: float


class PrescriptionCreate(BaseModel):
    prescription_id: str | None = None
    patient_id: str
    device_id: str
    medication_or_therapy: str | None = None
    start_date: int | None = None
    end_date: int | None = None
    parameters: str | list[PrescriptionParameter] = "[]"

    def to_row(self) -> dict:
        params = self.parameters
        if isinstance(params, list):
            params = json.dumps([p.model_dump() for p in params])
        return {
            "prescriptionId": self.prescription_id,
            "patientId": self.patient_id,
            "deviceId": self.device_id,
            "medicationOrTherapy": self.medication_or_therapy or "",
            "startDate": self.start_date,
            "endDate": self.end_date,
            "parameters": params,
        }


class PrescriptionUpdate(BaseModel):
    patient_id: str | None = None
    device_id: str | None = None
    medication_or_therapy: str | None = None
    start_date: int | None = None
    end_date: int | None = None
    parameters: str | list[PrescriptionParameter] | None = None

    def to_row(self) -> dict:
        row: dict = {}
        if self.patient_id is not None:
            row["patientId"] = self.patient_id
        if self.device_id is not None:
            row["deviceId"] = self.device_id
        if self.medication_or_therapy is not None:
            row["medicationOrTherapy"] = self.medication_or_therapy
        if self.start_date is not None:
            row["startDate"] = self.start_date
        if self.end_date is not None:
            row["endDate"] = self.end_date
        if self.parameters is not None:
            if isinstance(self.parameters, list):
                row["parameters"] = json.dumps([p.model_dump() if hasattr(p, "model_dump") else p for p in self.parameters])
            else:
                row["parameters"] = self.parameters
        return row


@app.get("/prescriptions/{prescription_id}")
def get_prescription(prescription_id: str) -> dict:
    """Get one prescription by ID. Requires PostgreSQL."""
    _prescriptions_db_required()
    row = get_prescription_by_id(prescription_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Prescription not found")
    return row


@app.post("/prescriptions", status_code=201)
def create_prescription_endpoint(body: PrescriptionCreate) -> dict:
    """Create a new prescription. Requires PostgreSQL."""
    _prescriptions_db_required()
    row = create_prescription(body.to_row())
    if row is None:
        raise HTTPException(status_code=409, detail="Create failed (e.g. duplicate prescription_id)")
    return row


@app.put("/prescriptions/{prescription_id}")
def update_prescription_endpoint(prescription_id: str, body: PrescriptionUpdate) -> dict:
    """Update a prescription by ID. Requires PostgreSQL."""
    _prescriptions_db_required()
    row = update_prescription(prescription_id, body.to_row())
    if row is None:
        raise HTTPException(status_code=404, detail="Prescription not found")
    return row


@app.delete("/prescriptions/{prescription_id}")
def delete_prescription_endpoint(prescription_id: str) -> dict:
    """Delete a prescription by ID. Requires PostgreSQL."""
    _prescriptions_db_required()
    if not delete_prescription(prescription_id):
        raise HTTPException(status_code=404, detail="Prescription not found")
    return {"status": "deleted", "prescriptionId": prescription_id}


# ---------- Simulation (existing) ----------


@app.get("/simulation/status")
def simulation_status() -> dict[str, bool]:
    return {"running": is_simulation_running()}


class SimulationStartRequest(BaseModel):
    patient_id: str | None = None
    simulation_type: Literal["all", "single"] = "all"

    @model_validator(mode="after")
    def patient_id_required_for_single(self) -> "SimulationStartRequest":
        if self.simulation_type == "single" and not self.patient_id:
            raise ValueError("patient_id is required when simulation_type is 'single'")
        return self


@app.post("/simulation/start")
def simulation_start(body: SimulationStartRequest | None = None) -> dict[str, str]:
    """Start the device simulation."""
    req = body or SimulationStartRequest()
    if start_simulation(patient_id=req.patient_id, simulation_type=req.simulation_type):
        msg = "Device simulation is running."
        if req.simulation_type == "single" and req.patient_id:
            msg = f"Device simulation is running for patient_id={req.patient_id}."
        return {"status": "started", "message": msg}
    raise HTTPException(status_code=409, detail="Simulation is already running.")


@app.post("/simulation/stop")
def simulation_stop() -> dict[str, str]:
    """Stop the device simulation. Idempotent: always 200 so clients can sync UI."""
    if stop_simulation():
        return {"status": "stopped", "message": "Device simulation stopped."}
    return {"status": "stopped", "message": "Simulation was already stopped."}


# ---------- Device simulator (scenario per device) ----------

SimulatorType = Literal["flow_level_down", "pressure_oscillate", "flow_rate_down"]


@app.post("/device/{device_id}/simulator/{sim_type}")
def device_simulator(device_id: str, sim_type: SimulatorType) -> dict[str, str]:
    """Run a one-shot scenario for a device: stop_motor, pressure_oscillate, or flow_rate_down."""
    devices = get_devices()
    known_ids = {d["device_id"] for d in devices}
    if device_id not in known_ids:
        raise HTTPException(status_code=404, detail="Device not found")
    try:
        if sim_type == "flow_level_down":
            run_flow_level_down(device_id)
            msg = f"flow_level_down scenario sent for device {device_id}."
        elif sim_type == "pressure_oscillate":
            run_pressure_oscillate(device_id)
            msg = f"Pressure up/down scenario sent for device {device_id}."
        else:
            run_flow_rate_down(device_id)
            msg = f"Flow rate down scenario sent for device {device_id}."
        return {"status": "ok", "message": msg}
    except ValueError as e:
        logger.warning("Simulator producer init failed: %s", e)
        raise HTTPException(
            status_code=503,
            detail="Telemetry backend unavailable (Kafka).",
        ) from e
    except Exception as e:
        logger.exception("Simulator failed for %s: %s", device_id, e)
        raise HTTPException(status_code=500, detail=str(e)) from e


# ---------- Telemetry SSE (existing) ----------


async def _telemetry_sse_generator(request: Request):
    q: asyncio.Queue = asyncio.Queue(maxsize=256)
    lock = _sse_subscribers_lock
    if lock is None:
        return
    async with lock:
        _sse_subscribers.add(q)
    try:
        while True:
            if await request.is_disconnected():
                break
            try:
                rec = await asyncio.wait_for(q.get(), timeout=15.0)
            except asyncio.TimeoutError:
                yield "event: ping\ndata: \n\n"
                continue
            yield f"event: telemetry\ndata: {json.dumps(rec)}\n\n"
    finally:
        if lock is not None:
            async with lock:
                _sse_subscribers.discard(q)


@app.get("/telemetry/metrics")
def telemetry_metrics() -> list[dict]:
    """Return the last N telemetry records sent to Kafka (for charts)."""
    return get_cached_telemetry()


@app.get("/telemetry/stream")
async def telemetry_stream(request: Request):
    """Stream device telemetry as Server-Sent Events."""
    return StreamingResponse(
        _telemetry_sse_generator(request),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


# ---------- Analytics (S3 Parquet / DuckDB) ----------


@app.get("/analytics/anomalies-per-device")
def analytics_anomalies_per_device() -> dict:
    """Anomaly count per device. Empty list if analytics not configured."""
    if not analytics_configured():
        return {"available": False, "data": [], "message": "Analytics not configured (set ANALYTICS_S3_* or ANALYTICS_LOCAL_PATH)."}
    data = get_anomalies_per_device()
    return {"available": True, "data": data}


@app.get("/analytics/config-changes-over-time")
def analytics_config_changes_over_time() -> dict:
    """Configuration changes per day. Empty list if analytics not configured."""
    if not analytics_configured():
        return {"available": False, "data": [], "message": "Analytics not configured (set ANALYTICS_S3_* or ANALYTICS_LOCAL_PATH)."}
    data = get_config_changes_over_time()
    return {"available": True, "data": data}


@app.get("/analytics/new-devices-over-time")
def analytics_new_devices_over_time() -> dict:
    """New devices first seen per day. Empty list if analytics not configured."""
    if not analytics_configured():
        return {"available": False, "data": [], "message": "Analytics not configured (set ANALYTICS_S3_* or ANALYTICS_LOCAL_PATH)."}
    data = get_new_devices_over_time()
    return {"available": True, "data": data}


@app.get("/analytics/dashboard")
def analytics_dashboard() -> dict:
    """All dashboard metrics in one response."""
    if not analytics_configured():
        return {
            "available": False,
            "anomalies_per_device": [],
            "config_changes_over_time": [],
            "new_devices_over_time": [],
            "message": "Analytics not configured (set ANALYTICS_S3_* or ANALYTICS_LOCAL_PATH).",
        }
    payload = get_dashboard_data()
    return {
        "available": True,
        "anomalies_per_device": payload["anomalies_per_device"],
        "config_changes_over_time": payload["config_changes_over_time"],
        "new_devices_over_time": payload["new_devices_over_time"],
    }


def run() -> None:
    uvicorn.run(
        "backend.main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
    )


if __name__ == "__main__":
    run()
