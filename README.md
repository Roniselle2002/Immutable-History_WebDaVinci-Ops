# WebDaVinci Ops – Immutable (Append-Only) Audit History

## Overview

This project implements an **append-only, tamper-evident audit/history system** for WebDaVinci Ops using **MySQL + Laravel**. It records business‑critical events (CRUD + non‑CRUD actions) in a way that is:

* Append-only for the application user
* Tamper‑evident via SHA‑256 hash chaining
* Queryable and performant
* Tenant‑safe (single‑tenant DB per park or `tenant_id` in shared DB)

This design is compatible with **shared hosting environments (e.g., Hostinger)** and avoids server‑level features or plugins.

---

## Objectives

* Capture critical operational events (reservations, pricing, permissions, exports, logins)
* Prevent application‑level modification (UPDATE/DELETE)
* Detect any manual tampering by privileged users
* Provide a clean query surface for operations and audit reviews

---

## Architecture Summary

**Layers:**

1. **Database layer (MySQL / InnoDB)**

   * `history_events` append‑only table
   * Defensive triggers blocking UPDATE/DELETE
   * Restricted DB privileges for the app user

2. **Application layer (Laravel)**

   * Single write helper: `HistoryEventWriter`
   * Centralized canonical payload & hash computation

3. **Verification layer (CLI)**

   * Standalone PHP script to verify hash chain integrity

---

## Database Design

### Table: `history_events`

Stores immutable audit records.

**Key characteristics:**

* Auto‑incrementing primary key for ordering
* UTC timestamps with microsecond precision
* JSON snapshots for before/after/diff
* SHA‑256 hash chaining for tamper detection

**Key columns:**

* Identity & ordering: `id`, `occurred_at`
* Multi‑tenant: `tenant_id`
* Actor context: `actor_type`, `actor_id`, `actor_label`, `ip`, `user_agent`, `request_id`
* Event context: `event_type`, `entity_type`, `entity_id`, `action`
* State capture: `before_json`, `after_json`, `diff_json`
* Tamper evidence: `prev_hash`, `event_hash`

Indexes are intentionally minimal to balance write performance and audit queries.

---

## Append‑Only Enforcement

### Permissions (R1)

* Application DB user:

  * `INSERT`, `SELECT` only on `history_events`
  * **No** `UPDATE` or `DELETE`

### Triggers (Defense‑in‑Depth)

* `BEFORE UPDATE` → raise error
* `BEFORE DELETE` → raise error

Even if permissions are accidentally widened later, triggers still block mutation.

> Note: A true MySQL superuser can still modify data. Tamper‑evidence addresses this risk.

---

## Tamper‑Evident Hash Chain (R3)

Each row contains:

* `prev_hash` – hash of the previous event
* `event_hash` – SHA‑256(prev_hash + canonical_payload)

### Canonical Payload

The payload includes (at minimum):

* occurred_at
* tenant_id
* actor_* fields
* event_type, entity_*, action
* before_json, after_json, diff_json

JSON is **normalized** by the application to ensure stable hashing.

Any modification of a historical row will break the chain.

---

## Coverage Rules (R4)

### Must Log

* Reservation create / update / cancel
* Guest information changes
* Rate & pricing changes (manual or automated)
* Refunds & charge adjustments
* Admin permission changes
* Data exports (CSV / Excel / PDF)
* Login failures & impersonation events

### Must NOT Log

* Raw card data
* Passwords
* Secrets or tokens

### Redaction

* Sensitive fields should be masked or represented only in diffs

---

## Laravel Write Helper

**File:** `app/Services/HistoryEventWriter.php`

Responsibilities:

* Build canonical payload
* Fetch previous event hash
* Compute SHA‑256 hash
* Insert a single immutable row

All audit writes must go through this helper.

---

## Verification Script

**File:** `verify_history_chain.php`

**Purpose:**

* Walk the audit table in ID order
* Recompute hashes
* Detect the first broken link

**Behavior:**

* Clean DB → verification passes silently
* Any tampering → reports offending row ID

This script is intentionally **standalone** and read‑only.

---

## Query Pack

A set of operational and audit queries supports:

* "Who changed reservation X?"
* "All pricing changes in the last 7 days"
* "Exports by user"
* "Permission changes"

Queries rely on indexed columns only.

---

## Performance & Retention (R5)

* Inserts are lightweight and non‑blocking
* No foreign keys to hot tables
* JSON fields allow flexibility without schema churn

**Retention:**

* Minimum: 12–24 months for ops audit
* Longer retention recommended for compliance/defensibility

Partitioning by month is optional and not required early.

---

## How to Validate the System

1. Insert events using `HistoryEventWriter`
2. Confirm no UPDATE/DELETE allowed for app user
3. Run verification script (passes)
4. Manually tamper a row using admin credentials
5. Run verification script again (fails at tampered row)

---

## Security Notes

* Hash chain provides **tamper evidence**, not absolute immutability
* Stronger guarantees can be achieved later by exporting events to WORM storage or an external append‑only log service

---

## Status

This implementation satisfies:

* R1 – Append‑only enforcement
* R2 – Event schema
* R3 – Tamper‑evident hashing
* R4 – Coverage rules
* R5 – Performance & retention planning

---

## Author / Context

Implemented as part of an OJT task for WebDaVinci Ops to establish a robust, reviewable audit foundation suitable for production environments on shared hosting platforms.
