<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Carbon\Carbon;

class HistoryEventWriter
{
    /**
     * Write an immutable audit event.
     *
     * @param array $data
     * @return void
     */
    public static function write(array $data): void
    {
        $now = $data['occurred_at'] ?? Carbon::now()->utc();

        // Fetch previous hash (last event for tenant)
        $prevHash = DB::table('history_events')
            ->where('tenant_id', $data['tenant_id'])
            ->orderByDesc('id')
            ->value('event_hash');

        if ($prevHash === null) {
            // Genesis hash (32 zero bytes)
            $prevHash = hex2bin(str_repeat('00', 64));
        }

        // Build canonical payload string
        $payload = self::canonicalPayload([
            'occurred_at' => $now->format('Y-m-d H:i:s.u'),
            'tenant_id'   => $data['tenant_id'],
            'actor_type'  => $data['actor_type'],
            'actor_id'    => $data['actor_id'] ?? '',
            'actor_label' => $data['actor_label'] ?? '',
            'ip'          => $data['ip'] ?? '',
            'user_agent'  => $data['user_agent'] ?? '',
            'request_id'  => $data['request_id'] ?? '',
            'event_type'  => $data['event_type'],
            'entity_type' => $data['entity_type'],
            'entity_id'   => $data['entity_id'] ?? '',
            'action'      => $data['action'],
            'before_json' => self::stableJson($data['before_json'] ?? null),
            'after_json'  => self::stableJson($data['after_json'] ?? null),
            'diff_json'   => self::stableJson($data['diff_json'] ?? null),
        ]);

        // Compute event hash (raw binary)
        $eventHash = hash('sha256', $prevHash . $payload, true);

        // Insert (append-only)
        DB::table('history_events')->insert([
            'occurred_at' => $now,
            'tenant_id'   => $data['tenant_id'],
            'actor_type'  => $data['actor_type'],
            'actor_id'    => $data['actor_id'] ?? null,
            'actor_label' => $data['actor_label'] ?? null,
            'ip'          => $data['ip'] ?? null,
            'user_agent'  => $data['user_agent'] ?? null,
            'request_id'  => $data['request_id'] ?? (string) Str::uuid(),

            'event_type'  => $data['event_type'],
            'entity_type' => $data['entity_type'],
            'entity_id'   => $data['entity_id'] ?? null,
            'action'      => $data['action'],

            'before_json' => $data['before_json'] ?? null,
            'after_json'  => $data['after_json'] ?? null,
            'diff_json'   => $data['diff_json'] ?? null,

            'prev_hash'   => $prevHash,
            'event_hash'  => $eventHash,
        ]);
    }

    /**
     * Build a deterministic canonical payload string.
     */
    private static function canonicalPayload(array $fields): string
    {
        ksort($fields);

        return implode('|', array_map(
            fn ($v) => (string) $v,
            $fields
        ));
    }

    /**
     * Stable JSON encoding with sorted keys.
     */
    private static function stableJson($value): string
    {
        if ($value === null) {
            return '';
        }

        return json_encode(
            self::sortKeysRecursive($value),
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
        );
    }

    /**
     * Recursively sort JSON keys.
     */
    private static function sortKeysRecursive($data)
    {
        if (is_array($data)) {
            ksort($data);
            foreach ($data as $k => $v) {
                $data[$k] = self::sortKeysRecursive($v);
            }
        }

        return $data;
    }
}
