// In dev, use /api so Vite proxies to backend (no CORS). Otherwise use VITE_API_URL or backend on port 8000.
const baseUrl = import.meta.env.VITE_API_URL ?? (import.meta.env.DEV ? '' : 'http://localhost:8000')
const apiBase = baseUrl ? `${baseUrl.replace(/\/$/, '')}` : '/api'

/** Serialize a number for JSON so integers are emitted with .0 (double, not integer). */
function jsonNumber(n) {
  const v = Number(n)
  return Number.isInteger(v) ? `${v}.0` : String(v)
}

/** Stringify parameters array so parameter_value and parameter_tolerance are always sent as floats (with .0). */
function stringifyParameters(parameters) {
  if (parameters == null || !Array.isArray(parameters)) return '[]'
  const parts = parameters.map((p) => {
    const value = jsonNumber(p.parameter_value ?? 0)
    const tolerance = jsonNumber(p.parameter_tolerance ?? 0)
    return `{"parameter_name":${JSON.stringify(p.parameter_name ?? '')},"parameter_value":${value},"parameter_type":${JSON.stringify(p.parameter_type ?? 'float')},"parameter_tolerance":${tolerance}}`
  })
  return '[' + parts.join(',') + ']'
}

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
    parameters: typeof body.parameters === 'string' ? body.parameters : stringifyParameters(body.parameters ?? []),
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
    payload.parameters = typeof body.parameters === 'string' ? body.parameters : stringifyParameters(body.parameters)
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

/** Simulator scenario types. */
const SIMULATOR_TYPES = ['flow_level_down', 'pressure_oscillate', 'flow_rate_down']

/**
 * Trigger a one-shot scenario for a device.
 * @param { string } deviceId - device_id (e.g. DEV-P001)
 * @param { 'flow_level_down' | 'pressure_oscillate' | 'flow_rate_down' } type
 * @returns { Promise<{ status: string, message: string }> }
 */
export async function triggerDeviceSimulation(deviceId, type) {
  if (!SIMULATOR_TYPES.includes(type)) {
    throw new Error(`Invalid simulator type: ${type}`)
  }
  const res = await fetch(
    `${apiBase}/device/${encodeURIComponent(deviceId)}/simulator/${type}`,
    { method: 'POST' }
  )
  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(err.detail || `Simulator failed: ${res.status}`)
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

// ---------- Analytics (S3 Parquet / DuckDB dashboard) ----------

/**
 * Fetch all dashboard metrics in one call.
 * @returns { Promise<{ available: boolean, anomalies_per_device: Array<{ device_id: string, count: number }>, config_changes_over_time: Array<{ date: string, count: number }>, new_devices_over_time: Array<{ date: string, count: number }>, message?: string }> }
 */
export async function getDashboardData() {
  const res = await fetch(`${apiBase}/analytics/dashboard`)
  if (!res.ok) throw new Error(`Analytics failed: ${res.status}`)
  return res.json()
}

/**
 * Live counts from hc_fct_telemetry_1h consumed in this backend (Kafka consumer).
 * @returns { Promise<{ consumer_enabled: boolean, topic: string, windows_received: number, total_readings_in_windows: number, by_device: Array<{ device_id: string, count: number }>, by_metric: Array<{ metric_name: string, count: number }>, last_message_at: string | null }> }
 */
export async function getTelemetry1hCounts() {
  const res = await fetch(`${apiBase}/analytics/telemetry-1h-counts`)
  if (!res.ok) throw new Error(`Telemetry 1h counts failed: ${res.status}`)
  return res.json()
}
