/**
 * Demonstration guide: how to use the Healthcare Demo UI.
 * Rendered as markdown on the Demonstration page.
 */
export const demonstrationMarkdown = `
# How to Use the Healthcare Demo

This guide walks you through the demo user interface and how to run the demonstration.

## Overview

The **Healthcare Demo** UI lets you:

- Browse **patients**, **devices**, and **prescriptions** (demo data from the backend).
- Control the **device telemetry simulation** and watch live telemetry in the browser.
- Follow this **Demonstration** page for step-by-step instructions.

---

## 1. Start the Local Solution

From the **repo root**:

\`\`\`bash
# Copy and edit backend/.env with Kafka and Schema Registry credentials (see backend/.env.example)
cp backend/.env.example backend/.env

docker compose up -d
\`\`\`


Open the app in your browser (e.g. **http://localhost:5173**). The frontend proxies API requests to the backend when running in dev mode.

---

## 2. Deploy the Real-time processing in Flink


---

## 3. Use the Navigation

Use the **left sidebar** to move between pages:

| Page | What it does |
|------|----------------|
| **Home** | Welcome and short overview. |
| **Patients** | Lists patients (ID, name, gender, birth date, zip). Data comes from the backend. |
| **Devices** | Lists devices (ID, patient, pressure/flow settings). |
| **Prescriptions** | Lists prescriptions **grouped by device** (device row + metric targets). |
| **Device telemetry** | Start/stop the simulation and connect to the **live telemetry stream**. |

---

## 4. Run the Telemetry Simulation

1. Go to **Device telemetry** in the sidebar.
2. Check **Simulation control**:
   - Click **Start simulation** to begin producing device telemetry (to Kafka and to the in-browser stream).
   - Click **Stop simulation** to stop.
3. (Optional) Click **Connect stream** to subscribe to live telemetry. Events appear in the table (device, patient, metric, value). Use **Pause** / **Resume** or **Clear** as needed.

The simulation uses the same patient and device IDs as in the **Patients** and **Devices** lists, so you can correlate live metrics with the catalog.

---

## Architecture (Reference)

The demo backend produces Avro telemetry to **Confluent Cloud Kafka** (topic \`device_metrics\`) and exposes the same data via **SSE** for the UI. The frontend does not connect to Kafka directly; it uses the backend REST API and telemetry stream.

For pipeline architecture and component diagrams, see the main **README** in the repo.

---

## Demo Components (Diagram)

![Demo components](/demo/demo_components.png)
`
