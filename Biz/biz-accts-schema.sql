-- biz_accounting_schema.sql
-- $Id: biz_accounting_schema.sql,v 1.5 2008/04/30 17:17:07 lynn Exp $
-- realizing Business::Accounting classes
-- Lynn Dobbs and Greg Davidson
-- 25 March 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- This is a schema file, so source it only
-- into a new database!!!

-- Requires:
--	us_pennies and line_items from utility_money

-- Accounting Transactions realtime

CREATE DOMAIN service_action_ids AS integer NOT NULL;
CREATE DOMAIN maybe_service_action_ids AS integer;
CREATE DOMAIN service_action_id_arrays AS integer[] NOT NULL;

CREATE SEQUENCE service_action_id_seq;

CREATE OR REPLACE
FUNCTION next_service_action_id() RETURNS service_action_ids AS $$
  SELECT nextval('service_action_id_seq')::service_action_ids
$$ LANGUAGE sql;

CREATE TYPE service_states AS ENUM (
	'service_state_new',	-- work needs to be scheduled
	'service_state_in_process', --scheduled work is incomplete
	'service_state_stalled', -- agent intervention needed
	'service_state_failed',
	'service_state_complete'
);

CREATE TABLE service_actions (
  id service_action_ids PRIMARY KEY DEFAULT next_service_action_id(),
  state service_states NOT NULL DEFAULT 'service_state_new',
  deal_id deal_ids NOT NULL REFERENCES price_deals
) INHERITS(time_ranges);
COMMENT ON TABLE service_actions IS
'Actions to fulfill service_request.
 Referenced by service_request_actions';

ALTER SEQUENCE service_action_id_seq OWNED BY service_actions.id;

SELECT handles_for('service_actions');
SELECT notes_for('service_actions');

CREATE OR REPLACE
FUNCTION service_action_item_kind(service_action_ids) RETURNS line_item_kinds AS $$
  SELECT item.kind FROM line_items item, service_actions action, price_deals deal
  WHERE action.id = $1 AND deal.id = action.deal_id AND item.id = deal.item_id
$$ LANGUAGE sql;

CREATE TABLE service_action_trees (
  whole_id service_action_ids NOT NULL REFERENCES service_actions,
  part_id service_action_ids NOT NULL REFERENCES service_actions,
  UNIQUE(whole_id, part_id)
);

CREATE TABLE service_action_parts (
  whole_id service_action_ids PRIMARY KEY REFERENCES service_actions,
  parts service_action_id_arrays NOT NULL
);

CREATE TABLE service_action_payments (
  service_action_id service_action_ids PRIMARY KEY REFERENCES service_actions,
  amount us_pennies NOT NULL,
  CONSTRAINT service_action_deals_line_item_kind
  CHECK (service_action_item_kind(service_action_id) = 'item_kind_chargeable')
);

CREATE TABLE service_action_reverses (
  service_action_id service_action_ids PRIMARY KEY REFERENCES service_actions,
  other_service_id service_action_ids NOT NULL REFERENCES service_actions,
  CONSTRAINT service_action_deals_line_item_kind
  CHECK (service_action_item_kind(service_action_id) = 'item_kind_reverse')
);

CREATE TABLE service_action_special (
  service_action_id service_action_ids PRIMARY KEY REFERENCES service_actions,
  amount us_pennies NOT NULL,
  explanation TEXT
--  CONSTRAINT service_action_deals_line_item_kind
--  CHECK (service_action_item_kind(service_action_id) = 'item_kind_kind_special')
  -- probably needs authorization
);

CREATE TABLE service_request_actions (
  request_id service_request_ids REFERENCES service_requests,
  top_action_id service_action_ids PRIMARY KEY REFERENCES service_actions,
  UNIQUE(request_id, top_action_id)
);

SELECT handles_for('service_request_actions');
