# Admin Control RPC Contracts

These database RPCs are the shared backend contract for web and Flutter clients.

## 1) admin_dashboard_metrics
Returns an aggregated admin dashboard snapshot for the selected time window.

Input:
- `p_days` integer (1-365), default 30

Output (JSONB):
- `window_days`
- `generated_at`
- `users_total`
- `providers_total`
- `bookings_total`
- `bookings_completed`
- `bookings_cancelled`
- `gmv_lkr_window`
- `reports_open`
- `moderation_pending`
- `rides_open`
- `wallet_volume_lkr_window`

## 2) admin_update_listing_moderation
Updates moderation status across all listing verticals via one RPC.

Input:
- `p_listing_type` text: `stay|vehicle|event|property|social|sme`
- `p_listing_id` uuid
- `p_moderation_status` text: `pending|approved|rejected|suspended`
- `p_admin_note` text (optional)
- `p_active` boolean (optional, default true)

Output:
- void

## 3) admin_resolve_user_report
Resolves or updates investigation state of user reports.

Input:
- `p_report_id` uuid
- `p_status` text: `pending|investigating|resolved|dismissed`
- `p_admin_note` text (optional)

Output:
- void

## 4) is_admin
Checks if a user is admin.

Input:
- `p_user_id` uuid (optional; defaults to `auth.uid()`)

Output:
- boolean

## 5) admin_log_action
Writes structured action logs to `admin_actions`.

Input:
- `p_action_type` text
- `p_target_type` text
- `p_target_id` uuid
- `p_details` jsonb (optional)

Output:
- void

## Feature flags table contract
Table: `public.admin_feature_flags`

Columns:
- `flag_key` (unique)
- `enabled`
- `payload` (jsonb)
- `description`
- `updated_by`
- `created_at`
- `updated_at`

Read/Write:
- Admin-only via RLS policies.
