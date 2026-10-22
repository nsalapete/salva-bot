-- Every incoming Telegram message (leads + orders)
CREATE TABLE requests (
  id           SERIAL PRIMARY KEY,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  chat_id      BIGINT      NOT NULL,
  client_name  TEXT,
  message      TEXT        NOT NULL,
  intent       TEXT        NOT NULL,
  product      TEXT,
  quantity     NUMERIC,
  unit         TEXT,
  language     TEXT,
  status       TEXT        NOT NULL DEFAULT 'received'
);

-- Product catalog + stock, used by the inventory API in Step 7
-- (sample values: replace with Salva Import's real catalog and prices)
CREATE TABLE products (
  sku              TEXT PRIMARY KEY,
  name             TEXT    NOT NULL,
  category         TEXT    NOT NULL,
  bottle_ml        INTEGER NOT NULL,
  bottles_per_case INTEGER NOT NULL,
  price_per_case   NUMERIC(10,2) NOT NULL,
  stock_bottles    INTEGER NOT NULL DEFAULT 0
);

INSERT INTO products VALUES
  ('AGU-CUM-700', 'Cumbé Premium Aguardiente',  'aguardiente', 700,  6, 135,  210),
  ('AGU-CUM-1000', 'Cumbé Premium Aguardiente',  'aguardiente', 1000,  6, 153,  510);
