/** Mock data aligned with README domain classes. Replace with API calls when backend endpoints exist. */

export const mockPatients = [
  { patientId: 'P001', name: 'Alice Smith', gender: 'F', birthDate: '1980-05-12', zipCode: '15201' },
  { patientId: 'P002', name: 'Bob Jones', gender: 'M', birthDate: '1975-11-03', zipCode: '15206' },
  { patientId: 'P003', name: 'Carol White', gender: 'F', birthDate: '1990-02-28', zipCode: '15217' },
  { patientId: 'P004', name: 'David Lee', gender: 'M', birthDate: '1988-07-19', zipCode: '15222' },
  { patientId: 'P005', name: 'Eve Brown', gender: 'F', birthDate: '1982-09-05', zipCode: '15232' },
]

export const mockDevices = [
  { device_id: 'DEV-P001', patientId: 'P001', pressureSetting: 10.0, flowRateSetting: 2.5, flowLevel: 120 },
  { device_id: 'DEV-P002', patientId: 'P002', pressureSetting: 12.0, flowRateSetting: 2.8, flowLevel: 160 },
  { device_id: 'DEV-P003', patientId: 'P003', pressureSetting: 8.0, flowRateSetting: 2.0, flowLevel: 200 },
  { device_id: 'DEV-P004', patientId: 'P004', pressureSetting: 11.0, flowRateSetting: 2.6, flowLevel: 240 },
  { device_id: 'DEV-P005', patientId: 'P005', pressureSetting: 9.5, flowRateSetting: 2.3, flowLevel: 120 },
]

/** One prescription per device; parameters = JSON string of array of { parameter_name, parameter_value, parameter_type, parameter_tolerance }. */
export const mockPrescriptions = [
  {
    prescriptionId: 'RX-DEV-P001',
    patientId: 'P001',
    deviceId: 'DEV-P001',
    medicationOrTherapy: 'CPAP Oxygen Flow',
    startDate: 1710000000000,
    endDate: 1741536000000,
    parameters: '[{"parameter_name":"Pressure","parameter_value":10,"parameter_type":"float","parameter_tolerance":1},{"parameter_name":"FlowRate","parameter_value":2.5,"parameter_type":"float","parameter_tolerance":0.5},{"parameter_name":"FlowLevel","parameter_value":150,"parameter_type":"float","parameter_tolerance":50}]',
  },
  {
    prescriptionId: 'RX-DEV-P002',
    patientId: 'P002',
    deviceId: 'DEV-P002',
    medicationOrTherapy: 'CPAP Oxygen Flow',
    startDate: 1710000000000,
    endDate: 1741536000000,
    parameters: '[{"parameter_name":"Pressure","parameter_value":12,"parameter_type":"float","parameter_tolerance":1},{"parameter_name":"FlowRate","parameter_value":2.8,"parameter_type":"float","parameter_tolerance":0.5},{"parameter_name":"FlowLevel","parameter_value":150,"parameter_type":"float","parameter_tolerance":50}]',
  },
  {
    prescriptionId: 'RX-DEV-P003',
    patientId: 'P003',
    deviceId: 'DEV-P003',
    medicationOrTherapy: 'CPAP Oxygen Flow',
    startDate: 1710000000000,
    endDate: 1741536000000,
    parameters: '[{"parameter_name":"Pressure","parameter_value":8,"parameter_type":"float","parameter_tolerance":1},{"parameter_name":"FlowRate","parameter_value":2,"parameter_type":"float","parameter_tolerance":0.5},{"parameter_name":"FlowLevel","parameter_value":150,"parameter_type":"float","parameter_tolerance":50}]',
  },
]
