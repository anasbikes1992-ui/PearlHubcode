# 🔧 Operations Guide - PearlHub Production

**Status**: Phase 1 Launch  
**Audience**: Developers, DevOps, Operations Team

---

## Daily Operations Checklist

### Morning (7 AM Sri Lanka Time)

- [ ] Check Supabase dashboard for errors in last 24 hours
- [ ] Review payment success/failure metrics
- [ ] Check user feedback channels (support email, in-app reports)
- [ ] Verify Edge Functions latency (target: < 500ms p95)

### Throughout Day

- [ ] Monitor real-time payment transactions
- [ ] Respond to support tickets
- [ ] Watch for error spikes

### Evening (6 PM Sri Lanka Time)

- [ ] Generate daily ops report
- [ ] Backup database
- [ ] Archive logs

---

## 1. Payment Flow Monitoring

### Real-Time Payment Dashboard Query

```sql
-- Run in Supabase SQL editor
SELECT 
  DATE(created_at) as date,
  COUNT(*) as total,
  COUNT(CASE WHEN status = 'paid' THEN 1 END) as paid,
  COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed,
  ROUND(100.0 * COUNT(CASE WHEN status = 'paid' THEN 1 END) / COUNT(*), 2) as success_rate_pct,
  SUM(CASE WHEN status = 'paid' THEN amount / 100 ELSE 0 END) as total_revenue_lkr
FROM payment_transactions
WHERE created_at > NOW() - INTERVAL '7 day'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

### Payment States State Machine

```
PENDING
    ↓ (user pays in PayHere)
PROCESSING
    ↓ (webhook received)
PAID (success) or FAILED (error)
    ↓ (booking state updated)
CANCELLED (refund initiated)
```

### Common Payment Failures

| Status Code | Meaning | Action |
| --- | --- | --- |
| 1 | Subscription active | Normal; no action needed |
| 2 | Payment success | Normal; booking marked paid |
| -1 | Payment cancelled | User abandoned; retry later |
| -2 | Payment failed | Inspect reason; notify user |
| -3 | Invalid payment | Fraud check; escalate |

---

## 2. Handling Failed Payments

### If Payment Never Confirmed

**Symptoms**:
- User reports payment processed but booking not created
- `payment_transactions` has `status='processing'` for >5 min

**Debug**:
1. Check webhook logs in Supabase dashboard
2. Manually verify with PayHere API

**Fix** (manual):
```sql
-- Mark payment as successful if confirmed with PayHere
UPDATE payment_transactions
SET status = 'paid', verified_at = NOW()
WHERE order_id = 'PAYHERE_ORDER_ID' AND status = 'processing';

-- Then create/update booking
UPDATE bookings
SET payment_status = 'paid'
WHERE id = (
  SELECT booking_id FROM payment_transactions 
  WHERE order_id = 'PAYHERE_ORDER_ID'
);
```

### If Webhook Keeps Failing

**Symptoms**:
- PayHere webhook calls failing repeatedly
- Payment marked failed in PayHere but `payment_transactions.status` still 'processing'

**Debug**:
1. Check `payment-webhook` Edge Function logs
2. Verify merchant credentials in Supabase secrets
3. Test with curl:
   ```bash
   curl -X POST https://YOUR_PROJECT_ID.supabase.co/functions/v1/payment-webhook \
     -H "Authorization: Bearer YOUR_FUNCTION_KEY" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "merchant_id=MERCHANT_ID&order_id=TEST&amount=10000&status_code=2&md5sig=..."
   ```

**Fix**:
1. Update PayHere credentials in Supabase secrets
2. Restart Edge Functions: In dashboard → Functions → Redeploy payment-webhook
3. Re-send webhook from PayHere Resend button

---

## 3. Refund Handling

### Partial Refund

```sql
-- Insert refund transaction
INSERT INTO wallet_transactions (user_id, transaction_type, amount, description, status)
VALUES (
  'USER_ID',
  'payment_refund',
  -5000,  -- Negative amount
  'Refund for cancelled booking #12345',
  'completed'
);

-- Mark booking cancelled
UPDATE bookings SET status = 'cancelled' WHERE id = '12345';

-- Mark payment refunded
INSERT INTO payment_transactions (
  order_id, booking_id, amount, status, payment_method
) VALUES (
  'REFUND_REF_' || gen_random_uuid(),
  '12345',
  -5000,
  'refunded',
  'payhere_refund'
);
```

### Full Refund via PayHere

1. Login to PayHere Dashboard
2. Find transaction
3. Click "Refund"
4. Confirm amount
5. **Then** update database:
   ```sql
   UPDATE payment_transactions SET status = 'refunded' WHERE order_id = '...';
   ```

---

## 4. Emergency Procedures

### Kill Switch: Disable All Payments

If critical security issue or system failure:

```sql
-- Set feature flag to disable checkout
INSERT INTO platform_config (key, value)
VALUES ('payments_enabled', 'false')
ON CONFLICT (key) DO UPDATE SET value = 'false';
```

Then update app to show:
```jsx
{paymentEnabled === false && (
  <Alert severity="error">
    Payments temporarily disabled for maintenance. Try again later.
  </Alert>
)}
```

### Database Backup & Restore

**Automatic backups** (daily):
- Enabled by default in Supabase
- Retention: 7 days
- Location: Supabase dashboard → Settings → Backups

**Manual backup**:
```bash
supabase db dump --db-url "postgresql://..." > backup-$(date +%Y%m%d).sql
```

**Restore**:
```bash
psql -U postgres -d postgres -h localhost < backup-20260325.sql
```

### RLS Policy Debugging

If users can't see their bookings:

```sql
-- Check what user can see
SELECT * FROM bookings 
WHERE auth.uid() = user_id;  -- Should return rows

-- Check policy
SELECT * FROM pg_policies 
WHERE tablename = 'bookings' 
AND policyname = 'Users can read own bookings';

-- If missing, recreate:
CREATE POLICY "Users can read own bookings" ON bookings
FOR SELECT TO authenticated
USING (auth.uid() = user_id);
```

---

## 5. Monitoring & Alerts

### Key Metrics

**Payment Success Rate**:
```sql
SELECT 
  100.0 * COUNT(CASE WHEN status='paid' THEN 1 END) / COUNT(*)
FROM payment_transactions
WHERE created_at > NOW() - INTERVAL '1 hour';
-- Target: > 95%
```

**Edge Function Latency**:
- View in Supabase dashboard → Logs → Functions
- Filter: `create-payhere-session`, `payment-webhook`
- Target: < 500ms p95

**Database Connection Pool**:
- View in Supabase dashboard → Monitor → Connections
- Target: < 80% utilization

### Email Alerts (Setup in Supabase)

1. Go to Supabase → Settings → Notifications
2. Add email for alerts
3. Configure alerts:
   - Payment failures spike > 10% in 1 hour
   - Edge Function errors > 5
   - Database connections > 90%
   - Auth failures spike

---

## 6. Scaling & Performance

### When to Scale

| Metric | Threshold | Action |
| --- | --- | --- |
| Booking creation avg latency | > 1 second | Scale database compute |
| Edge Function concurrent errors | > 10 | Increase function memory |
| Database CPU | > 80% | Add read replicas |
| Storage | > 80% used | Archive/delete old logs |

### Scale Database Compute

```bash
supabase projects update --compute-size large
# Or in dashboard: Settings → Compute Size → Change
```

### Scale Edge Functions

Edge Functions auto-scale; no manual action needed. Monitor latency and adjust if necessary.

---

## 7. User Support Scenarios

### "My payment failed"

**Check**:
```sql
SELECT * FROM payment_transactions 
WHERE order_id = 'USER_PROVIDED_ID';
```

**Actions**:
- If `status = 'failed'`: Ask user to try again
- If `status = 'paid'`: Check if booking was created; if not, manually create
- If `status = 'processing'`: Check logs; if >10 min old, manually verify with PayHere

### "My booking wasn't created"

**Check**:
```sql
SELECT * FROM bookings WHERE user_id = 'USER_ID' ORDER BY created_at DESC LIMIT 5;
```

**Actions**:
- If no booking: Ask user to try payment again
- If booking exists: User may not have seen confirmation; send email
- If multiple attempts: Check for circuit breaker; may need manual investigation

### "I need to cancel my booking"

```sql
UPDATE bookings SET status = 'cancelled' WHERE id = 'BOOKING_ID';
-- And process refund (see Refund Handling above)
```

---

## 8. Security Incidents

### Potential Attack: Fake Webhook

**Detection**:
- Sudden spike in payment_transactions with `status='processing'` but no user complaints
- Webhook requests from unfamiliar IP

**Response**:
1. Block IP in Vercel/Edge Function firewall
2. Review webhook signature verification in `payment-webhook/index.ts`
3. Query suspicious transactions:
   ```sql
   SELECT * FROM payment_transactions 
   WHERE created_at > (NOW() - INTERVAL '1 hour')
   AND status = 'processing'
   AND (
     amount > 1000000
     OR merchant_id NOT IN (SELECT value FROM platform_config WHERE key = 'payhere_merchant_id')
   );
   ```

### Potential Attack: Token Reuse

**Detection**:
- Same `idempotency_key` creating multiple bookings

**Fix**: Already handled by `payment_transactions.idempotency_key` UNIQUE constraint

### Potential Attack: RLS Bypass

**Detection**:
- User seeing other users' bookings/payments

**Response**:
1. IMMEDIATELY disable booking API access
2. Run RLS audit:
   ```sql
   SELECT * FROM pg_policies WHERE tablename IN ('bookings', 'payment_transactions');
   ```
3. Escalate to security team

---

## 9. Log Retention & Analytics

### View Edge Function Logs

```bash
supabase functions logs create-payhere-session --tail
```

### Archive Old Logs

```sql
-- Move logs older than 90 days to archive table
CREATE TABLE request_logs_archive AS 
SELECT * FROM request_logs 
WHERE created_at < NOW() - INTERVAL '90 day';

DELETE FROM request_logs 
WHERE created_at < NOW() - INTERVAL '90 day';
```

### Audit Trail

All admin actions should be logged:
```sql
SELECT * FROM admin_actions 
WHERE created_at > NOW() - INTERVAL '7 day'
ORDER BY created_at DESC;
```

---

## 10. Runbook: End-of-Day Report

```sql
-- Daily ops report (save as CSV)
WITH stats AS (
  SELECT 
    'Payments' as category,
    COUNT(*) as total,
    ROUND(100.0 * COUNT(CASE WHEN status='paid' THEN 1 END) / COUNT(*), 2) as success_rate_pct
  FROM payment_transactions
  WHERE created_at > NOW() - INTERVAL '1 day'
),
bookings_stats AS (
  SELECT
    'Bookings' as category,
    COUNT(*) as total,
    ROUND(100.0 * COUNT(CASE WHEN status='paid' THEN 1 END) / COUNT(*), 2) as success_rate_pct
  FROM bookings
  WHERE created_at > NOW() - INTERVAL '1 day'
),
errors_stats AS (
  SELECT
    'Errors (24h)' as category,
    COUNT(*) as total,
    NULL::numeric as success_rate_pct
  FROM request_logs
  WHERE level = 'error'
  AND created_at > NOW() - INTERVAL '1 day'
)
SELECT * FROM stats
UNION ALL SELECT * FROM bookings_stats
UNION ALL SELECT * FROM errors_stats;
```

Generate daily at 6 PM, share with team.

---

