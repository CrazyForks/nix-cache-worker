-- Count-based hard capacity for each retention policy group.
ALTER TABLE gc_policies
  ADD COLUMN capacity_versions INTEGER
  CHECK (capacity_versions IS NULL OR (capacity_versions >= 0 AND capacity_versions <= 100000));

-- Persist all capacity-bearing policy matches so GC can rank a complete
-- policy/group snapshot across bounded Worker invocations.
CREATE TABLE IF NOT EXISTS gc_policy_capacity_matches (
  job_id TEXT NOT NULL,
  version_id TEXT NOT NULL,
  policy_id INTEGER NOT NULL,
  group_key TEXT NOT NULL,
  registered_at TEXT NOT NULL,
  capacity_versions INTEGER NOT NULL CHECK (capacity_versions >= 0 AND capacity_versions <= 100000),
  PRIMARY KEY (job_id, version_id, policy_id)
);

CREATE INDEX IF NOT EXISTS idx_gc_policy_capacity_matches_job_group
  ON gc_policy_capacity_matches(job_id, policy_id, group_key, registered_at DESC);
