CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(100) NOT NULL,
  status VARCHAR(20),
  legacy_notes TEXT
);

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  total NUMERIC(10,2)
);

CREATE INDEX idx_orders_user_id ON orders (user_id);
