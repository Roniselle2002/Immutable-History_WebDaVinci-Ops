-- 15 Query Packs for Immutable History in WebDaVinci Ops

-- 1. Who changed reservation X?
SELECT
  occurred_at,
  actor_type,
  actor_id,
  actor_label,
  action,
  before_json,
  after_json
FROM history_events
WHERE tenant_id = tenant_id
  AND entity_type = 'reservation'
  AND entity_id = reservation_id
ORDER BY occurred_at ASC;

-- 2. Latest change to a reservation
SELECT *
FROM history_events
WHERE tenant_id = tenant_id
  AND entity_type = 'reservation'
  AND entity_id = reservation_id
ORDER BY occurred_at DESC
LIMIT 1;

-- 3. All reservation changes in last 7 days
SELECT *
FROM history_events
WHERE tenant_id = tenant_id
  AND entity_type = 'reservation'
  AND occurred_at >= UTC_TIMESTAMP() - INTERVAL 7 DAY
ORDER BY occurred_at DESC;

-- 4. All pricing / rate changes
SELECT
  occurred_at,
  actor_type,
  actor_label,
  entity_id AS rate_id,
  before_json,
  after_json
FROM history_events
WHERE tenant_id = tenant_id
  AND event_type IN ('rate.changed', 'pricing.updated')
ORDER BY occurred_at DESC;

-- 5. Pricing changes by automation vs humans
SELECT
  actor_type,
  COUNT(*) AS change_count
FROM history_events
WHERE tenant_id = tenant_id
  AND event_type = 'rate.changed'
GROUP BY actor_type;

-- 6. Guest information changes
SELECT
  occurred_at,
  actor_label,
  before_json,
  after_json
FROM history_events
WHERE tenant_id = tenant_id
  AND entity_type = 'guest'
  AND action = 'update'
ORDER BY occurred_at DESC;

-- 7. Refunds and charge adjustments
SELECT *
FROM history_events
WHERE tenant_id = tenant_id
  AND event_type IN ('refund.processed', 'charge.adjusted')
ORDER BY occurred_at DESC;

-- 8. Admin permission changes
SELECT
  occurred_at,
  actor_label,
  before_json,
  after_json
FROM history_events
WHERE tenant_id = tenant_id
  AND event_type = 'permission.changed'
ORDER BY occurred_at DESC;

-- 9. Data exports (CSV / Excel / PDF)
SELECT
  occurred_at,
  actor_label,
  event_type,
  entity_type
FROM history_events
WHERE tenant_id = tenant_id
  AND action = 'action'
  AND event_type LIKE '%export%'
ORDER BY occurred_at DESC;

-- 10. Exports by specific user
SELECT *
FROM history_events
WHERE tenant_id = tenant_id
  AND action = 'action'
  AND event_type LIKE '%export%'
  AND actor_id = user_id
ORDER BY occurred_at DESC;

-- 11. Login failures
SELECT
  occurred_at,
  actor_label,
  ip,
  user_agent
FROM history_events
WHERE tenant_id = tenant_id
  AND event_type = 'login.failed'
ORDER BY occurred_at DESC;

-- 12. Events tied to a single request (correlation)
SELECT *
FROM history_events
WHERE request_id = request_id
ORDER BY occurred_at ASC;

-- 13. All actions by a specific actor
SELECT *
FROM history_events
WHERE tenant_id = tenant_id
  AND actor_type = 'user'
  AND actor_id = actor_id
ORDER BY occurred_at DESC;

-- 14. Detect missing or broken history (sanity check)
SELECT COUNT(*) AS total_events
FROM history_events
WHERE tenant_id = tenant_id;

-- 15. Oldest and newest audit records (retention)
SELECT
  MIN(occurred_at) AS oldest_event,
  MAX(occurred_at) AS newest_event
FROM history_events
WHERE tenant_id = tenant_id;
