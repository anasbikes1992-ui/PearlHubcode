// Phase 5 monitoring bootstrap for Sentry and PostHog

import * as Sentry from '@sentry/browser';
import posthog from 'posthog-js';

export interface MonitoringConfig {
  sentryDsn?: string;
  posthogKey?: string;
  posthogHost?: string;
  environment?: string;
  release?: string;
}

let monitoringInitialized = false;

export function initMonitoring(config?: MonitoringConfig) {
  if (monitoringInitialized) return;

  const resolvedConfig: MonitoringConfig = {
    sentryDsn: config?.sentryDsn ?? import.meta.env.VITE_SENTRY_DSN,
    posthogKey: config?.posthogKey ?? import.meta.env.VITE_POSTHOG_KEY,
    posthogHost: config?.posthogHost ?? import.meta.env.VITE_POSTHOG_HOST,
    environment: config?.environment ?? import.meta.env.MODE ?? 'production',
    release: config?.release ?? import.meta.env.VITE_APP_RELEASE,
  };

  if (resolvedConfig.sentryDsn) {
    Sentry.init({
      dsn: resolvedConfig.sentryDsn,
      environment: resolvedConfig.environment || 'production',
      release: resolvedConfig.release,
      tracesSampleRate: 0.2,
      replaysSessionSampleRate: 0.05,
      replaysOnErrorSampleRate: 1.0,
    });
  }

  if (resolvedConfig.posthogKey) {
    posthog.init(resolvedConfig.posthogKey, {
      api_host: resolvedConfig.posthogHost || 'https://app.posthog.com',
      person_profiles: 'identified_only',
      capture_pageview: true,
      capture_pageleave: true,
    });
  }

  monitoringInitialized = true;
}

export function captureError(error: unknown, context?: Record<string, unknown>) {
  if (error instanceof Error) {
    Sentry.captureException(error, { extra: context });
  } else {
    Sentry.captureMessage('Non-error exception captured', {
      level: 'error',
      extra: { value: error, ...context },
    });
  }
}

export function trackEvent(event: string, properties?: Record<string, unknown>) {
  posthog.capture(event, properties);
}

export function identifyUser(userId: string, traits?: Record<string, unknown>) {
  posthog.identify(userId, traits);
  Sentry.setUser({ id: userId });
}
