"""
Backend Smoke Test — verifies all API endpoints are working correctly.
Run from: server/ directory using the venv python.
"""
import json
import random
import urllib.request
import urllib.error

BASE = 'http://127.0.0.1:8000/api'
TAG  = random.randint(1000, 9999)
EMAIL = 'smoketest{}@test.com'.format(TAG)
PASS  = 'testpass123'

PASS_MARK = 'PASS'
FAIL_MARK = 'FAIL'

results = []


def req(method, path, data=None, token=None):
    url = BASE + path
    body = json.dumps(data).encode() if data else b'{}'
    headers = {'Content-Type': 'application/json', 'Origin': 'http://127.0.0.1:5174'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    r = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def check(label, ok, detail=''):
    mark = PASS_MARK if ok else FAIL_MARK
    line = '[{}] {:<35} {}'.format(mark, label, detail)
    results.append((ok, line))
    print(line)


print('=' * 60)
print('  AI PRODUCTIVITY TRACKER — BACKEND SMOKE TEST')
print('=' * 60)

# ── 1. REGISTER ────────────────────────────────────────────────────
status, body = req('POST', '/auth/register', {'name': 'Babil Nagar', 'email': EMAIL, 'password': PASS})
check('Register new user', status == 201 and body.get('success'),
      'HTTP {} | user={}'.format(status, body.get('user', {}).get('name', '?')))
token = body.get('token', '')

# ── 2. LOGIN ───────────────────────────────────────────────────────
status, body = req('POST', '/auth/login', {'email': EMAIL, 'password': PASS})
check('Login with credentials', status == 200 and body.get('success'),
      'HTTP {} | token_len={}'.format(status, len(body.get('token', ''))))
token = body.get('token', token)

# ── 3. /ME ─────────────────────────────────────────────────────────
status, body = req('GET', '/auth/me', token=token)
name = body.get('data', {}).get('name', '?')
check('GET /auth/me (protected)', status == 200, 'HTTP {} | name={}'.format(status, name))

# ── 4. CREATE ROUTINE ──────────────────────────────────────────────
payload = {
    'date': '2026-05-20',
    'coreChecklists': {'study': True, 'exercise': True, 'ml': False},
    'coreMetrics':    {'studyHours': 4, 'mobileUsage': 2},
    'sleepTime': '23:00',
    'wakeTime':  '07:00',
    'notes':     'Smoke test log entry',
}
status, body = req('POST', '/routines', data=payload, token=token)
score = body.get('data', {}).get('productivityScore', '?')
routine_id = body.get('data', {}).get('id')
check('POST /routines (create)', status == 201 and body.get('success'),
      'HTTP {} | score={}%'.format(status, score))

# ── 5. LIST ROUTINES ───────────────────────────────────────────────
status, body = req('GET', '/routines', token=token)
check('GET /routines (list)', status == 200 and body.get('success'),
      'HTTP {} | count={}'.format(status, body.get('count', 0)))

# ── 6. UPDATE ROUTINE ──────────────────────────────────────────────
if routine_id:
    upd = dict(payload)
    upd['notes'] = 'Updated via smoke test'
    status, body = req('PUT', '/routines/{}'.format(routine_id), data=upd, token=token)
    check('PUT /routines/{id} (update)', status == 200 and body.get('success'),
          'HTTP {}'.format(status))

# ── 7. ANALYTICS ───────────────────────────────────────────────────
status, body = req('GET', '/analytics/full', token=token)
avg = body.get('stats', {}).get('avgScore', '?')
check('GET /analytics/full', status == 200 and body.get('success'),
      'HTTP {} | avgScore={}'.format(status, avg))

status, body = req('GET', '/analytics/weekly', token=token)
check('GET /analytics/weekly', status == 200 and body.get('success'),
      'HTTP {}'.format(status))

status, body = req('GET', '/analytics/insights', token=token)
check('GET /analytics/insights', status == 200 and body.get('success'),
      'HTTP {}'.format(status))

# ── 8. AI ENDPOINTS ────────────────────────────────────────────────
status, body = req('POST', '/ai/chat', data={'message': 'How to improve my study focus?'}, token=token)
reply_len = len(body.get('reply', ''))
check('POST /ai/chat', status == 200 and body.get('success'),
      'HTTP {} | reply_len={} chars'.format(status, reply_len))

status, body = req('POST', '/ai/generate-plan', data={}, token=token)
plan_len = len(body.get('plan', ''))
check('POST /ai/generate-plan', status == 200 and body.get('success'),
      'HTTP {} | plan_len={} chars'.format(status, plan_len))

status, body = req('POST', '/ai/analyze', data={}, token=token)
check('POST /ai/analyze', status == 200 and body.get('success'),
      'HTTP {}'.format(status))

# ── 9. CALENDAR STATUS ─────────────────────────────────────────────
status, body = req('GET', '/calendar/status', token=token)
check('GET /calendar/status', status == 200 and body.get('success'),
      'HTTP {} | connected={}'.format(status, body.get('connected')))

# ── 10. TOKEN REFRESH ──────────────────────────────────────────────
# First get a refresh token
status, body = req('POST', '/auth/login', {'email': EMAIL, 'password': PASS})
refresh_token = body.get('refresh', '')
if refresh_token:
    status, body = req('POST', '/auth/token/refresh', data={'refresh': refresh_token})
    check('POST /auth/token/refresh', status == 200 and bool(body.get('access')),
          'HTTP {}'.format(status))

# ── 11. DELETE ROUTINE ─────────────────────────────────────────────
if routine_id:
    status, body = req('DELETE', '/routines/{}'.format(routine_id), token=token)
    check('DELETE /routines/{id}', status == 200 and body.get('success'),
          'HTTP {}'.format(status))

# ── SUMMARY ────────────────────────────────────────────────────────
print()
print('=' * 60)
passed = sum(1 for ok, _ in results if ok)
failed = sum(1 for ok, _ in results if not ok)
print('  Results: {} passed, {} failed out of {} tests'.format(passed, failed, len(results)))
if failed == 0:
    print('  ✓ ALL CHECKS PASSED — Backend is fully operational!')
else:
    print('  ✗ Some checks failed — review the output above.')
print('=' * 60)
