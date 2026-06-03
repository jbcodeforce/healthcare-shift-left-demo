<script setup>
import { ref, computed, onMounted } from 'vue'
import { getDevices, getPatients } from '../api/deviceGenerator.js'

const devices = ref([])
const patients = ref([])
const error = ref(null)

const patientById = computed(() => new Map(patients.value.map((p) => [p.patientId, p])))

function formatCoord(n) {
  if (n == null || Number.isNaN(Number(n))) return '—'
  return Number(n).toFixed(4)
}

function formatPlugged(v) {
  if (v == null) return '—'
  return v ? 'Yes' : 'No'
}

const rows = computed(() =>
  devices.value.map((d) => {
    const patient = patientById.value.get(d.patientId)
    return {
      ...d,
      patientName: patient?.name ?? '—',
      flowLevelSetting: d.flowLevelSetting ?? d.flowLevel,
      softwareVersion: d.sw_version ?? '—',
      latitude: d.latitude ?? d.lat,
      longitude: d.longitude ?? d.lng,
      batteryLevel: d.batteryLevel ?? d.battery_level,
      plugged: d.plugged,
    }
  })
)

onMounted(async () => {
  try {
    const [dev, pts] = await Promise.all([getDevices(), getPatients()])
    devices.value = dev
    patients.value = pts
    error.value = null
  } catch (e) {
    error.value = e.message
    devices.value = []
    patients.value = []
  }
})
</script>

<template>
  <div class="list-view">
    <h2>Devices</h2>
    <p class="view-desc">
      CPAP device settings plus latest lifecycle state (software version, location, power) aligned with device events.
    </p>
    <p v-if="error" class="error-msg">Could not load devices from the backend: {{ error }}</p>
    <table class="data-table">
      <thead>
        <tr>
          <th>Device ID</th>
          <th>Patient</th>
          <th>Software version</th>
          <th>Latitude</th>
          <th>Longitude</th>
          <th>Battery %</th>
          <th>Plugged</th>
          <th>Pressure setting</th>
          <th>Flow rate setting</th>
          <th>Flow level (0–300)</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="d in rows" :key="d.device_id">
          <td><code class="mono">{{ d.device_id }}</code></td>
          <td>
            <span class="patient-cell">{{ d.patientId }}</span>
            <span v-if="d.patientName !== '—'" class="patient-name"> — {{ d.patientName }}</span>
          </td>
          <td>{{ d.sw_version }}</td>
          <td>{{ formatCoord(d.latitude) }}</td>
          <td>{{ formatCoord(d.longitude) }}</td>
          <td>{{ d.batteryLevel != null ? d.batteryLevel : '—' }}</td>
          <td>{{ formatPlugged(d.plugged) }}</td>
          <td>{{ d.pressureSetting }}</td>
          <td>{{ d.flowRateSetting }}</td>
          <td>{{ d.flowLevelSetting }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.list-view h2 {
  margin-bottom: 0.5rem;
}
.view-desc {
  margin: 0 0 1rem;
  font-size: 0.9rem;
  color: var(--text);
  max-width: 42rem;
}
.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9rem;
}
.data-table th,
.data-table td {
  padding: 0.5rem 0.75rem;
  text-align: left;
  border-bottom: 1px solid var(--border);
  vertical-align: top;
}
.data-table th {
  font-weight: 600;
  color: var(--text-h);
  background: var(--code-bg);
}
.mono {
  font-family: var(--mono);
  font-size: 0.85em;
}
.patient-cell {
  font-family: var(--mono);
  font-size: 0.85em;
}
.patient-name {
  color: var(--text);
}
.error-msg {
  color: #b91c1c;
  font-size: 0.9rem;
  margin-bottom: 0.5rem;
}
</style>
