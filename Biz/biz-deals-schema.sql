-- utility_deals_schema.sql
-- $Id: utility_deals_schema.sql,v 1.5 2008/04/30 17:16:46 lynn Exp $
-- generic support for dealing with money, line_items and deals
-- price_deals and deal_packages support pricing and time travel
-- Lynn Dobbs and Greg Davidson

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * Concept: Money

-- Note:  The PostgreSQL type "money" is deprecated!

CREATE DOMAIN us_pennies AS bigint NOT NULL;
COMMENT ON DOMAIN us_pennies IS 'represents money in US Pennies';

-- * Concept: Line Items

CREATE TYPE line_item_kinds AS ENUM (
  'item_kind_no_money',		-- money not involved
  'item_kind_total',		-- just a total or subtotal
  'item_kind_chargeable',	-- you can charge for this
  'item_kind_creditable',	-- you can give money back for this
  'item_kind_reverse'		-- oops! reverse of earlier charge???
);
COMMENT ON TYPE line_item_kinds IS
'The kind of monetary value, if any, which might be associated
with a given line item.  ???Charge reversals might go away if we
handle them at the transaction level???';

-- Move the next two comments to the appropriate place in the
-- system:

-- All transactions should have a reference to another transaction
-- which is used in case of reversals.  A transaction which has not
-- been reversed will have NULL there.  A reversed transaction will
-- have a reference to the reversing transaction in its future
-- which will have a back reference to it.

-- In the case where a reversal of a transaction affects downstream
-- charges, e.g. finance charges, there will be a single tree of
-- transactions containing reversals for all affected items
-- and new revised credits and debits where applicable.  This means
-- that we need time travel to be able to ignore reversals in
-- order to properly interpret past bills.  It also suggests that
-- the running balance idea is a bad idea.

CREATE DOMAIN line_item_ids AS integer NOT NULL;
CREATE DOMAIN maybe_line_item_ids AS integer;

CREATE SEQUENCE line_item_id_seq;

CREATE OR REPLACE
FUNCTION next_line_item_id() RETURNS line_item_ids AS $$
  SELECT nextval('line_item_id_seq')::line_item_ids
$$ LANGUAGE sql;

CREATE TABLE line_items (
  id line_item_ids PRIMARY KEY DEFAULT next_line_item_id(),
  kind line_item_kinds NOT NULL,
  name text NOT NULL,
  UNIQUE (kind,name)
);
COMMENT ON TABLE line_items IS
'Identifies what a line item is for in any kind transaction register.
If chargeable, the amount should be given by a deal.';

ALTER SEQUENCE line_item_id_seq OWNED BY line_items.id;

SELECT notes_for('line_items');
SELECT handles_for('line_items');

-- CREATE TABLE abstract_line_items (
--   kind line_item_kinds NOT NULL,
--   item_id line_item_ids PRIMARY KEY REFERENCES line_items,
--   charge us_pennies NOT NULL
-- );
-- COMMENT ON TABLE abstract_line_items IS
-- 'just an idea';

-- SELECT abstract_trigger_for('abstract_line_items');

-- * deal packages

CREATE DOMAIN deal_package_ids AS integer NOT NULL;
CREATE DOMAIN maybe_deal_package_ids AS integer;

CREATE SEQUENCE deal_package_id_seq;

CREATE OR REPLACE
FUNCTION next_deal_package_id() RETURNS deal_package_ids AS $$
  SELECT nextval('deal_package_id_seq')::deal_package_ids
$$ LANGUAGE sql;

CREATE TABLE deal_packages (
  id deal_package_ids PRIMARY KEY DEFAULT next_deal_package_id(),
  base maybe_deal_package_ids,
  name text NOT NULL
--  UNIQUE(name, starting, ending)
) INHERITS (time_ranges);
COMMENT ON TABLE deal_packages IS 
'A collection of deals for pricing service actions.  Only one deal for
a given item should be current at a time.';
COMMENT ON COLUMN deal_packages.base IS
'When not null and we lack a fixed_price deal for an item, we can try
a recursive search up the base links to establish a price.  This must
be possible in order for a percent or discount deal to be associated
with a package.';

ALTER TABLE deal_packages
ADD CONSTRAINT deal_packages_base
FOREIGN KEY (base) REFERENCES deal_packages (id) MATCH FULL;

-- add appropriate indexes for name, starting, ending

ALTER SEQUENCE deal_package_id_seq OWNED BY deal_packages.id;

SELECT notes_for('deal_packages');
SELECT handles_for('deal_packages');

CREATE FUNCTION base_price_pkg() RETURNS deal_package_ids AS $$
  SELECT (-1)::deal_package_ids
$$ LANGUAGE sql IMMUTABLE;

INSERT INTO deal_packages(id, name, base, starting, ending) VALUES(
  base_price_pkg(), 'BasePrices', NULL, time_range_start(), time_range_end()
);
-- Consider creating a graveyard for any package which gets
-- highly clotted with old expired deals.

-- * deals

CREATE TYPE deal_kinds AS ENUM (
  'deal_kind_fixed',	-- fixed charge
  'deal_kind_percent',	-- adjust by this percent
  'deal_kind_discount',	-- adjust by this amount
  'deal_kind_special'	-- call a special function
);
COMMENT ON TYPE deal_kinds IS
'How to interpret the "amount" field of a deal.';

CREATE DOMAIN deal_ids AS integer NOT NULL;
CREATE DOMAIN maybe_deal_ids AS integer;

CREATE SEQUENCE deal_id_seq;

CREATE OR REPLACE
FUNCTION next_deal_id() RETURNS deal_ids AS $$
  SELECT nextval('deal_id_seq')::deal_ids
$$ LANGUAGE sql;

CREATE TABLE price_deals (
  id deal_ids PRIMARY KEY DEFAULT next_deal_id(),
  package_id deal_package_ids NOT NULL REFERENCES deal_packages,
  kind deal_kinds,
  item_id line_item_ids NOT NULL REFERENCES line_items,
--  UNIQUE(package_id, item_id, starting, ending),
  amount us_pennies
) INHERITS (time_ranges);
COMMENT ON TABLE price_deals IS
'A deal establishes a price, if any, for a given sort of monetary
transaction.  Deals are bound to deal packages.  Only one deal
for a given item should be current at a time.';
COMMENT ON COLUMN price_deals.item_id IS
'The line_item_kind of the item must be chargeable;
perhaps creditable could also be allowed?';
COMMENT ON COLUMN price_deals.amount IS
'Kludge alert:
When kind = deal_kind_percent then this is really a percent.
When kind = deal_kind_special then this is a code for a function.
Otherwise, this is an amount of money.';

-- add appropriate indexes for package, item, starting, ending

ALTER SEQUENCE deal_id_seq OWNED BY price_deals.id;

SELECT notes_for('price_deals');
SELECT handles_for('price_deals');


