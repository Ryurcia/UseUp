ALTER TABLE ingredients ADD COLUMN IF NOT EXISTS notif_read_at timestamptz;
ALTER TABLE ingredients ADD COLUMN IF NOT EXISTS dismissed boolean NOT NULL DEFAULT false;
