# Cost-Zero Operation — Reference Pattern

> How to run AI-agent development at $0/month using free-tier rotation,
> careful resource management, and strategic provider selection.
> Proven across a full production development cycle.

---

## The principle

AI-agent development has three cost centers: AI model usage, hosting/infrastructure,
and developer tools. All three can operate at zero cost with the right structure —
but only if usage is actively managed, not assumed.

## Provider rotation strategy

> Offerings below were accurate as of 2026-08. Free catalogs rotate constantly —
> verify current limits before relying on any specific number here.

| Provider | Free offering | Best for | Watch out for |
|---|---|---|---|
| OpenCode Zen | ~8-27 free models (rotating) | General coding, reasoning | Catalog rotates weekly; some models flake |
| OpenRouter `:free` | 17+ free models, 1M ctx options | Specific models unavailable elsewhere | Daily request limits (~50-1000 depending on tier) |
| Google AI Studio | Gemini Flash free tier | Fast tasks, large context | Region restrictions may apply |
| Groq | Free tier, very fast | Speed-critical tasks | Limited model selection |
| DeepSeek | Near-zero cost official API | Reasoning-heavy tasks | Paid (but extremely cheap) |
| GitHub Actions | 2,000 min/mo (free tier) | CI/CD, automated testing | Private repos consume at 1x rate |
| Cloudflare Workers | 100k req/day free | Edge functions, API proxies | CPU time limited (10ms free tier) |

## Rotation rules

1. **Free before paid. Always.** Only use paid when no free option can do the job
2. **Track consumption internally** — never display quota counters to users
3. **Auto-fallback when exhausted** — switch to next provider without user intervention
4. **Re-evaluate monthly** — free catalogs rotate; today's dead model may return

## What this enabled in practice

- Full production dashboard built and operated: $0/month infrastructure
- 26+ concurrent agent sessions: $0 AI costs (free-tier rotation)
- Multiple providers tested and benchmarked: $0 (health probes use minimal tokens)
- CI/CD pipeline with security scanning: $0 (GitHub free tier)
- Total development cost excluding human time: **$0/month**

## When paid becomes necessary

| Trigger | Action |
|---|---|
| Free-tier daily limits consistently hit | Upgrade specific provider OR add paid backup |
| Task requires capabilities no free model offers | Use cheapest capable paid model for that task only |
| Production traffic exceeds free-tier infrastructure | Upgrade hosting only for affected components |
| Compliance requires enterprise SLA | Negotiate directly; document the requirement |

The key principle: upgrade deliberately, not by default. Every dollar spent should
trace to a specific capability gap that free tiers cannot fill.

## Hidden costs to watch for

| Cost | Source | Mitigation |
|---|---|---|
| Developer time debugging free-tier quirks | Flaky models, rotating catalogs | Time-box debugging; document known issues |
| Data egress from cloud platforms | Hosting platforms charge for bandwidth | Cache aggressively; minimize external calls |
| Token consumption from verbose prompts | Large context windows consume tokens fast | Compact prompts; use structured output formats |
| CI minutes consumed by repeated testing | Every push triggers test suite | Batch pushes; optimize test parallelism |
