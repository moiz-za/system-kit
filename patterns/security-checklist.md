# Security Checklist — Reference Pattern

> Security is the foundation every other pattern sits on. This checklist
> applies to every project, every deployment, every code change — locally,
> in staging, and in production. No environment gets a security exemption.

---

## Universal requirements (every project, non-negotiable)

### Credentials & Secrets

| Check | How to verify |
|---|---|
| Keys/tokens/passwords ONLY in env vars, secret managers, or platform stores | Search tracked files for hardcoded values |
| Zero credentials in git history | `git log -p` scan + secret-scanning tool |
| API keys handled by scripts internally; never echoed or logged | Code review of all scripts that touch auth |
| Key rotation procedure exists and has been tested | Documented runbook + dry-run |
| Different keys for different environments (dev/staging/prod) | Config inspection |

### Access Control

| Check | How to verify |
|---|---|
| Every protected route requires authentication | Attempt access without session → expect redirect/401 |
| Authorization checked server-side (never client-side only) | Attempt privilege escalation via crafted requests |
| Tenant isolation: user A can never access user B's data | Cross-tenant access attempts blocked |
| Admin routes explicitly gated with role checks | Access attempts as regular user → denied |
| Default deny: undefined access is blocked | Test undefined route + undefined role combination |

### Input Handling

| Check | How to verify |
|---|---|
| All user input validated before use | Submit malformed data → rejected gracefully |
| SQL queries parameterized (no string concatenation) | Code review of all database interactions |
| XSS prevention: output encoded for context | Submit script tags in text fields → rendered inert |
| File uploads restricted (type, size, content validation) | Upload malicious file types → rejected |
| Error messages don't expose internals to users | Trigger errors → generic messages shown, details logged server-side only |

### Transport & Infrastructure

| Check | How to verify |
|---|---|
| TLS enforced (HTTP redirects to HTTPS) | HTTP request → 301 redirect |
| Security headers present (CSP, HSTS, X-Content-Type-Options, X-Frame-Options) | Response header inspection |
| Dependencies scanned for known vulnerabilities | Automated scanning tool output clean |
| Debug mode disabled in production | Error responses don't include stack traces |
| Backup procedure exists AND restore has been tested | Restore drill completed successfully |

## AI-specific security (for agent-powered projects)

| Check | Why it matters |
|---|---|
| Agent never reads raw credential files | Keys entering LLM context are sent to external servers |
| LLM outputs treated as untrusted input | Model could echo injected instructions or produce harmful code |
| Tool calling restricted to authorized operations | Prevents prompt injection from triggering unintended actions |
| Project data clearly labeled as untrusted context | Prevents injection through crafted file contents |
| Response validated against expected schema before execution | Prevents hallucinated APIs from being called |

## Incident response quick reference

When a security issue is discovered:

```
1. CONTAIN   → limit blast radius immediately
                (revoke keys, block access, disable affected features)
2. ASSESS    → what was exposed? for how long? who's affected?
3. FIX       → close the vulnerability
4. VERIFY    → confirm the fix works (test the specific attack vector)
5. DOCUMENT  → record what happened, timeline, and lessons learned
6. DISCLOSE  → notify affected parties if required by law or ethics
```

## Red flags that indicate immediate attention needed

- Credentials found in any tracked file
- Users reporting unauthorized access to others' data
- Unexplained outbound network calls from production
- Dependency vulnerabilities rated HIGH or CRITICAL
- Auth bypass discovered (even if seemingly hard to exploit)
