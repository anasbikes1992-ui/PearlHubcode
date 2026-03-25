import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    browse_marketplace: {
      executor: 'ramping-vus',
      startVUs: 5,
      stages: [
        { duration: '30s', target: 25 },
        { duration: '1m', target: 50 },
        { duration: '30s', target: 0 },
      ],
      gracefulRampDown: '10s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<800'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'https://pearlhub.lk';

export default function () {
  const res1 = http.get(`${BASE_URL}/`);
  check(res1, {
    'home is 200': (r) => r.status === 200,
  });

  const res2 = http.get(`${BASE_URL}/search`);
  check(res2, {
    'search is 200': (r) => r.status === 200,
  });

  const res3 = http.get(`${BASE_URL}/api/health`);
  check(res3, {
    'health endpoint acceptable': (r) => r.status === 200 || r.status === 404,
  });

  sleep(1);
}
