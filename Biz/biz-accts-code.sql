-- biz_accounting_code.sql
-- $Id: biz_accounting_code.sql,v 1.3 2008/04/18 02:05:46 lynn Exp $
-- Lynn Dobbs and Greg Davidson
-- April 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- Note: Some of the make_* functions could be done in
-- LANGUAGE sql, but I'm anticipating they may want some
-- additional code added which can only be done in plpgsql.

CREATE OR REPLACE
FUNCTION make_service_action(deal_ids) RETURNS service_action_ids AS $$
DECLARE 
  the_id maybe_service_action_ids;
BEGIN
  INSERT INTO service_actions (state, deal_id, starting, ending)
    VALUES( 'service_state_new', $1, time_range_start(), time_range_end() )
  RETURNING id INTO the_id;
  RETURN the_id;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION make_service_action(contact_ids, line_item_ids)
RETURNS service_action_ids AS $$
DECLARE
  deal maybe_deal_ids := find_deal($2, get_client_package($1));
BEGIN
  IF deal IS NULL THEN
    RAISE EXCEPTION 'make_service_action(%, %): No such deal', $1, $2;
  END IF;
  RETURN make_service_action(deal);
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION make_service_action(contact_ids, text)
RETURNS service_action_ids AS $$
  SELECT make_service_action($1, line_item($2))
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_service_action_tree(service_action_ids, service_action_id_arrays)
RETURNS service_action_ids AS $$
BEGIN
  FOR i IN array_lower($2, 1) .. array_upper($2, 1) LOOP
    INSERT INTO service_action_trees(whole_id, part_id) VALUES($1, $2[i]);
  END LOOP;
  INSERT INTO service_action_parts(whole_id, parts) VALUES($1, $2);
  RETURN $1;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION make_service_action_payment(service_action_ids, us_pennies)
RETURNS service_action_ids AS $$
    INSERT INTO service_action_payments(service_action_id, amount) VALUES($1, $2);
    SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_service_action_reverse(service_action_ids, service_action_ids)
RETURNS service_action_ids AS $$
    INSERT INTO service_action_reverses(service_action_id, other_service_id)
    VALUES($1, $2);
    SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_service_action_special(service_action_ids, us_pennies, text)
RETURNS service_action_ids AS $$
    INSERT INTO service_action_special(service_action_id, amount, explanation)
     VALUES($1, $2, $3);
    SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION service_state_text(service_states)
RETURNS text AS $$
	select replace(substring($1::text FROM 15),'_',' ')
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
VIEW view_service_actions (
  trans_id, whole_id, start_when, finish_when,
  state, what, who, sub_account
) AS
   SELECT sa.id, whole_id,
   time_text(sa.starting),time_text(sa.ending),service_state_text(state),
     line_item_text(item_id),contact_text(customer_id),
     CASE WHEN subacct_id IS NULL THEN '' ELSE contact_text(subacct_id) END
   FROM service_actions sa
   LEFT JOIN service_request_actions sra ON (sa.id = top_action_id)
   LEFT JOIN service_requests sr ON (sr.id = sra.request_id)
   LEFT JOIN price_deals ON (sa.deal_id = item_id)
   LEFT JOIN service_action_trees ON (sa.id = part_id);

CREATE OR REPLACE
FUNCTION make_service_request_action(service_request_ids, service_action_ids)
RETURNS service_action_ids AS $$
  INSERT INTO service_request_actions(request_id, top_action_id) VALUES( $1, $2 );
  SELECT $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_service_request_action(text, service_action_ids)
RETURNS service_action_ids AS $$
  SELECT make_service_request_action(services_id($1), $2)
$$ LANGUAGE sql STRICT;

