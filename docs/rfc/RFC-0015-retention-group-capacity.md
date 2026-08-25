# RFC-0015: retention group capacity

- Status: Implemented
- Date: 2026-08-25

## Context

Retention rules currently protect a configurable number of newest versions and
may apply a finite age-based duration, but they cannot limit how many active
versions a computed group tolerates. Operators need a count-based hard upper
bound for groups whose version volume must remain small even when versions are
newer than their normal time-based retention period.

## Goals and non-goals

- Add an optional `capacityVersions` action to retention rules.
- Evaluate the capacity independently for every group produced by a rule's
  `groupBy` fields.
- Allow capacity-only rules and preserve the existing `lastN` and
  `durationDays` actions when they are also configured.
- Keep `null` as unlimited capacity and treat `0` as no tolerated unprotected
  versions.
- Keep pin and keep-latest protection fail-safe, even when protected versions
  cause a group to exceed its configured capacity.
- Preserve bounded, resumable GC execution and existing Nix HTTP behavior.

This change does not introduce byte-based accounting, shared-NAR size
deduplication, or any change to HTTP cache TTL calculation.

## Design

The public policy shape gains:

```json
{
  "name": "stable-builds",
  "conditions": [],
  "groupBy": ["pkg_name", "pkg_tag:channel"],
  "lastN": 3,
  "durationDays": 30,
  "capacityVersions": 20
}
```

`capacityVersions` is a non-negative integer no greater than 100,000, or
`null` when unlimited. A rule may configure capacity without `lastN` or
`durationDays`. Capacity is an additional hard upper bound: versions ranked
older than the configured capacity in any matching policy/group may become
automatic-GC candidates without waiting for `durationDays`. The existing
default retention still applies to versions that are not otherwise eligible.

Ranking is newest first by `registered_at DESC, version_id DESC`. Every active
version matching a capacity-bearing policy counts toward that policy/group,
including pinned and keep-latest-protected versions. Candidates are skipped if
they are pinned or protected by keep-latest from any matching policy. Thus a
group can remain above capacity when its protected versions alone exceed the
limit. Overlapping capacity rules are enforced independently; a version is a
capacity candidate if it is beyond the limit of any matching policy/group.

GC persists capacity matches in a job-scoped table during the protect phase.
The evaluate phase uses a window rank over the persisted snapshot to identify
capacity-overage versions on each bounded page. The policy snapshot already
stored in the GC job remains authoritative for the complete run.

## Invariants and security

- Capacity never overrides explicit pin or keep-latest protection.
- Capacity decisions use active-version metadata and do not replace R2 as the
  source of object bytes.
- Capacity actions do not change cache headers or public Nix responses.
- Capacity values are validated as bounded integers and are never interpreted
  as bearer credentials or executable input.
- Capacity match rows and GC jobs are cleaned independently and can be retried
  after Worker interruption.

## Compatibility and migration

The `gc_policies` table gains a nullable `capacity_versions` column. A new
job-scoped capacity-match table stores the policy, group, version, registration
order, and capacity snapshot needed for resumable evaluation. Existing policy
rows remain unlimited and existing jobs remain valid. No Nix HTTP or object
schema change is required.

The admin API adds `capacityVersions` to policy GET/POST/PUT payloads while
retaining all existing fields. The admin console exposes the new action and
describes its early-cleanup behavior.

## Acceptance tests

- Capacity-only, combined, unlimited, zero, and invalid policy payloads.
- Independent capacity enforcement for multiple groups and stable tie-breaking.
- Capacity-triggered deletion before age expiry.
- Capacity not changing normal duration-based deletion when the group is under
  its limit.
- Overlapping capacity rules and unioned keep-latest protection.
- Pinned versions remaining untouched even when over capacity.
- Capacity ranking and cleanup across multiple GC pages and resumed jobs.
- Existing cache TTL, Nix HTTP, and shared-NAR deletion protections remaining
  unchanged.

## Implementation notes

Implemented on the `codex/retention-group-capacity` branch with the nullable
policy column, resumable capacity-match table, bounded D1 query chunks, admin
API/UI support, documentation, and GC regression coverage. No implementation
deviations from this RFC were required.
