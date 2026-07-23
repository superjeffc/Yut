CREATE TABLE IF NOT EXISTS users (
  google_id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  coins INTEGER DEFAULT 0,
  unlocked_animals TEXT DEFAULT 'Seal Penguin',
  games INTEGER DEFAULT 0,
  wins INTEGER DEFAULT 0,
  losses INTEGER DEFAULT 0
);
