-- Append-only permissions for history_events
-- Hostinger / shared MySQL compatible

USE webdavinci_ops;

-- Grant ONLY the required privileges
GRANT SELECT, INSERT
ON webdavinci_ops.history_events
TO 'app_user'@'%';

FLUSH PRIVILEGES;
