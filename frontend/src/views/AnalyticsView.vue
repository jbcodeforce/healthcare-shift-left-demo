<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { Chart } from 'chart.js/auto'
import { getDashboardData } from '../api/deviceGenerator.js'

const loading = ref(true)
const error = ref(null)
const available = ref(false)
const message = ref(null)
const anomaliesPerDevice = ref([])
const configChangesOverTime = ref([])
const newDevicesOverTime = ref([])

const canvasAnomalies = ref(null)
const canvasConfigChanges = ref(null)
const canvasNewDevices = ref(null)
let chartAnomalies = null
let chartConfigChanges = null
let chartNewDevices = null

const CHART_COLORS = [
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

function createBarChart(canvasEl, labels, values, title, yLabel, colors) {
  if (!canvasEl) return null
  const ctx = canvasEl.getContext('2d')
  if (!ctx) return null
  return new Chart(ctx, {
    type: 'bar',
    data: {
      labels,
      datasets: [{
        label: yLabel,
        data: values,
        backgroundColor: colors,
        borderColor: colors.map(c => c.replace(')', ', 0.9)').replace('rgb', 'rgba')),
        borderWidth: 1,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        title: { display: true, text: title },
      },
      scales: {
        x: {
          title: { display: true },
          ticks: { maxRotation: 45 },
        },
        y: {
          title: { display: true, text: yLabel },
          beginAtZero: true,
          ticks: { stepSize: 1 },
        },
      },
    },
  })
}

function createLineChart(canvasEl, labels, values, title, yLabel, color) {
  if (!canvasEl) return null
  const ctx = canvasEl.getContext('2d')
  if (!ctx) return null
  return new Chart(ctx, {
    type: 'line',
    data: {
      labels,
      datasets: [{
        label: yLabel,
        data: values,
        borderColor: color,
        backgroundColor: color.replace(')', ', 0.1)').replace('rgb', 'rgba'),
        fill: true,
        tension: 0.2,
        pointRadius: 4,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        title: { display: true, text: title },
      },
      scales: {
        x: {
          title: { display: true, text: 'Date' },
          ticks: { maxRotation: 45 },
        },
        y: {
          title: { display: true, text: yLabel },
          beginAtZero: true,
          ticks: { stepSize: 1 },
        },
      },
    },
  })
}

function initCharts() {
  if (chartAnomalies) chartAnomalies.destroy()
  if (chartConfigChanges) chartConfigChanges.destroy()
  if (chartNewDevices) chartNewDevices.destroy()

  const labelsA = anomaliesPerDevice.value.map(r => r.device_id)
  const valuesA = anomaliesPerDevice.value.map(r => r.count)
  const colorsA = labelsA.map((_, i) => CHART_COLORS[i % CHART_COLORS.length])
  chartAnomalies = createBarChart(
    canvasAnomalies.value,
    labelsA,
    valuesA,
    'Anomalies per device',
    'Count',
    colorsA
  )

  const labelsC = configChangesOverTime.value.map(r => r.date)
  const valuesC = configChangesOverTime.value.map(r => r.count)
  chartConfigChanges = createLineChart(
    canvasConfigChanges.value,
    labelsC,
    valuesC,
    'Configuration changes over time',
    'Changes per day',
    CHART_COLORS[0]
  )

  const labelsN = newDevicesOverTime.value.map(r => r.date)
  const valuesN = newDevicesOverTime.value.map(r => r.count)
  chartNewDevices = createLineChart(
    canvasNewDevices.value,
    labelsN,
    valuesN,
    'New devices deployed over time',
    'New devices per day',
    CHART_COLORS[1]
  )
}

async function fetchDashboard() {
  loading.value = true
  error.value = null
  try {
    const data = await getDashboardData()
    available.value = data.available === true
    message.value = data.message ?? null
    anomaliesPerDevice.value = data.anomalies_per_device ?? []
    configChangesOverTime.value = data.config_changes_over_time ?? []
    newDevicesOverTime.value = data.new_devices_over_time ?? []
    const { nextTick } = await import('vue')
    await nextTick()
    if (available.value) initCharts()
  } catch (e) {
    error.value = e.message || 'Failed to load analytics'
    available.value = false
  } finally {
    loading.value = false
  }
}

onMounted(fetchDashboard)
onUnmounted(() => {
  if (chartAnomalies) chartAnomalies.destroy()
  if (chartConfigChanges) chartConfigChanges.destroy()
  if (chartNewDevices) chartNewDevices.destroy()
})
</script>

<template>
  <div class="analytics-view">
    <h2>Analytics</h2>
    <p class="muted">Metrics from S3 Parquet / Iceberg tables (DuckDB). Configure ANALYTICS_S3_* or ANALYTICS_LOCAL_PATH to enable.</p>

    <div v-if="loading" class="loading">Loading analytics…</div>
    <p v-else-if="error" class="error">{{ error }}</p>
    <div v-else-if="!available" class="unavailable">
      <p><strong>Analytics not available</strong></p>
      <p v-if="message" class="muted">{{ message }}</p>
      <button type="button" @click="fetchDashboard">Retry</button>
    </div>

    <template v-else>
      <section class="charts-section">
        <div class="charts-grid">
          <div class="chart-wrap">
            <canvas ref="canvasAnomalies" aria-label="Anomalies per device"></canvas>
            <p v-if="!anomaliesPerDevice.length" class="chart-placeholder">No anomaly data.</p>
          </div>
          <div class="chart-wrap">
            <canvas ref="canvasConfigChanges" aria-label="Config changes over time"></canvas>
            <p v-if="!configChangesOverTime.length" class="chart-placeholder">No config change data.</p>
          </div>
          <div class="chart-wrap">
            <canvas ref="canvasNewDevices" aria-label="New devices over time"></canvas>
            <p v-if="!newDevicesOverTime.length" class="chart-placeholder">No new device data.</p>
          </div>
        </div>
      </section>
      <div class="refresh">
        <button type="button" @click="fetchDashboard">Refresh</button>
      </div>
    </template>
  </div>
</template>

<style scoped>
.analytics-view h2 {
  margin-bottom: 0.5rem;
}
.muted {
  color: var(--text);
  opacity: 0.8;
  font-size: 0.9rem;
  margin-bottom: 1rem;
}
.loading,
.error {
  margin: 1rem 0;
}
.error {
  color: #b91c1c;
}
.unavailable {
  margin: 1rem 0;
  padding: 1rem;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--code-bg);
}
.unavailable p {
  margin: 0 0 0.5rem;
}
.unavailable button {
  margin-top: 0.75rem;
  padding: 0.5rem 1rem;
  font-size: 0.9rem;
  border-radius: 6px;
  border: 1px solid var(--border);
  background: var(--bg);
  color: var(--text-h);
  cursor: pointer;
}
.unavailable button:hover {
  background: var(--accent-bg);
  border-color: var(--accent-border);
}
.charts-section {
  margin-top: 1rem;
  margin-bottom: 1rem;
}
.charts-grid {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}
.chart-wrap {
  height: 260px;
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
.refresh {
  margin-top: 1rem;
}
.refresh button {
  padding: 0.5rem 1rem;
  font-size: 0.9rem;
  border-radius: 6px;
  border: 1px solid var(--border);
  background: var(--bg);
  color: var(--text-h);
  cursor: pointer;
}
.refresh button:hover {
  background: var(--accent-bg);
  border-color: var(--accent-border);
}
</style>
