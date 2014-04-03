-- utility_deals_code.sql
-- $Id: utility_deals_code.sql,v 1.5 2008/04/30 17:16:59 lynn Exp $
-- part of domain-independent support structures
-- Lynn Dobbs and Greg Davidson

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- Concept: Money

CREATE OR REPLACE
FUNCTION pennies_text(us_pennies) RETURNS text AS $$
  SELECT ( ($1/100)::text || '.'  || trim(from to_char($1%100,'00')) )::money::text
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION pennies_text(us_pennies) IS
'money type deprecated. !!';

CREATE OR REPLACE
FUNCTION pennies_percent(us_pennies) RETURNS numeric AS $$
  SELECT ($1::numeric/100)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION pennies_percent(us_pennies) IS
'retrieves a percentage which was encoded as us_pennies';

-- returns a percentage of us_pennies correctly rounded.
CREATE OR REPLACE
FUNCTION pennies_percent_of(us_pennies, numeric) RETURNS us_pennies AS $$
  SELECT round( ($1 * $2) / 100 )::us_pennies
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION pennies_percent_of(us_pennies, numeric) IS
'interprets the 2nd argument as a percentage to compute of the first amount';

-- returns a us_pennies after percent discount is applied
CREATE OR REPLACE
FUNCTION pennies_percent_off(us_pennies, numeric) RETURNS us_pennies AS $$
  SELECT ($1 - pennies_percent_of($1,$2))::us_pennies
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION pennies_percent_off(us_pennies, numeric) IS
'returns $1 after a percentage has been subtracted';

CREATE OR REPLACE
FUNCTION percent_pennies(numeric) RETURNS us_pennies AS $$
  SELECT $1::us_pennies
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION percent_pennies(numeric) IS
'supports the kludge of storing a percent as a us_pennies amount';

-- Concept: Line Items

CREATE OR REPLACE
FUNCTION line_item_text(line_item_ids) RETURNS text AS $$
  SELECT name FROM line_items WHERE id = $1
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION line_item(text) RETURNS line_item_ids AS $$
DECLARE
  the_item maybe_line_item_ids;
BEGIN
  SELECT INTO the_item id FROM line_items WHERE name = $1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'line_item(%): No such item!', $1;
  END IF;
  RETURN the_item::line_item_ids;
END
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION make_line_item(line_item_kinds, text) RETURNS maybe_line_item_ids AS $$
DECLARE
  the_id maybe_line_item_ids;
BEGIN
  BEGIN
    INSERT INTO line_items(kind, name) VALUES ($1, $2)
    RETURNING id INTO the_id;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE NOTICE 'make_line_item(%): already exists', $2;
      SELECT INTO the_id id FROM line_items WHERE name = $2;
  END;
  RETURN the_id;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION make_chargeable_item(text) RETURNS maybe_line_item_ids AS $$
  SELECT make_line_item('item_kind_chargeable', $1)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_creditable_item(text) RETURNS maybe_line_item_ids AS $$
  SELECT make_line_item('item_kind_creditable', $1)
$$ LANGUAGE sql STRICT;

-- concept Deal Packages

CREATE OR REPLACE
FUNCTION make_deal_package(
  name_ text,
  base_ deal_package_ids,
  duration_ time_ranges
) RETURNS maybe_deal_package_ids AS $$
DECLARE
  the_id maybe_deal_package_ids;
BEGIN
  BEGIN
  -- prohibit overlaping an existing package of the same name !!!
  -- any other potential integrity violations ???
    INSERT INTO deal_packages(name, base, starting, ending)
    VALUES ( $1, $2, time_range_start($3), time_range_end($3) )
    RETURNING id INTO the_id;
  EXCEPTION
    WHEN unique_violation THEN  -- the unique constraint in the table is gone!!!
      RAISE NOTICE 'make_deal_package(%): already exists', $2;
      SELECT INTO the_id id FROM deal_packages WHERE name = $2;
  END;
  RETURN the_id;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION deal_package(text, event_times) RETURNS deal_package_ids AS $$
DECLARE
  the_id maybe_deal_package_ids;
BEGIN
  SELECT INTO the_id id FROM deal_packages
  WHERE name = $1 AND is_current(starting, ending, $2);
  IF NOT FOUND THEN
    RAISE EXCEPTION 'deal_package(%, %): No such deal package!', $1, $2;
  END IF;
  RETURN the_id::deal_package_ids;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION deal_package(text) RETURNS deal_package_ids AS $$
  SELECT deal_package($1, event_time())
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION deal_package_text(deal_package_ids) RETURNS text AS $$
  SELECT name FROM deal_packages WHERE id = $1
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION expire_deal_package(deal_package_ids, event_times) RETURNS event_times AS $$
  UPDATE deal_packages SET ending = $2 WHERE id = $1 AND ending = 'infinity';
  SELECT ending FROM deal_packages WHERE id = $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION extend_deal_package(deal_package_ids, event_times) RETURNS event_times AS $$
  UPDATE deal_packages SET ending = $2 WHERE id = $1 AND $2 > ending;
  SELECT ending FROM deal_packages WHERE id = $1
$$ LANGUAGE sql;

-- concept Deals

CREATE OR REPLACE
FUNCTION make_deal(
  item_ line_item_ids,
  kind_ deal_kinds,
  pkg_ deal_package_ids,
  amt_ us_pennies,
  when_ time_ranges
) RETURNS maybe_deal_ids AS $$
DECLARE
  the_id maybe_deal_ids;
BEGIN
  -- prohibit overlaping an existing deal for the same item in the same package  !!!
  -- prohibit creating a deal for an item which is not chargeable !!!
  -- any other potential integrity violations ???
  BEGIN
	INSERT INTO price_deals (item_id, kind, package_id, amount, starting, ending)
	VALUES (
	  $1, $2, $3, $4, time_range_start($5), time_range_end($5)
	) RETURNING id INTO the_id;
  EXCEPTION			-- this won't happen any more!!!
    WHEN unique_violation THEN
      RAISE NOTICE 'price_deal(%, %, %, %, %): already exists', $1, $2, $3, $4, $5;
  END;
  RETURN the_id;
END
$$ LANGUAGE plpgsql STRICT;
COMMENT ON FUNCTION make_deal(line_item_ids, deal_kinds, deal_package_ids, us_pennies, time_ranges)
IS 'Create (or select???) a deal with unique characteristics and return the deal id';

CREATE OR REPLACE
FUNCTION make_deal( text,  deal_kinds, text, us_pennies,  time_ranges ) RETURNS maybe_deal_ids AS $$
  SELECT make_deal( line_item($1), $2, deal_package($3, time_range_start($5)), $4, $5 )
$$ LANGUAGE sql STRICT;


CREATE OR REPLACE		-- dummy for recursion
FUNCTION find_deal(line_item_ids, deal_package_ids, event_times) RETURNS maybe_deal_ids AS $$
  SELECT NULL::maybe_deal_ids
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_deal_(line_item_ids, deal_package_ids, event_times)
RETURNS deal_ids AS $$
  SELECT deal.id
  FROM line_items item, deal_packages pkg, price_deals deal
  WHERE item.id = $1 AND pkg.id = $2 AND deal.item_id = $1 AND deal.package_id = $2
    AND is_current(deal.starting, deal.ending, $3);
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_deal(line_item_ids, deal_package_ids, event_times)
RETURNS maybe_deal_ids AS $$
  SELECT COALESCE(
    find_deal_($1, $2, $3),	-- look in this package
    find_deal($1, base, $3)	-- look in base package
  )::maybe_deal_ids
  FROM deal_packages dp WHERE id = $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_deal(line_item_ids, deal_package_ids)
RETURNS maybe_deal_ids AS $$
  SELECT find_deal( $1, $2, event_time() )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION must_get_deal(line_item_ids, deal_package_ids)
RETURNS maybe_deal_ids AS $$
DECLARE
  the_deal maybe_deal_ids := find_deal( $1, $2, event_time() );
BEGIN
  IF the_deal IS NULL THEN
    RAISE EXCEPTION 'must_get_deal(%, %): Sorry, no deal!', $1, $2;
  END IF;
  RETURN the_deal;
END
$$ LANGUAGE plpgsql STRICT;

-- need: FUNCTION expire_deal(deal_ids)
-- need: FUNCTION extend_deal(deal_ids, event_times)
-- need: FUNCTION change_deal(deal_ids, deal_kinds, us_pennies, time_ranges)

CREATE OR REPLACE
FUNCTION non_neg_amt(us_pennies) RETURNS us_pennies AS $$
  SELECT $1 WHERE $1 >= 0
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION neg_amt(us_pennies) RETURNS us_pennies AS $$
  SELECT $1 WHERE $1 < 0
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE		-- dummy for recursion
FUNCTION item_price(line_item_ids, deal_package_ids, event_times) RETURNS us_pennies AS $$
  SELECT NULL::us_pennies
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION item_price_(line_item_ids, deal_package_ids, event_times) RETURNS us_pennies AS $$
  SELECT CASE pd.kind
	WHEN 'deal_kind_fixed' THEN pd.amount
	WHEN 'deal_kind_percent'
	  THEN non_neg_amt( pennies_percent_off( item_price($1, dp.base, $3), pd.amount::numeric ) )
	WHEN 'deal_kind_discount'
	  THEN non_neg_amt( item_price($1, dp.base, $3) - pd.amount )
	WHEN 'deal_kind_special' THEN neg_amt(-pd.amount)
  END::us_pennies
  FROM line_items li, deal_packages dp, price_deals pd
  WHERE li.id = $1 AND dp.id = $2 AND pd.item_id = $1 AND pd.package_id = $2
    AND is_current(pd.starting, pd.ending, $3);
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION item_price(line_item_ids, deal_package_ids, event_times) RETURNS us_pennies AS $$
  SELECT COALESCE( item_price_($1, $2, $3), item_price($1, base, $3) )
  FROM deal_packages dp WHERE id = $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION item_price(line_item_ids, deal_package_ids) RETURNS us_pennies AS $$
  SELECT item_price( $1, $2, event_time() )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION item_price(text, text) RETURNS us_pennies AS $$
  SELECT item_price( line_item($1), deal_package($2, now_), now_ ) FROM event_time() now_
$$ LANGUAGE sql STRICT;

-- Concept: Base Price

-- a fixed-price deal in the BasePrices package

CREATE OR REPLACE
FUNCTION make_fixed_price(line_item_ids, us_pennies, time_ranges) RETURNS maybe_deal_ids AS $$
  SELECT make_deal( $1, 'deal_kind_fixed', base_price_pkg(), $2, $3 )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_fixed_price(text, us_pennies, time_ranges) RETURNS maybe_deal_ids AS $$
  SELECT make_deal( line_item($1), 'deal_kind_fixed', base_price_pkg(), $2, $3 )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_fixed_price(line_item_ids, us_pennies) RETURNS maybe_deal_ids AS $$
  SELECT make_deal( $1, 'deal_kind_fixed', base_price_pkg(), $2, time_range() )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_fixed_price(text, us_pennies) RETURNS maybe_deal_ids AS $$
  SELECT make_deal( line_item($1), 'deal_kind_fixed', base_price_pkg(), $2, time_range() )
$$ LANGUAGE sql STRICT;
