<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { getSimulationStatus, startSimulation, stopSimulation, subscribeTelemetryStream } from '../api/deviceGenerator.js'

const status = ref(null)
const error = ref(null)
const loading = ref(false)
const telemetryEvents = ref([])
const maxEvents = 100
const streamPaused = ref(false)
const streamActive = ref(false)
let unsubscribeStream = null

async function fetchStatus() {
  try {
    const data = await getSimulationStatus()
    status.value = data.running ? 'running' : 'stopped'
    error.value = null
  } catch (e) {
    status.value = null
    error.value = e.message || 'Failed to get status'
  }
}

async function start() {
  loading.value = true
  error.value = null
  try {
    await startSimulation({ simulation_type: 'all' })
    await fetchStatus()
  } catch (e) {
    error.value = e.message || 'Failed to start'
  } finally {
    loading.value = false
  }
}

async function stop() {
  loading.value = true
  error.value = null
  try {
    await stopSimulation()
    await fetchStatus()
  } catch (e) {
    error.value = e.message || 'Failed to stop'
  } finally {
    loading.value = false
  }
}

function formatTs(ts) {
  if (ts == null) return '—'
  const d = new Date(typeof ts === 'number' ? ts : parseInt(ts, 10))
  return d.toISOString()
}

function clearEvents() {
  telemetryEvents.value = []
}

function toggleStream() {
  if (streamActive.value) {
    if (unsubscribeStream) unsubscribeStream()
    unsubscribeStream = null
    streamActive.value = false
  } else {
    streamActive.value = true
    streamPaused.value = false
    unsubscribeStream = subscribeTelemetryStream((data) => {
      if (streamPaused.value) return
      telemetryEvents.value = [data, ...telemetryEvents.value].slice(0, maxEvents)
    })
  }
}

onMounted(() => {
  fetchStatus()
})

onUnmounted(() => {
  if (unsubscribeStream) unsubscribeStream()
})
</script>

<template>
  <div class="telemetry-view">
    <h2>Device telemetry</h2>

    <section class="control-section">
      <h3>Simulation control</h3>
      <p v-if="status !== null" class="status">
        Status: <strong :class="status">{{ status === 'running' ? 'Running' : 'Stopped' }}</strong>
      </p>
      <p v-else-if="error" class="error">{{ error }}</p>
      <div class="buttons">
        <button type="button" :disabled="loading || status === 'running'" @click="start">
          Start simulation
        </button>
        <button type="button" :disabled="loading || status === 'stopped'" @click="stop">
          Stop simulation
        </button>
      </div>
    </section>

    <section class="stream-section">
      <h3>Live telemetry stream</h3>
      <div class="stream-controls">
        <button type="button" :class="{ active: streamActive }" @click="toggleStream">
          {{ streamActive ? 'Disconnect' : 'Connect' }} stream
        </button>
        <template v-if="streamActive">
          <button type="button" @click="streamPaused = !streamPaused">
            {{ streamPaused ? 'Resume' : 'Pause' }}
          </button>
        </template>
        <button type="button" @click="clearEvents">Clear</button>
      </div>
      <div class="telemetry-list">
        <table v-if="telemetryEvents.length" class="data-table">
          <thead>
            <tr>
              <th>Time</th>
              <th>Device ID</th>
              <th>Patient ID</th>
              <th>Metric</th>
              <th>Value</th>
              <th>Version</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(ev, i) in telemetryEvents" :key="i">
              <td>{{ formatTs(ev.ts) }}</td>
              <td>{{ ev.device_id }}</td>
              <td>{{ ev.patient_id }}</td>
              <td>{{ ev.metric_name }}</td>
              <td>{{ ev.metric_value }}</td>
              <td>{{ ev.software_version ?? '—' }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="muted">No events yet. Connect the stream and start the simulation.</p>
      </div>
    </section>
  </div>
</template>

<style scoped>
.telemetry-view h2 {
  margin-bottom: 1rem;
}
.control-section,
.stream-section {
  margin-bottom: 2rem;
}
.control-section h3,
.stream-section h3 {
  font-size: 1rem;
  font-weight: 600;
  color: var(--text-h);
  margin: 0 0 0.5rem;
}
.status .running {
  color: green;
}
.status .stopped {
  color: var(--text);
}
.error {
  color: #b91c1c;
}
.buttons,
.stream-controls {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
  margin-top: 0.5rem;
}
button {
  padding: 0.5rem 1rem;
  font-size: 0.9rem;
  border-radius: 6px;
  border: 1px solid var(--border);
  background: var(--bg);
  color: var(--text-h);
  cursor: pointer;
}
button:hover:not(:disabled) {
  background: var(--accent-bg);
  border-color: var(--accent-border);
}
button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
button.active {
  background: var(--accent-bg);
  border-color: var(--accent);
}
.telemetry-list {
  margin-top: 0.75rem;
  overflow-x: auto;
}
.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.85rem;
}
.data-table th,
.data-table td {
  padding: 0.4rem 0.6rem;
  text-align: left;
  border-bottom: 1px solid var(--border);
}
.data-table th {
  font-weight: 600;
  color: var(--text-h);
  background: var(--code-bg);
}
.muted {
  color: var(--text);
  opacity: 0.8;
  font-size: 0.9rem;
}
</style>
