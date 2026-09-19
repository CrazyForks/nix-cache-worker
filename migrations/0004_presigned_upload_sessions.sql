-- Track authenticated direct-to-R2 NAR upload sessions and their staging keys.
CREATE TABLE IF NOT EXISTS upload_sessions (
  id TEXT PRIMARY KEY,
  r2_key TEXT NOT NULL,
  staging_key TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL CHECK (kind = 'nar'),
  expected_size INTEGER NOT NULL CHECK (expected_size >= 0),
  expected_sha256 TEXT NOT NULL CHECK (length(expected_sha256) = 64),
  status TEXT NOT NULL DEFAULT 'issued'
    CHECK (status IN ('issued', 'completed', 'failed', 'expired')),
  object_etag TEXT,
  error_code TEXT,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  completed_at TEXT,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_upload_sessions_expiry
  ON upload_sessions(status, expires_at);

CREATE INDEX IF NOT EXISTS idx_upload_sessions_key
  ON upload_sessions(r2_key, status, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_upload_sessions_active_key
  ON upload_sessions(r2_key)
  WHERE status = 'issued';
