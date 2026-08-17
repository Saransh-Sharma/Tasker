# Cloud EVA Documentation

Cloud EVA is LifeBoard's optional, 18+, user-controlled Luna intelligence layer with independently controlled `tts-1` spoken output. Offline EVA remains available through explicitly selected MLX models, while dictation/transcription remains on Apple's stack.

Use these documents by job:

| Need | Document |
|---|---|
| Understand the product and system end to end | [Product and Technical Guide](./CLOUD_EVA_PRODUCT_AND_TECHNICAL_GUIDE.md) |
| Implement or integrate a client | [API Contract](./API_CONTRACT.md) |
| Provision, deploy, observe, or roll back | [Backend Runbook](./BACKEND_RUNBOOK.md) |
| Review consent, processors, retention, or deletion | [Privacy and Data Flow](./PRIVACY_AND_DATA_FLOW.md) |
| Respond to an outage, safety, privacy, auth, or cost event | [Incident Runbook](./INCIDENT_RUNBOOK.md) |
| Decide whether production is ready | [Migration TODO](./EVA_CLOUD_MIGRATION_TODO.md) and [Risk Register](./RISK_REGISTER.md) |
| Shape future intelligence investment | [EVA and the Ultimate Life OS Roadmap](./LIFE_OS_PRODUCT_ROADMAP.md) |

Canonical machine-readable wire schemas and fixtures live in `Shared/EVACloudContracts`. Source and tests override prose when they disagree; correcting the prose is part of the same change. Future ideas are not shipped claims until they graduate into the current Feature Catalog with verification evidence.
