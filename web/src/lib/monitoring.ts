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

export function initMonitoring(config: MonitoringConfig) {
  if (monitoringInitialized) return;

  if (config.sentryDsn) {
    Sentry.init({
      dsn: config.sentryDsn,
      environment: config.environment || 'production',
      release: config.release,
      tracesSampleRate: 0.2,
      replaysSessionSampleRate: 0.05,
      replaysOnErrorSampleRate: 1.0,
    });
  }

  if (config.posthogKey) {
    posthog.init(config.posthogKey, {
      api_host: config.posthogHost || 'https://app.posthog.com',
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
