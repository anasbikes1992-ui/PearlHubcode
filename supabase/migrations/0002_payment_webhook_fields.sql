-- Add webhook verification fields to payment_transactions table
-- These fields are critical for proper PayHere webhook handling

ALTER TABLE public.payment_transactions 
ADD COLUMN IF NOT EXISTS payhere_order_id TEXT UNIQUE;

ALTER TABLE public.payment_transactions 
ADD COLUMN IF NOT EXISTS webhook_received BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.payment_transactions 
ADD COLUMN IF NOT EXISTS webhook_received_at TIMESTAMPTZ;

ALTER TABLE public.payment_transactions 
ADD COLUMN IF NOT EXISTS webhook_signature_valid BOOLEAN;

ALTER TABLE public.payment_transactions 
ADD COLUMN IF NOT EXISTS md5_signature VARCHAR(32);

ALTER TABLE public.payment_transactions 
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- Create index for fast payhere_order_id lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_transactions_payhere_order_id 
  ON public.payment_transactions (payhere_order_id)
  WHERE payhere_order_id IS NOT NULL;

-- Create index for webhook received tracking
CREATE INDEX IF NOT EXISTS idx_payment_transactions_webhook_received 
  ON public.payment_transactions (webhook_received, created_at DESC);

-- Update any existing payment_transactions that have payment_ref to populate payhere_order_id
UPDATE public.payment_transactions 
SET payhere_order_id = payment_ref 
WHERE payhere_order_id IS NULL AND payment_ref IS NOT NULL AND gateway = 'payhere';

-- Add comment to document the field purposes
COMMENT ON COLUMN public.payment_transactions.payhere_order_id IS 'External PayHere order ID for webhook lookups';
COMMENT ON COLUMN public.payment_transactions.webhook_received IS 'Flag to prevent duplicate webhook processing (idempotency)';
COMMENT ON COLUMN public.payment_transactions.webhook_received_at IS 'Timestamp when webhook was received';
COMMENT ON COLUMN public.payment_transactions.webhook_signature_valid IS 'Whether MD5 signature verification passed';
COMMENT ON COLUMN public.payment_transactions.md5_signature IS 'The MD5 signature received from webhook';
COMMENT ON COLUMN public.payment_transactions.completed_at IS 'When the payment was completed (for successful payments)';
