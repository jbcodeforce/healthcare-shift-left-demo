"""Demo backend: REST API for patients, devices, prescriptions; simulation and telemetry SSE."""

import asyncio
import json
import logging
import queue
from contextlib import asynccontextmanager
from typing import Literal

import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, model_validator

from backend.data import get_devices, get_patients, get_prescriptions
from backend.simulation import (
    is_simulation_running,
    set_telemetry_sink,
    start_simulation,
    stop_simulation,
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
    """List prescriptions (demo data aligned with simulation)."""
    return get_prescriptions()


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
    """Stop the device simulation."""
    if stop_simulation():
        return {"status": "stopped", "message": "Device simulation stopped."}
    raise HTTPException(status_code=409, detail="Simulation was not running.")


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


def run() -> None:
    uvicorn.run(
        "backend.main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
    )


if __name__ == "__main__":
    run()
