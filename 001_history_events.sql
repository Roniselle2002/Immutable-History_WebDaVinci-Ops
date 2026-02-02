-- Defensive triggers to enforce append-only behavior
-- Immutable / Append-Only History Events Table
-- Engine: InnoDB
-- Purpose: Business-critical audit logging with tamper-evident hash chaining

CREATE TABLE history_events (
    -- Identity & ordering
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    occurred_at DATETIME(6) NOT NULL COMMENT 'UTC timestamp when the event occurred',

    -- Multi-tenant (omit if truly single-tenant DB)
    tenant_id BIGINT UNSIGNED NOT NULL,

    -- Actor (who/what performed the action)
    actor_type ENUM('user','staff','system','integration','api_key') NOT NULL,
    actor_id BIGINT UNSIGNED NULL,
    actor_label VARCHAR(255) NULL COMMENT 'Snapshot of name/email at time of event',
    ip VARBINARY(16) NULL COMMENT 'IPv4 or IPv6',
    user_agent VARCHAR(512) NULL,
    request_id CHAR(36) NULL COMMENT 'Request / correlation ID',

    -- What happened
    event_type VARCHAR(80) NOT NULL COMMENT 'e.g. reservation.updated',
    entity_type VARCHAR(80) NOT NULL COMMENT 'e.g. reservation, guest',
    entity_id BIGINT UNSIGNED NULL,
    action ENUM('create','update','delete','action') NOT NULL,

    -- Change payloads
    before_json JSON NULL,
    after_json JSON NULL,
    diff_json JSON NULL,

    -- Tamper-evident hash chain
    prev_hash BINARY(32) NOT NULL COMMENT 'SHA-256 hash of previous event',
    event_hash BINARY(32) NOT NULL COMMENT 'SHA-256 hash of this event',

    PRIMARY KEY (id),

    -- Indexes for audit / ops queries
    KEY idx_tenant_occurred (tenant_id, occurred_at),
    KEY idx_tenant_entity (tenant_id, entity_type, entity_id, occurred_at),
    KEY idx_tenant_event_type (tenant_id, event_type, occurred_at),
    KEY idx_request_id (request_id)

) ENGINE=InnoDB
  COMMENT='Append-only, tamper-evident audit history for WebDaVinci Ops';
