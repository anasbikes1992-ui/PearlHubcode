ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability_slots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own bookings" ON public.bookings;
CREATE POLICY "Users can read own bookings"
  ON public.bookings FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = provider_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage bookings" ON public.bookings;
CREATE POLICY "Admins can manage bookings"
  ON public.bookings FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Users can read own wallet transactions" ON public.wallet_transactions;
CREATE POLICY "Users can read own wallet transactions"
  ON public.wallet_transactions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage wallet transactions" ON public.wallet_transactions;
CREATE POLICY "Admins can manage wallet transactions"
  ON public.wallet_transactions FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Users can read own payment transactions" ON public.payment_transactions;
CREATE POLICY "Users can read own payment transactions"
  ON public.payment_transactions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage payment transactions" ON public.payment_transactions;
CREATE POLICY "Admins can manage payment transactions"
  ON public.payment_transactions FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
CREATE POLICY "Users can read own notifications"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage notifications" ON public.notifications;
CREATE POLICY "Admins can manage notifications"
  ON public.notifications FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Users can raise disputes for own bookings" ON public.disputes;
CREATE POLICY "Users can raise disputes for own bookings"
  ON public.disputes FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = raised_by AND EXISTS (
      SELECT 1
      FROM public.bookings b
      WHERE b.id = booking_id
        AND (b.user_id = auth.uid() OR b.provider_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can read relevant disputes" ON public.disputes;
CREATE POLICY "Users can read relevant disputes"
  ON public.disputes FOR SELECT
  TO authenticated
  USING (
    auth.uid() = raised_by
    OR public.is_admin(auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.bookings b
      WHERE b.id = booking_id
        AND (b.user_id = auth.uid() OR b.provider_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Admins can manage disputes" ON public.disputes;
CREATE POLICY "Admins can manage disputes"
  ON public.disputes FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Users can upload own KYC documents" ON public.kyc_documents;
CREATE POLICY "Users can upload own KYC documents"
  ON public.kyc_documents FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can read own KYC documents" ON public.kyc_documents;
CREATE POLICY "Users can read own KYC documents"
  ON public.kyc_documents FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage KYC documents" ON public.kyc_documents;
CREATE POLICY "Admins can manage KYC documents"
  ON public.kyc_documents FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Providers can read own payouts" ON public.payouts;
CREATE POLICY "Providers can read own payouts"
  ON public.payouts FOR SELECT
  TO authenticated
  USING (auth.uid() = provider_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage payouts" ON public.payouts;
CREATE POLICY "Admins can manage payouts"
  ON public.payouts FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Public can read public platform config" ON public.platform_config;
CREATE POLICY "Public can read public platform config"
  ON public.platform_config FOR SELECT
  TO anon, authenticated
  USING (is_public = true OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage platform config" ON public.platform_config;
CREATE POLICY "Admins can manage platform config"
  ON public.platform_config FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Users can manage own favorites" ON public.favorites;
CREATE POLICY "Users can manage own favorites"
  ON public.favorites FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can read own messages" ON public.messages;
CREATE POLICY "Users can read own messages"
  ON public.messages FOR SELECT
  TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Users can send messages they author" ON public.messages;
CREATE POLICY "Users can send messages they author"
  ON public.messages FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS "Recipients can mark messages read" ON public.messages;
CREATE POLICY "Recipients can mark messages read"
  ON public.messages FOR UPDATE
  TO authenticated
  USING (auth.uid() = recipient_id OR public.is_admin(auth.uid()))
  WITH CHECK (auth.uid() = recipient_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Authenticated users can read availability" ON public.availability_slots;
CREATE POLICY "Authenticated users can read availability"
  ON public.availability_slots FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Providers can manage own availability" ON public.availability_slots;
CREATE POLICY "Providers can manage own availability"
  ON public.availability_slots FOR ALL
  TO authenticated
  USING (auth.uid() = provider_id OR public.is_admin(auth.uid()))
  WITH CHECK (auth.uid() = provider_id OR public.is_admin(auth.uid()));

DO $$
BEGIN
  IF to_regclass('public.reviews') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Verified reviews only after completed booking" ON public.reviews';
    EXECUTE $policy$
      CREATE POLICY "Verified reviews only after completed booking"
      ON public.reviews FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid() = user_id AND EXISTS (
          SELECT 1
          FROM public.bookings b
          WHERE b.id = booking_id
            AND b.user_id = auth.uid()
            AND b.status = ''completed''
        )
      )
    $policy$;
  END IF;
END;
$$;
