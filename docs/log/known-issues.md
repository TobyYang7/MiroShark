# Known Issues Log

Running record of upstream / infrastructure problems hit during simulation
runs. Update an entry when status changes; add a new entry for a new symptom.

---

## 1. Alva sandbox: proxy connection reset to api.openai.com

- **Status**: intermittent / not reproducing as of 2026-04-23 06:15 UTC
  (direct wrapper probe returned 200 with `content: "pong"`). Keep
  monitoring; symptom can return without notice.
- **First observed**: 2026-04-23 (earlier in the day, prior session).
- **Last reproduced**: prior session, 2026-04-23.
- **Last verified working**: 2026-04-23 06:15 UTC.
- **Affects**: every simulation run that routes LLM calls through the
  Alva-hosted openai-api wrapper (`alva-wrapper` PM2 service →
  `openai-api/server.js` → `adk.agent()` inside the V8 sandbox).

### Symptom

The Alva V8 sandbox initiates an outbound HTTPS request to
`api.openai.com` via the platform's egress proxy `10.1.6.3:3128`. The proxy
resets the TCP connection mid-handshake:

```
Alva sandbox → tries to reach api.openai.com
            → through proxy 10.1.6.3:3128
            → connection reset by peer
```

The MiroShark backend itself is healthy — services start, requests reach the
wrapper, the wrapper forwards into the sandbox, the sandbox accepts the
job. The failure is strictly between the Alva sandbox egress proxy and
OpenAI.

### Impact

- Every `chat/completions` call routed through the wrapper fails fast with
  HTTP 502 (`bad_gateway`) carrying the proxy-reset message.
- Simulation rounds requiring LLM calls cannot complete; agents idle until
  retries exhaust.
- Knock-on effect: even read-only Alva SDK calls remain fine, because they
  do not exit the platform — only the OpenAI egress path is broken.

### Workarounds (in priority order)

1. **Wait** for Alva to restore the egress proxy. No client-side fix
   resolves the reset.
2. **Bypass the wrapper** by pointing MiroShark's LLM client straight at
   another provider (OpenRouter or OpenAI direct), using the user's own
   API key from `MiroShark/.env`. This sidesteps the Alva sandbox entirely
   and is the recommended fallback for time-sensitive runs.
3. **Lower concurrency** so a partial recovery isn't immediately
   re-saturated. As of this entry, `semaphore` in
   `backend/scripts/run_parallel_simulation.py`,
   `run_twitter_simulation.py`, and `run_reddit_simulation.py` is pinned
   to **5** for exactly this reason. Restore to 60/30 once the proxy is
   stable.

### Verification when fixed

1. From the MiroShark host:
   ```bash
   curl --noproxy 127.0.0.1 -X POST http://127.0.0.1:8787/v1/chat/completions \
     -H 'content-type: application/json' \
     -d '{"model":"alva-adk","messages":[{"role":"user","content":"ping"}],"max_turns":1}'
   ```
   Expect HTTP 200 with a non-empty `choices[0].message.content`. A 502
   with `connection reset by peer` means the proxy is still down.
2. Once two consecutive runs return 200, restore `semaphore` values and
   note the recovery date in this file.

---

## 2. alva-wrapper rejects MiroShark's OpenAI-standard tool schema

- **Status**: **resolved** 2026-04-23 via bridge mode in
  `openai-api/translator.js` + `server.js`. Wrapper now accepts both
  the native flat shape and the OpenAI nested shape; when no `fn` is
  provided it switches to prompt-driven JSON tool calling and parses
  the response with `jsonrepair`. Verified: `test_polymarket.py`
  produced 6 real agent actions (BUY_SHARES across three agents) with
  zero tool-format errors. Run log:
  `docs/log/sim-run-2026-04-23-bridge.log`.
- **First observed**: 2026-04-23 during `test_polymarket.py` smoke run.
- **Affects**: any MiroShark/camel-driven simulation that points
  `LLM_BASE_URL` at the local `alva-wrapper` (port 8787).

### Symptom

Every chat-completions request that includes tools fails with HTTP 400 from
the wrapper, e.g.:

```
openai.BadRequestError: Error code: 400 - {'error': {'message':
'tools[0]: field "name" must be a string', 'type': 'invalid_request_error',
'param': 'tools'}}
```

In `_test_polymarket` the failure repeats 6 times and the simulation
finishes in 0.8s with only the 2 seeded markets — no agent actions. See
`docs/log/sim-run-2026-04-23.log`.

### Root cause

The two sides disagree on the shape of `tools[]`:

| Layer | Expected `tools[i]` shape |
| --- | --- |
| MiroShark / camel / openai-python | `{"type":"function","function":{"name":"X","parameters":...}}` |
| alva-wrapper (`openai-api/translator.js`) | `{"name":"X","description":"...","parameters":...,"fn":"<JS source>"}` |

The wrapper is intentionally non-standard — it embeds the tool
implementation as a JavaScript source string (`fn`) so the ADK agent loop
can run server-side without a client-side tool round-trip. There is no
auto-translation from the OpenAI nested form, and there is nowhere for
camel to inject an `fn` body.

### Workarounds

1. **Bypass the wrapper for MiroShark runs.** Point
   `LLM_BASE_URL` directly at OpenAI / OpenRouter (or any
   OpenAI-compatible endpoint that accepts the standard tool schema) and
   keep the wrapper for Alva-native ADK agent calls only. This is the
   recommended path until the wrapper grows a translation layer.
2. **Add a translation layer in the wrapper** that accepts the standard
   `{"type":"function","function":{...}}` shape, drops the `fn`
   requirement when no implementation is provided, and short-circuits the
   ADK loop into a single-turn pass-through. (Not done.)

### Implication for issue #1

Until issue #2 is fixed, MiroShark traffic never reaches the Alva
sandbox, so the proxy-reset symptom (issue #1) cannot be reproduced from
MiroShark. To reproduce issue #1, exercise the wrapper directly with a
correctly-shaped request (curl example in section 1 — verification).
