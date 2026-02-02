-- Defensive triggers to enforce append-only behavior
-- Even if UPDATE/DELETE privileges are accidentally granted later

DELIMITER $$

CREATE TRIGGER history_events_block_update
BEFORE UPDATE ON history_events
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'UPDATE is not allowed on history_events (append-only table)';
END$$

CREATE TRIGGER history_events_block_delete
BEFORE DELETE ON history_events
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'DELETE is not allowed on history_events (append-only table)';
END$$

DELIMITER ;
