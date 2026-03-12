<script setup>
import { ref, computed, onMounted } from 'vue'
import { getPrescriptions, getDevices } from '../api/deviceGenerator.js'
import { mockPrescriptions, mockDevices } from '../data/mockData.js'

const prescriptions = ref([])
const devices = ref([])
const error = ref(null)

function groupByDevice(rxList) {
  const order = []
  const byDevice = new Map()
  for (const r of rxList) {
    const id = r.deviceId
    if (!byDevice.has(id)) {
      order.push(id)
      byDevice.set(id, {
        deviceId: id,
        patientId: r.patientId,
        prescriptions: [],
      })
    }
    byDevice.get(id).prescriptions.push(r)
  }
  const deviceList = devices.value
  const byId = new Map(deviceList.map((d) => [d.device_id, d]))
  return order.map((deviceId) => {
    const g = byDevice.get(deviceId)
    return {
      ...g,
      device: byId.get(deviceId) ?? null,
    }
  })
}

const grouped = computed(() => groupByDevice(prescriptions.value))

onMounted(async () => {
  try {
    const [rx, dev] = await Promise.all([getPrescriptions(), getDevices()])
    prescriptions.value = rx
    devices.value = dev
    error.value = null
  } catch (e) {
    error.value = e.message
    prescriptions.value = mockPrescriptions
    devices.value = mockDevices
  }
})
</script>

<template>
  <div class="list-view">
    <h2>Prescriptions</h2>
    <p v-if="error" class="error-msg">Backend unavailable, showing mock data: {{ error }}</p>
    <table class="data-table">
      <thead>
        <tr>
          <th>Device</th>
          <th>Patient</th>
          <th>Prescription ID</th>
          <th>Metric</th>
          <th>Target</th>
          <th>Tolerance</th>
        </tr>
      </thead>
      <tbody>
        <template v-for="group in grouped" :key="group.deviceId">
          <tr class="device-row">
            <td colspan="6">
              <strong>{{ group.deviceId }}</strong>
              <span class="device-meta"> — Patient {{ group.patientId }}</span>
              <span v-if="group.device" class="device-meta">
                · Pressure {{ group.device.pressureSetting }} · Flow {{ group.device.flowRateSetting }} · Level {{ group.device.flowLevel }}
              </span>
            </td>
          </tr>
          <tr v-for="r in group.prescriptions" :key="r.prescriptionId" class="rx-row">
            <td></td>
            <td></td>
            <td>{{ r.prescriptionId }}</td>
            <td>{{ r.metricName }}</td>
            <td>{{ r.targetValue }}</td>
            <td>{{ r.toleranceRange }}</td>
          </tr>
        </template>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.list-view h2 {
  margin-bottom: 1rem;
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
}
.data-table th {
  font-weight: 600;
  color: var(--text-h);
  background: var(--code-bg);
}
.device-row td {
  background: var(--accent-bg);
  color: var(--accent);
  border-top: 2px solid var(--accent-border);
  padding: 0.6rem 0.75rem;
  font-size: 0.95rem;
}
.device-row .device-meta {
  color: rgba(255, 255, 255, 0.9);
  font-weight: normal;
}
.rx-row td:first-child,
.rx-row td:nth-child(2) {
  border-left: 1px solid var(--border);
}
.error-msg {
  color: #b91c1c;
  font-size: 0.9rem;
  margin-bottom: 0.5rem;
}
</style>
