<?php

$pdo = new PDO(
    'mysql:host=127.0.0.1;dbname=laravel;charset=utf8mb4',
    'root',
    '',
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ]
);

$stmt = $pdo->query(
    "SELECT *
     FROM history_events
     ORDER BY id ASC"
);

$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

$expectedPrevHash = hex2bin(str_repeat('00', 64));
$rowNumber = 0;

foreach ($rows as $row) {
    $rowNumber++;

    // 1. Check prev_hash matches expectation
    if ($row['prev_hash'] !== $expectedPrevHash) {
        echo "❌ Chain broken at row ID {$row['id']} (prev_hash mismatch)\n";
        exit(1);
    }

    // 2. Rebuild canonical payload
    $payload = canonicalPayload([
        'occurred_at' => $row['occurred_at'],
        'tenant_id'   => $row['tenant_id'],
        'actor_type'  => $row['actor_type'],
        'actor_id'    => $row['actor_id'] ?? '',
        'actor_label' => $row['actor_label'] ?? '',
        'ip'          => $row['ip'] ?? '',
        'user_agent'  => $row['user_agent'] ?? '',
        'request_id'  => $row['request_id'] ?? '',
        'event_type'  => $row['event_type'],
        'entity_type' => $row['entity_type'],
        'entity_id'   => $row['entity_id'] ?? '',
        'action'      => $row['action'],
        'before_json' => stableJson($row['before_json']),
        'after_json'  => stableJson($row['after_json']),
        'diff_json'   => stableJson($row['diff_json']),
    ]);

    // 3. Recompute hash
    $recomputedHash = hash(
        'sha256',
        $expectedPrevHash . $payload,
        true
    );

    // 4. Compare hashes
    if ($recomputedHash !== $row['event_hash']) {
        echo "❌ Hash mismatch at row ID {$row['id']}\n";
        exit(1);
    }

    // 5. Advance chain
    $expectedPrevHash = $row['event_hash'];
}

echo "✅ History chain verified successfully ({$rowNumber} rows)\n";


// ---------------- Helper functions ----------------

function canonicalPayload(array $fields): string
{
    ksort($fields);
    return implode('|', array_map('strval', $fields));
}

function stableJson($json): string
{
    if ($json === null || $json === '') {
        return '';
    }

    $data = json_decode($json, true);
    if ($data === null) {
        return '';
    }

    sortKeysRecursive($data);
    return json_encode($data, JSON_UNESCAPED_UNICODE);
}

function sortKeysRecursive(&$data): void
{
    if (!is_array($data)) {
        return;
    }

    ksort($data);
    foreach ($data as &$value) {
        sortKeysRecursive($value);
    }
}
