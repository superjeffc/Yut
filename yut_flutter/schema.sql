CREATE TABLE IF NOT EXISTS users (
  username TEXT PRIMARY KEY,
  password_hash TEXT NOT NULL,
  coins INTEGER DEFAULT 0,
  unlocked_animals TEXT DEFAULT 'Seal Penguin',
  games INTEGER DEFAULT 0,
  wins INTEGER DEFAULT 0,
  losses INTEGER DEFAULT 0
);
