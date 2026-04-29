
**Summary**: System-level trust boundary policy between the public API surface and internal services, enforced via auth middleware and signed service tokens.
**Tags**: #architecture #auth #boundary
**Created**: 2026-04-29T00:00:00+00:00
**Last Updated**: 2026-04-29T00:00:00+00:00

---

## Content

### Trust boundary definition

Every request from the public API surface to internal services crosses the auth middleware **exactly once**. This is a system-level invariant, not a per-function contract.

### Key invariants

1. **Single authentication crossing**: Services never re-authenticate the same principal. Once a user is authenticated at the API boundary, their identity is propagated inward — internal services trust the token, not the raw credentials.

2. **Inter-service tokens**: Calls between internal services carry a **signed service token** rather than a user session. Service tokens are short-lived, scoped to the source and destination service, and signed with a shared secret or asymmetric key.

3. **No re-authentication inside the boundary**: An internal service that receives a request with a valid service token must not require the calling service to also present user credentials. Re-authentication inside the boundary breaks the single-crossing invariant and introduces unnecessary latency and coupling.

### Why this is ARCHITECTURE, not FUNCTIONS

This policy describes HOW services compose across the entire system — it is an enforced invariant about the topology of authentication, not the behavior of a single function or endpoint. Treating it as function documentation would obscure its system-wide scope.

### What this is NOT

- This is not the implementation of the auth middleware itself (see individual handler references).
- This is not a per-route authorization policy (which route allows which role).
- This is not a session management spec (session lifetime, refresh, revocation).

### Enforcement

The policy is enforced by convention and code review. The auth middleware is the canonical enforcement point at the API boundary. Inter-service token signing is the enforcement point inside the boundary.

## Related Notes

- [[System Architecture Overview]]
- [[Enforced Codebase Rules]]
