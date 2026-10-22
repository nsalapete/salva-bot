-- Step 13: atomic stock reservation
ALTER TABLE requests
  ADD COLUMN reserved_sku TEXT,
  ADD COLUMN reserved_bottles INTEGER;

-- Reserve bottles for a request, atomically and only once per request.
-- Called by the workflow through the inventory API: POST /rpc/reserve_stock
CREATE OR REPLACE FUNCTION reserve_stock(p_request_id integer, p_sku text, p_bottles integer)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  already   integer;
  remaining integer;
BEGIN
  -- Lock the request row: a retried call must not reserve twice
  SELECT reserved_bottles INTO already FROM requests WHERE id = p_request_id FOR UPDATE;
  IF already IS NOT NULL THEN
    SELECT stock_bottles INTO remaining FROM products WHERE sku = p_sku;
    RETURN json_build_object('reserved', true, 'stock_bottles', remaining, 'already_reserved', true);
  END IF;

  -- Take the bottles only if there are enough (the row lock prevents overselling)
  UPDATE products
     SET stock_bottles = stock_bottles - p_bottles
   WHERE sku = p_sku AND p_bottles > 0 AND stock_bottles >= p_bottles
  RETURNING stock_bottles INTO remaining;

  IF NOT FOUND THEN
    SELECT stock_bottles INTO remaining FROM products WHERE sku = p_sku;
    RETURN json_build_object('reserved', false, 'stock_bottles', remaining);
  END IF;

  UPDATE requests SET reserved_sku = p_sku, reserved_bottles = p_bottles WHERE id = p_request_id;
  RETURN json_build_object('reserved', true, 'stock_bottles', remaining);
END;
$$;

REVOKE EXECUTE ON FUNCTION reserve_stock(integer, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION reserve_stock(integer, text, integer) TO web_anon;

-- Give the bottles back when the sales team cancels an order (run by hand, not exposed to the API)
CREATE OR REPLACE FUNCTION cancel_order(p_request_id integer)
RETURNS text
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  r requests%ROWTYPE;
BEGIN
  SELECT * INTO r FROM requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR r.reserved_bottles IS NULL OR r.status = 'cancelled' THEN
    RETURN 'nothing to release';
  END IF;
  UPDATE products SET stock_bottles = stock_bottles + r.reserved_bottles WHERE sku = r.reserved_sku;
  UPDATE requests SET status = 'cancelled' WHERE id = p_request_id;
  RETURN format('released %s bottles of %s', r.reserved_bottles, r.reserved_sku);
END;
$$;

REVOKE EXECUTE ON FUNCTION cancel_order(integer) FROM PUBLIC;

-- Tell the inventory API to pick up the new function
NOTIFY pgrst, 'reload schema';
