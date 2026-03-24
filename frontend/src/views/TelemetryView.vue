<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { Chart } from 'chart.js/auto'
import 'chartjs-adapter-date-fns'
import { getSimulationStatus, startSimulation, stopSimulation, subscribeTelemetryStream, getTelemetryMetrics, getDevices, triggerDeviceSimulation } from '../api/deviceGenerator.js'

const status = ref(null)
const error = ref(null)
const loading = ref(false)
const devices = ref([])
const selectedDeviceId = ref(null)
const simulatorMessage = ref(null)
const simulatorLoading = ref(false)
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
let chartFlowLevel = null
const canvasPressure = ref(null)
const canvasFlowRate = ref(null)
const canvasFlowLevel = ref(null)

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

/** Epoch ms for charts/API; supports numeric ms or ISO strings (parseInt on ISO breaks Chart.js). */
function toEpochMs(ts) {
  if (ts == null || ts === '') return null
  if (typeof ts === 'number' && Number.isFinite(ts)) return ts
  if (typeof ts === 'string') {
    const trimmed = ts.trim()
    if (/^\d+$/.test(trimmed)) return parseInt(trimmed, 10)
    const parsed = Date.parse(ts)
    if (!Number.isNaN(parsed)) return parsed
  }
  return null
}

function formatTs(ts) {
  const ms = toEpochMs(ts)
  if (ms == null) return '—'
  return new Date(ms).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

function formatTsShort(ts) {
  const ms = toEpochMs(ts)
  if (ms == null) return ''
  return new Date(ms).toLocaleTimeString(undefined, { minute: '2-digit', second: '2-digit' })
}

/** Shared x-axis range so the three charts stay aligned; padding avoids edge clipping. */
function xBoundsFromRecords(records) {
  let minT = Infinity
  let maxT = -Infinity
  for (const r of records) {
    const x = toEpochMs(r.ts)
    if (x == null) continue
    minT = Math.min(minT, x)
    maxT = Math.max(maxT, x)
  }
  if (!Number.isFinite(minT)) return null
  const span = Math.max(maxT - minT, 90_000)
  const padL = Math.max(span * 0.06, 120_000)
  const padR = Math.max(span * 0.08, 180_000)
  return { min: minT - padL, max: maxT + padR }
}

/** Build Chart.js datasets for one metric: one dataset per device. */
function buildDatasetsForMetric(records, metricName) {
  const byDevice = {}
  for (const r of records) {
    if (r.metric_name !== metricName) continue
    const dev = r.device_id
    if (!byDevice[dev]) byDevice[dev] = []
    const x = toEpochMs(r.ts)
    if (x == null) continue
    byDevice[dev].push({ x, y: Number(r.metric_value) })
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
      tension: 0,
      pointRadius: 3,
      pointHoverRadius: 5,
    }
  })
}

function updateChart(chartInstance, records, metricName, yLabel, xBounds, yAxis = null) {
  if (!chartInstance) return
  const datasets = buildDatasetsForMetric(records, metricName)
  chartInstance.data.datasets = datasets
  chartInstance.options.scales.y.title.text = yLabel
  if (yAxis && yAxis.min != null && yAxis.max != null) {
    chartInstance.options.scales.y.min = yAxis.min
    chartInstance.options.scales.y.max = yAxis.max
  }
  const xScale = chartInstance.options.scales.x
  if (xBounds) {
    xScale.min = xBounds.min
    xScale.max = xBounds.max
  } else {
    delete xScale.min
    delete xScale.max
  }
  chartInstance.update()
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

function createChart(canvasEl, metricName, title, yLabel, yAxis = null) {
  if (!canvasEl) return null
  const ctx = canvasEl.getContext('2d')
  if (!ctx) return null
  const yScale = {
    title: { display: true, text: yLabel },
    beginAtZero: yAxis?.min === 0,
  }
  if (yAxis?.min != null) yScale.min = yAxis.min
  if (yAxis?.max != null) yScale.max = yAxis.max
  if (!yAxis) yScale.beginAtZero = false
  return new Chart(ctx, {
    type: 'line',
    data: {
      datasets: buildDatasetsForMetric(metricsRecords.value, metricName),
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: {
        duration: 500,
        easing: 'easeOutQuart',
      },
      transitions: {
        active: { animation: { duration: 350 } },
      },
      interaction: { intersect: false, mode: 'nearest', axis: 'x' },
      plugins: {
        legend: { position: 'top' },
        title: { display: true, text: title },
        tooltip: {
          callbacks: {
            title: (items) => {
              if (!items.length) return ''
              const x = items[0].parsed?.x
              return x != null ? formatTs(x) : ''
            },
          },
        },
      },
      scales: {
        x: {
          type: 'time',
          title: { display: true, text: 'Simulated event time' },
          time: {
            tooltipFormat: 'MMM d, yyyy HH:mm:ss',
            displayFormats: {
              millisecond: 'HH:mm:ss.SSS',
              second: 'HH:mm:ss',
              minute: 'MMM d HH:mm',
              hour: 'MMM d HH:mm',
              day: 'MMM d',
            },
          },
          ticks: {
            maxRotation: 0,
            autoSkip: true,
            maxTicksLimit: 12,
          },
        },
        y: yScale,
      },
    },
  })
}

function initCharts() {
  if (chartPressure) chartPressure.destroy()
  if (chartFlowRate) chartFlowRate.destroy()
  if (chartFlowLevel) chartFlowLevel.destroy()
  chartPressure = createChart(canvasPressure.value, 'Pressure', 'Pressure (simulated → Kafka)', 'Pressure')
  chartFlowRate = createChart(canvasFlowRate.value, 'FlowRate', 'Flow rate (simulated → Kafka)', 'Flow rate')
  chartFlowLevel = createChart(
    canvasFlowLevel.value,
    'FlowLevel',
    'Flow level (simulated → Kafka)',
    'Flow level (0–300)',
    { min: 0, max: 300 },
  )
}

watch(metricsRecords, (records) => {
  if (!records.length) return
  const bounds = xBoundsFromRecords(records)
  updateChart(chartPressure, records, 'Pressure', 'Pressure', bounds)
  updateChart(chartFlowRate, records, 'FlowRate', 'Flow rate', bounds)
  updateChart(chartFlowLevel, records, 'FlowLevel', 'Flow level (0–300)', bounds, { min: 0, max: 300 })
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

async function runScenario(type) {
  if (!selectedDeviceId.value) return
  simulatorLoading.value = true
  simulatorMessage.value = null
  error.value = null
  try {
    const res = await triggerDeviceSimulation(selectedDeviceId.value, type)
    simulatorMessage.value = res.message || 'Scenario sent.'
    setTimeout(() => { simulatorMessage.value = null }, 4000)
  } catch (e) {
    simulatorMessage.value = null
    error.value = e.message || 'Scenario failed'
  } finally {
    simulatorLoading.value = false
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
  try {
    devices.value = await getDevices()
  } catch (_) {
    // ignore
  }
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
  if (chartFlowLevel) chartFlowLevel.destroy()
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
      <div class="device-simulator">
        <h4>Device scenario</h4>
        <p class="muted">Select a device and run a one-shot scenario (telemetry sent to Kafka).</p>
        <select v-model="selectedDeviceId" class="device-select" aria-label="Select device">
          <option :value="null" disabled>Select device</option>
          <option v-for="d in devices" :key="d.device_id" :value="d.device_id">
            {{ d.device_id }} ({{ d.patientId }})
          </option>
        </select>
        <div class="buttons scenario-buttons">
          <button
            type="button"
            :disabled="!selectedDeviceId || simulatorLoading"
            @click="runScenario('flow_level_down')"
          >
            Flow level down
          </button>
          <button
            type="button"
            :disabled="!selectedDeviceId || simulatorLoading"
            @click="runScenario('pressure_oscillate')"
          >
            Pressure up/down
          </button>
          <button
            type="button"
            :disabled="!selectedDeviceId || simulatorLoading"
            @click="runScenario('flow_rate_down')"
          >
            Flow rate down
          </button>
        </div>
        <p v-if="simulatorMessage" class="simulator-message">{{ simulatorMessage }}</p>
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
          <canvas ref="canvasFlowLevel" aria-label="Flow level chart"></canvas>
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
.device-simulator {
  margin-top: 1.5rem;
  padding-top: 1rem;
  border-top: 1px solid var(--border);
}
.device-simulator h4 {
  font-size: 1rem;
  font-weight: 600;
  color: var(--text-h);
  margin: 0 0 0.5rem;
}
.device-select {
  display: block;
  margin-top: 0.5rem;
  margin-bottom: 0.75rem;
  padding: 0.5rem 0.75rem;
  font-size: 0.9rem;
  border-radius: 6px;
  border: 1px solid var(--border);
  background: var(--bg);
  color: var(--text-h);
  min-width: 12rem;
}
.scenario-buttons {
  margin-top: 0.25rem;
}
.simulator-message {
  margin-top: 0.5rem;
  color: green;
  font-size: 0.9rem;
}
</style>
