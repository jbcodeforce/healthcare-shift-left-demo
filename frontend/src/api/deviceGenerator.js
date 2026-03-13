// In dev, use /api so Vite proxies to backend (no CORS). Otherwise use VITE_API_URL or backend on port 8000.
const baseUrl = import.meta.env.VITE_API_URL ?? (import.meta.env.DEV ? '' : 'http://localhost:8000')
const apiBase = baseUrl ? `${baseUrl.replace(/\/$/, '')}` : '/api'

export async function getPatients() {
  const res = await fetch(`${apiBase}/patients`)
  if (!res.ok) throw new Error(`Patients failed: ${res.status}`)
  return res.json()
}

export async function getDevices() {
  const res = await fetch(`${apiBase}/devices`)
  if (!res.ok) throw new Error(`Devices failed: ${res.status}`)
  return res.json()
}

export async function getPrescriptions() {
  const res = await fetch(`${apiBase}/prescriptions`)
  if (!res.ok) throw new Error(`Prescriptions failed: ${res.status}`)
  return res.json()
}

export async function getPrescription(prescriptionId) {
  const res = await fetch(`${apiBase}/prescriptions/${encodeURIComponent(prescriptionId)}`)
  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(err.detail || `Prescription failed: ${res.status}`)
  }
  return res.json()
}

/**
 * Create a new prescription. Body: { prescriptionId?, patientId, deviceId, medicationOrTherapy?, startDate?, endDate?, parameters }
 * parameters can be JSON string (array) or array of { parameter_name, parameter_value, parameter_type?, parameter_tolerance? }
 */
export async function createPrescription(body) {
  const payload = {
    prescription_id: body.prescriptionId ?? null,
    patient_id: body.patientId,
    device_id: body.deviceId,
    medication_or_therapy: body.medicationOrTherapy ?? '',
    start_date: body.startDate ?? null,
    end_date: body.endDate ?? null,
    parameters: typeof body.parameters === 'string' ? body.parameters : JSON.stringify(body.parameters ?? []),
  }
  const res = await fetch(`${apiBase}/prescriptions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(err.detail || `Create failed: ${res.status}`)
  }
  return res.json()
}

/**
 * Update prescription by id. Body: same shape as create (partial ok).
 */
export async function updatePrescription(prescriptionId, body) {
  const payload = {}
  if (body.patientId !== undefined) payload.patient_id = body.patientId
  if (body.deviceId !== undefined) payload.device_id = body.deviceId
  if (body.medicationOrTherapy !== undefined) payload.medication_or_therapy = body.medicationOrTherapy
  if (body.startDate !== undefined) payload.start_date = body.startDate
  if (body.endDate !== undefined) payload.end_date = body.endDate
  if (body.parameters !== undefined) {
    payload.parameters = typeof body.parameters === 'string' ? body.parameters : JSON.stringify(body.parameters)
  }
  const res = await fetch(`${apiBase}/prescriptions/${encodeURIComponent(prescriptionId)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(err.detail || `Update failed: ${res.status}`)
  }
  return res.json()
}

export async function deletePrescription(prescriptionId) {
  const res = await fetch(`${apiBase}/prescriptions/${encodeURIComponent(prescriptionId)}`, {
    method: 'DELETE',
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(err.detail || `Delete failed: ${res.status}`)
  }
  return res.json()
}

export async function getSimulationStatus() {
  const res = await fetch(`${apiBase}/simulation/status`)
  if (!res.ok) throw new Error(`Simulation status failed: ${res.status}`)
  return res.json()
}

export async function startSimulation(body = { simulation_type: 'all' }) {
  const res = await fetch(`${apiBase}/simulation/start`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(err.detail || `Start failed: ${res.status}`)
  }
  return res.json()
}

export async function stopSimulation() {
  const res = await fetch(`${apiBase}/simulation/stop`, { method: 'POST' })
  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(err.detail || `Stop failed: ${res.status}`)
  }
  return res.json()
}

/**
 * Fetch last N telemetry records sent to Kafka (for metrics charts).
 * @returns { Promise<Array<{ device_id, patient_id, ts, metric_name, metric_value, software_version }>> }
 */
export async function getTelemetryMetrics() {
  const res = await fetch(`${apiBase}/telemetry/metrics`)
  if (!res.ok) throw new Error(`Telemetry metrics failed: ${res.status}`)
  return res.json()
}

/**
 * Subscribe to device telemetry SSE stream. Calls onEvent(parsedData) for each "telemetry" event.
 * Returns an abort function to close the stream.
 * @param { (data: object) => void } onEvent
 * @returns { () => void } abort
 */
export function subscribeTelemetryStream(onEvent) {
  const url = `${apiBase}/telemetry/stream`
  const eventSource = new EventSource(url)

  eventSource.addEventListener('telemetry', (e) => {
    try {
      const data = JSON.parse(e.data)
      onEvent(data)
    } catch (_) {
      // ignore parse errors
    }
  })

  return () => {
    eventSource.close()
  }
}
