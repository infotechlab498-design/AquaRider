# Locked V1 — W18 Communication & W19 Audit Trail

## Scope

| Module | Locked V1 behaviour |
|---|---|
| **W18** | Transactional **SMS** templates, history, enqueue/retry, gateway status. Gateway remains **NotConfigured** until real provider credentials exist server-side. No WhatsApp, no marketing blasts, no fabricated Delivered status. |
| **W19** | Read-only **AuditLogs** stream + dossier. CSV export. Hash verify returns **VerificationUnavailable** (no stored hashes). No fabricated IP/device/diffs/Knox/Merkle. |

## Roles

Admin JWT role only for HQ APIs. Riders receive 403.

## APIs

- `GET/POST /api/admin/audit/*`
- `GET/POST/PUT /api/admin/communication/*`

## Integrity trust boundary

AuditLog integrity is application-level immutability (no update/delete endpoints). Cryptographic hash chaining is **not** claimed until hashes are written at event creation.
