<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { Chart } from 'chart.js/auto'
import { getSimulationStatus, startSimulation, stopSimulation, subscribeTelemetryStream, getTelemetryMetrics } from '../api/deviceGenerator.js'

const status = ref(null)
const error = ref(null)
const loading = ref(false)
const telemetryEvents = ref([])
const maxEvents = 100
const streamPaused = ref(false)
const streamActive = ref(false)
const metricsRecords = ref([])
const pollIntervalMs = 2000
let unsubscribeStream = null
let pollTimer = null
let chartPressure = null
let chartFlowRate = null
let chartMotorSpeed = null
const canvasPressure = ref(null)
const canvasFlowRate = ref(null)
const canvasMotorSpeed = ref(null)

const DEVICE_COLORS = [
  'rgb(59, 130, 246)',
  'rgb(34, 197, 94)',
  'rgb(234, 88, 12)',
  'rgb(168, 85, 247)',
  'rgb(236, 72, 153)',
  'rgb(14, 165, 233)',
  'rgb(132, 204, 22)',
  'rgb(251, 146, 60)',
  'rgb(99, 102, 241)',
  'rgb(20, 184, 166)',
]

function formatTs(ts) {
  if (ts == null) return '—'
  const d = new Date(typeof ts === 'number' ? ts : parseInt(ts, 10))
  return d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}


function formatTsShort(ts) {
  if (ts == null) return ''
  const d = new Date(typeof ts === 'number' ? ts : parseInt(ts, 10))
  return d.toLocaleTimeString(undefined, { minute: '2-digit', second: '2-digit' })
}

/** Build Chart.js datasets for one metric: one dataset per device. */
function buildDatasetsForMetric(records, metricName) {
  const byDevice = {}
  for (const r of records) {
    if (r.metric_name !== metricName) continue
    const dev = r.device_id
    if (!byDevice[dev]) byDevice[dev] = []
    byDevice[dev].push({ x: r.ts, y: Number(r.metric_value) })
  }
  const devices = Object.keys(byDevice).sort()
  return devices.map((dev, i) => {
    const points = byDevice[dev].sort((a, b) => a.x - b.x)
    return {
      label: dev,
      data: points,
      borderColor: DEVICE_COLORS[i % DEVICE_COLORS.length],
      backgroundColor: DEVICE_COLORS[i % DEVICE_COLORS.length],
      fill: false,
      tension: 0.2,
      pointRadius: 2,
      pointHoverRadius: 5,
    }
  })
}

function updateChart(chartInstance, records, metricName, yLabel) {
  if (!chartInstance) return
  const datasets = buildDatasetsForMetric(records, metricName)
  chartInstance.data.datasets = datasets
  chartInstance.options.scales.y.title.text = yLabel
  chartInstance.update('none')
}

async function fetchMetrics() {
  try {
    const data = await getTelemetryMetrics()
    metricsRecords.value = data
  } catch (_) {
    // ignore
  }
}

function startPolling() {
  fetchMetrics()
  pollTimer = setInterval(fetchMetrics, pollIntervalMs)
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer)
    pollTimer = null
  }
}

function createChart(canvasEl, metricName, title, yLabel) {
  if (!canvasEl) return null
  const ctx = canvasEl.getContext('2d')
  if (!ctx) return null
  return new Chart(ctx, {
    type: 'line',
    data: {
      datasets: buildDatasetsForMetric(metricsRecords.value, metricName),
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { intersect: false, mode: 'index' },
      plugins: {
        legend: { position: 'top' },
        title: { display: true, text: title },
        tooltip: {
          callbacks: {
            title: (items) => items.length && items[0].raw?.x != null ? formatTs(items[0].raw.x) : '',
          },
        },
      },
      scales: {
        x: {
          type: 'linear',
          title: { display: true, text: 'Time' },
          ticks: {
            callback: (value) => formatTsShort(value),
            maxTicksLimit: 10,
          },
        },
        y: {
          title: { display: true, text: yLabel },
          beginAtZero: false,
        },
      },
    },
  })
}

function initCharts() {
  if (chartPressure) chartPressure.destroy()
  if (chartFlowRate) chartFlowRate.destroy()
  if (chartMotorSpeed) chartMotorSpeed.destroy()
  chartPressure = createChart(canvasPressure.value, 'Pressure', 'Pressure (simulated → Kafka)', 'Pressure')
  chartFlowRate = createChart(canvasFlowRate.value, 'FlowRate', 'Flow rate (simulated → Kafka)', 'Flow rate')
  chartMotorSpeed = createChart(canvasMotorSpeed.value, 'MotorSpeed', 'Motor speed (simulated → Kafka)', 'Motor speed (RPM)')
}

watch(metricsRecords, (records) => {
  if (records.length) {
    updateChart(chartPressure, records, 'Pressure', 'Pressure')
    updateChart(chartFlowRate, records, 'FlowRate', 'Flow rate')
    updateChart(chartMotorSpeed, records, 'MotorSpeed', 'Motor speed (RPM)')
  }
}, { deep: true })

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

onMounted(async () => {
  await fetchStatus()
  const { nextTick } = await import('vue')
  await nextTick()
  initCharts()
  startPolling()
})

onUnmounted(() => {
  stopPolling()
  if (unsubscribeStream) unsubscribeStream()
  if (chartPressure) chartPressure.destroy()
  if (chartFlowRate) chartFlowRate.destroy()
  if (chartMotorSpeed) chartMotorSpeed.destroy()
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

    <section class="charts-section">
      <h3>Simulated metrics sent to Kafka</h3>
      <p class="muted">Last records from the simulator cache (one line per device). Polling every {{ pollIntervalMs / 1000 }}s.</p>
      <div class="charts-grid">
        <div class="chart-wrap">
          <canvas ref="canvasPressure" aria-label="Pressure chart"></canvas>
          <p v-if="!metricsRecords.length" class="chart-placeholder">No data yet. Start the simulation to see metrics.</p>
        </div>
        <div class="chart-wrap">
          <canvas ref="canvasFlowRate" aria-label="Flow rate chart"></canvas>
          <p v-if="!metricsRecords.length" class="chart-placeholder">No data yet. Start the simulation to see metrics.</p>
        </div>
        <div class="chart-wrap">
          <canvas ref="canvasMotorSpeed" aria-label="Motor speed chart"></canvas>
          <p v-if="!metricsRecords.length" class="chart-placeholder">No data yet. Start the simulation to see metrics.</p>
        </div>
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
.charts-section,
.stream-section {
  margin-bottom: 2rem;
}
.control-section h3,
.charts-section h3,
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
  border-color: var(--accent-border);
  color: var(--accent);
}
.charts-grid {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  margin-top: 0.75rem;
}
.chart-wrap {
  height: 220px;
  min-width: 0;
  position: relative;
}
.chart-placeholder {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  margin: 0;
  color: var(--text);
  opacity: 0.8;
  font-size: 0.9rem;
  pointer-events: none;
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
