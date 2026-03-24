<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  getPrescriptions,
  getDevices,
  getPatients,
  createPrescription,
  deletePrescription,
} from '../api/deviceGenerator.js'
import { mockPrescriptions, mockDevices } from '../data/mockData.js'

const prescriptions = ref([])
const devices = ref([])
const patients = ref([])
const error = ref(null)
const showCreateForm = ref(false)
const createError = ref(null)
const createSuccess = ref(null)
const deletingId = ref(null)

/** Format epoch ms for datetime-local value (local calendar, not UTC). */
function epochMsToDatetimeLocal(ms) {
  if (ms == null || Number.isNaN(Number(ms))) return ''
  const d = new Date(Number(ms))
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function datetimeLocalToEpochMs(s) {
  if (s == null || String(s).trim() === '') return null
  const t = new Date(s).getTime()
  return Number.isNaN(t) ? null : t
}

function setFormStartFromLocal(s) {
  form.value.startDate = datetimeLocalToEpochMs(s)
}

function setFormEndFromLocal(s) {
  form.value.endDate = datetimeLocalToEpochMs(s)
}

/** Human-readable prescription boundary for list header. */
function formatPrescriptionDate(ms) {
  if (ms == null || ms === '') return null
  const n = Number(ms)
  if (Number.isNaN(n)) return null
  return new Date(n).toLocaleString()
}

const form = ref({
  patientId: '',
  deviceId: '',
  medicationOrTherapy: 'CPAP Oxygen Flow',
  startDate: 1710000000000,
  endDate: 1741536000000,
  parameters: [
    { parameter_name: 'Pressure', parameter_value: 10, parameter_type: 'float', parameter_tolerance: 1 },
    { parameter_name: 'FlowRate', parameter_value: 2.5, parameter_type: 'float', parameter_tolerance: 0.5 },
    { parameter_name: 'FlowLevel', parameter_value: 150, parameter_type: 'float', parameter_tolerance: 50 },
  ],
})

function parseParameters(str) {
  if (str == null || str === '') return []
  try {
    const arr = JSON.parse(str)
    return Array.isArray(arr) ? arr : []
  } catch {
    return []
  }
}

/** Get parameter value by name from a prescription's parameters array. */
function paramValue(params, name) {
  const p = params.find((x) => x.parameter_name === name)
  return p != null ? p.parameter_value : null
}

function groupedPrescriptions() {
  const list = prescriptions.value
  const deviceList = devices.value
  const byId = new Map(deviceList.map((d) => [d.device_id, d]))
  return list.map((r) => {
    const parametersArray = parseParameters(r.parameters)
    const device = byId.get(r.deviceId) ?? null
    return {
      deviceId: r.deviceId,
      patientId: r.patientId,
      prescriptionId: r.prescriptionId,
      medicationOrTherapy: r.medicationOrTherapy,
      startDate: r.startDate,
      endDate: r.endDate,
      parametersArray,
      device,
      // Header summary from this prescription's parameters (not the device record)
      pressureSetting: paramValue(parametersArray, 'Pressure') ?? device?.pressureSetting,
      flowRateSetting: paramValue(parametersArray, 'FlowRate') ?? device?.flowRateSetting,
      flowLevelSetting: paramValue(parametersArray, 'FlowLevel') ?? paramValue(parametersArray, 'FlowLevel') ?? device?.flowLevelSetting,
      flowLevel: paramValue(parametersArray, 'FlowLevel') ?? device?.flowLevel,
    }
  })
}

const grouped = computed(() => groupedPrescriptions())

async function loadPrescriptions() {
  try {
    const [rx, dev, pts] = await Promise.all([getPrescriptions(), getDevices(), getPatients()])
    prescriptions.value = rx
    devices.value = dev
    patients.value = pts
    error.value = null
  } catch (e) {
    error.value = e.message
    prescriptions.value = mockPrescriptions
    devices.value = mockDevices
    patients.value = []
  }
}

async function submitCreate() {
  createError.value = null
  createSuccess.value = null
  if (!form.value.patientId || !form.value.deviceId) {
    createError.value = 'Patient and Device are required.'
    return
  }
  const start = form.value.startDate
  const end = form.value.endDate
  if (start != null && end != null && end < start) {
    createError.value = 'End date must be on or after start date.'
    return
  }
  try {
    await createPrescription({
      patientId: form.value.patientId,
      deviceId: form.value.deviceId,
      medicationOrTherapy: form.value.medicationOrTherapy || 'CPAP Oxygen Flow',
      startDate: form.value.startDate ?? null,
      endDate: form.value.endDate ?? null,
      parameters: form.value.parameters,
    })
    createSuccess.value = 'Prescription created.'
    showCreateForm.value = false
    await loadPrescriptions()
  } catch (e) {
    createError.value = e.message
  }
}

function addParameter() {
  form.value.parameters.push({
    parameter_name: 'Metric',
    parameter_value: 0,
    parameter_type: 'float',
    parameter_tolerance: 0,
  })
}

function removeParameter(index) {
  form.value.parameters.splice(index, 1)
}

async function doDelete(prescriptionId) {
  if (!confirm(`Delete prescription ${prescriptionId}?`)) return
  deletingId.value = prescriptionId
  try {
    await deletePrescription(prescriptionId)
    await loadPrescriptions()
  } catch (e) {
    error.value = e.message
  } finally {
    deletingId.value = null
  }
}

onMounted(loadPrescriptions)
</script>

<template>
  <div class="list-view">
    <div class="header-row">
      <h2>Prescriptions</h2>
      <button type="button" class="btn btn-primary" @click="showCreateForm = true">
        New prescription
      </button>
    </div>
    <p v-if="error" class="error-msg">Backend unavailable, showing mock data: {{ error }}</p>
    <p v-if="createSuccess" class="success-msg">{{ createSuccess }}</p>

    <section v-if="showCreateForm" class="create-form card">
      <h3>Create prescription</h3>
      <p v-if="createError" class="error-msg">{{ createError }}</p>
      <form @submit.prevent="submitCreate">
        <div class="form-row">
          <label>Patient</label>
          <select v-model="form.patientId" required>
            <option value="">Select patient</option>
            <option v-for="p in patients" :key="p.patientId" :value="p.patientId">
              {{ p.patientId }} — {{ p.name }}
            </option>
          </select>
        </div>
        <div class="form-row">
          <label>Device</label>
          <select v-model="form.deviceId" required>
            <option value="">Select device</option>
            <option v-for="d in devices" :key="d.device_id" :value="d.device_id">
              {{ d.device_id }} ({{ d.patientId }})
            </option>
          </select>
        </div>
        <div class="form-row">
          <label>Medication / therapy</label>
          <input v-model="form.medicationOrTherapy" type="text" placeholder="e.g. CPAP Oxygen Flow" />
        </div>
        <div class="form-row">
          <label>Start date</label>
          <input
            type="datetime-local"
            :value="epochMsToDatetimeLocal(form.startDate)"
            @input="setFormStartFromLocal($event.target.value)"
          />
        </div>
        <div class="form-row">
          <label>End date</label>
          <input
            type="datetime-local"
            :value="epochMsToDatetimeLocal(form.endDate)"
            @input="setFormEndFromLocal($event.target.value)"
          />
        </div>
        <div class="form-row">
          <label>Parameters</label>
          <div class="params-list">
            <div class="param-row param-header">
              <span>Name</span>
              <span>Value</span>
              <span>Type</span>
              <span>Tolerance</span>
              <span></span>
            </div>
            <div
              v-for="(param, idx) in form.parameters"
              :key="idx"
              class="param-row"
            >
              <input v-model="param.parameter_name" placeholder="Name" />
              <input v-model.number="param.parameter_value" type="number" step="any" placeholder="Value" />
              <input v-model="param.parameter_type" placeholder="Type" />
              <input v-model.number="param.parameter_tolerance" type="number" step="any" placeholder="Tolerance" />
              <button type="button" class="btn btn-sm" @click="removeParameter(idx)">Remove</button>
            </div>
            <button type="button" class="btn btn-sm" @click="addParameter">Add parameter</button>
          </div>
        </div>
        <div class="form-actions">
          <button type="submit" class="btn btn-primary">Create</button>
          <button type="button" class="btn" @click="showCreateForm = false; createError = null; createSuccess = null">
            Cancel
          </button>
        </div>
      </form>
    </section>

    <table class="data-table">
      <thead>
        <tr>
          <th>Device</th>
          <th>Patient</th>
          <th>Prescription ID</th>
          <th>Parameter name</th>
          <th>Parameter value</th>
          <th>Parameter type</th>
          <th>Parameter tolerance</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <template v-for="group in grouped" :key="group.prescriptionId">
          <tr class="device-row">
            <td colspan="8">
              <strong>{{ group.deviceId }}</strong>
              <span class="device-meta"> — Patient {{ group.patientId }}</span>
              <span v-if="group.pressureSetting != null || group.flowRateSetting != null || group.flowLevel != null" class="device-meta">
                · Pressure {{ group.pressureSetting }} · Flow {{ group.flowRateSetting }} · Level {{ group.flowLevel }}
              </span>
              <span v-if="formatPrescriptionDate(group.startDate) || formatPrescriptionDate(group.endDate)" class="device-meta">
                · Start {{ formatPrescriptionDate(group.startDate) ?? '—' }} · End {{ formatPrescriptionDate(group.endDate) ?? '—' }}
              </span>
              <button
                v-if="!error"
                type="button"
                class="btn btn-sm btn-danger"
                :disabled="deletingId === group.prescriptionId"
                @click="doDelete(group.prescriptionId)"
              >
                {{ deletingId === group.prescriptionId ? 'Deleting…' : 'Delete' }}
              </button>
            </td>
          </tr>
          <tr v-for="(param, idx) in group.parametersArray" :key="`${group.prescriptionId}-${idx}`" class="rx-row">
            <td></td>
            <td></td>
            <td>{{ group.prescriptionId }}</td>
            <td>{{ param.parameter_name }}</td>
            <td>{{ param.parameter_value }}</td>
            <td>{{ param.parameter_type }}</td>
            <td>{{ param.parameter_tolerance }}</td>
            <td></td>
          </tr>
        </template>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.header-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1rem;
  flex-wrap: wrap;
  gap: 0.5rem;
}
.list-view h2 {
  margin: 0;
}
.btn {
  padding: 0.4rem 0.75rem;
  border-radius: 4px;
  border: 1px solid var(--border);
  background: var(--code-bg);
  color: var(--text);
  cursor: pointer;
  font-size: 0.9rem;
}
.btn:hover {
  background: var(--border);
}
.btn-primary {
  background: var(--accent-bg);
  color: #fff;
  border-color: var(--accent-border);
}
.btn-primary:hover {
  filter: brightness(1.1);
}
.btn-sm {
  padding: 0.2rem 0.5rem;
  font-size: 0.8rem;
}
.btn-danger {
  background: #b91c1c;
  color: #fff;
  border-color: #b91c1c;
  margin-left: 0.5rem;
}
.btn-danger:hover:not(:disabled) {
  filter: brightness(1.1);
}
.btn-danger:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}
.card {
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 1rem;
  margin-bottom: 1rem;
  background: var(--code-bg);
}
.create-form h3 {
  margin-top: 0;
  margin-bottom: 0.75rem;
}
.form-row {
  margin-bottom: 0.75rem;
}
.form-row label {
  display: block;
  font-weight: 500;
  margin-bottom: 0.25rem;
  font-size: 0.9rem;
}
.form-row select,
.form-row input[type="text"],
.form-row input[type="number"],
.form-row input[type="datetime-local"] {
  width: 100%;
  max-width: 24rem;
  padding: 0.4rem 0.5rem;
  border: 1px solid var(--border);
  border-radius: 4px;
  background: var(--bg);
  color: var(--text);
}
.params-list {
  max-width: 36rem;
}
.param-header {
  display: flex;
  gap: 0.5rem;
  align-items: center;
  margin-bottom: 0.25rem;
  font-weight: 600;
  font-size: 0.85rem;
  color: var(--text-h);
}
.param-header span {
  flex: 1;
  min-width: 4rem;
}
.param-header span:last-child {
  min-width: 4.5rem;
}
.param-row {
  display: flex;
  gap: 0.5rem;
  align-items: center;
  margin-bottom: 0.5rem;
  flex-wrap: wrap;
}
.param-row input {
  flex: 1;
  min-width: 4rem;
  padding: 0.3rem 0.4rem;
  border: 1px solid var(--border);
  border-radius: 4px;
  background: var(--bg);
  color: var(--text);
}
.form-actions {
  margin-top: 1rem;
  display: flex;
  gap: 0.5rem;
}
.success-msg {
  color: #059669;
  font-size: 0.9rem;
  margin-bottom: 0.5rem;
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
