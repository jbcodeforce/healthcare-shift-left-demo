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
