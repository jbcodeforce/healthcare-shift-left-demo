<script setup>
import { ref, computed, onMounted } from 'vue'
import { getPatients, getDevices } from '../api/deviceGenerator.js'

const patients = ref([])
const devices = ref([])
const error = ref(null)

const deviceByPatientId = computed(() => {
  const map = new Map()
  for (const d of devices.value) {
    map.set(d.patientId, d)
  }
  return map
})

const rows = computed(() =>
  patients.value.map((p) => {
    const device = deviceByPatientId.value.get(p.patientId)
    return {
      ...p,
      deviceId: device?.device_id ?? '—',
      pressureSetting: device?.pressureSetting ?? null,
      flowRateSetting: device?.flowRateSetting ?? null,
      flowLevelSetting: device?.flowLevelSetting ?? device?.flowLevel ?? null,
    }
  })
)

onMounted(async () => {
  try {
    const [pts, dev] = await Promise.all([getPatients(), getDevices()])
    patients.value = pts
    devices.value = dev
    error.value = null
  } catch (e) {
    error.value = e.message
    patients.value = []
    devices.value = []
  }
})
</script>

<template>
  <div class="list-view">
    <h2>Patients</h2>
    <p class="view-desc">
      Static patient dimensions used for geo-aggregations and daylight-hour device OTA gating (IANA timezone).
    </p>
    <p v-if="error" class="error-msg">Could not load patients from the backend: {{ error }}</p>
    <table class="data-table">
      <thead>
        <tr>
          <th>Patient ID</th>
          <th>Name</th>
          <th>Gender</th>
          <th>Birth date</th>
          <th>Zip code</th>
          <th>Timezone</th>
          <th>Assigned device</th>
          <th>Device settings</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="p in rows" :key="p.patientId">
          <td><code class="mono">{{ p.patientId }}</code></td>
          <td>{{ p.name }}</td>
          <td>{{ p.gender }}</td>
          <td>{{ p.birthDate }}</td>
          <td>{{ p.zipCode }}</td>
          <td>{{ p.timezone ?? '—' }}</td>
          <td>
            <code v-if="p.deviceId !== '—'" class="mono">{{ p.deviceId }}</code>
            <span v-else>—</span>
          </td>
          <td class="settings-cell">
            <template v-if="p.pressureSetting != null">
              Pressure {{ p.pressureSetting }} · Flow {{ p.flowRateSetting }} · Level {{ p.flowLevelSetting }}
            </template>
            <span v-else>—</span>
          </td>
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
.settings-cell {
  font-size: 0.85rem;
  color: var(--text);
  white-space: nowrap;
}
.error-msg {
  color: #b91c1c;
  font-size: 0.9rem;
  margin-bottom: 0.5rem;
}
</style>
