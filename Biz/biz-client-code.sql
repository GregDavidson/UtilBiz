-- biz_client_code.sql
-- $Id: biz_client_code.sql,v 1.3 2008/05/03 00:11:47 lynn Exp $
-- generic support for business clients
-- Lynn Dobbs and Greg Davidson
-- 25 March 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- pattern matching

CREATE OR REPLACE
FUNCTION words_to_like(text) RETURNS TEXT AS $$
  SELECT '%' || regexp_replace(str_trim_deep($1),' ','% ', 'g') || '%'
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION name_matches(text, text) RETURNS boolean AS $$
  SELECT $1 ILIKE words_to_like($2)
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION name_matches(xml, text) RETURNS boolean AS $$
  SELECT name_matches(xml_text($1), $2) OR $2 = ANY( xml_attr('a', $1) )
$$ LANGUAGE sql STRICT IMMUTABLE;

-- * Concept: Business Contacts

CREATE OR REPLACE
FUNCTION org_text(contact_ids) RETURNS text AS $$
  SELECT xml_text(name) FROM org_contacts WHERE id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION individual_text(contact_ids) RETURNS text AS $$
  SELECT xml_text(name) FROM individual_contacts WHERE id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION emp_text(contact_ids) RETURNS text AS $$
  SELECT xml_text(name) FROM employee_contacts WHERE id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION subacct_text(contact_ids) RETURNS text AS $$
  SELECT xml_text(name) FROM sub_account_contacts WHERE id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION contact_text(contact_ids) RETURNS text AS $$
  SELECT COALESCE(
    org_text($1),
    individual_text($1),
    emp_text($1),
    subacct_text($1)
  )
$$ LANGUAGE sql STRICT;

-- ** Sub-Concept: Business Contact Searches

-- We probably don't want to do text searches on employee contact role
-- names, employee contact individual names or subaccount names
-- because these things are best found by association from an
-- organization contact.  Therefore these next routines are probably
-- too general, and here they are anyway:

-- contacts_by_attr(xml_attr, text_to_match)
CREATE OR REPLACE
FUNCTION contacts_by_attr(text, text) RETURNS SETOF contact_ids AS $$
  SELECT id FROM abstract_contacts WHERE $2 = ANY(xml_attr($1, name))
$$ LANGUAGE sql STRICT;

-- contacts_by_subtext(xml_tag, text_to_match)
CREATE OR REPLACE
FUNCTION contacts_by_subtext(text, text) RETURNS SETOF contact_ids AS $$
  SELECT id FROM abstract_contacts WHERE $2 = ANY(xml_subtext($1, name))
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION contacts_like(text) RETURNS SETOF contact_ids AS $$
  SELECT id FROM abstract_contacts WHERE xml_text(name) ILIKE words_to_like($1)
$$ LANGUAGE sql STRICT;

-- It is reasonable to do text searches on part or all of
-- an individual's or organization's names.

-- *** finding orgs

-- orgs_by_subtext(xml_tag, text_to_match)
CREATE OR REPLACE
FUNCTION orgs_by_subtext(text, text) RETURNS SETOF contact_ids AS $$
  SELECT id FROM org_contacts WHERE $2 = ANY(xml_subtext($1, name))
$$ LANGUAGE sql STRICT;

-- orgs_by_attr(xml_attr, text_to_match)
CREATE OR REPLACE
FUNCTION orgs_by_attr(text, text) RETURNS SETOF contact_ids AS $$
  SELECT id FROM org_contacts WHERE $2 = ANY(xml_attr($1, name))
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION orgs_by_altname(text) RETURNS SETOF contact_ids AS $$
  SELECT orgs_by_attr('a', $1)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION orgs_like(text) RETURNS SETOF contact_ids AS $$
  SELECT id FROM org_contacts WHERE xml_text(name) ILIKE words_to_like($1)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_orgs(text) RETURNS SETOF contact_ids AS $$
  SELECT orgs_by_altname($1)
  UNION
  SELECT orgs_like($1)
$$ LANGUAGE sql STRICT;

-- finding individuals

-- individuals_by_subtext(xml_tag, text_to_match)
CREATE OR REPLACE
FUNCTION individuals_by_subtext(text, text) RETURNS SETOF contact_ids AS $$
  SELECT id FROM individual_contacts WHERE $2 = ANY(xml_subtext($1, name))
$$ LANGUAGE sql STRICT;

-- individuals_by_attr(xml_attr, text_to_match)
CREATE OR REPLACE
FUNCTION individuals_by_attr(text, text) RETURNS SETOF contact_ids AS $$
  SELECT id FROM individual_contacts WHERE $2 = ANY(xml_attr($1, name))
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION individuals_by_surname(text) RETURNS SETOF contact_ids AS $$
  SELECT individuals_by_subtext('f', $1)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION individuals_by_givenname(text) RETURNS SETOF contact_ids AS $$
  SELECT individuals_by_subtext('g', $1)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION individuals_by_nickname(text) RETURNS SETOF contact_ids AS $$
  SELECT individuals_by_subtext('n', $1)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION individuals_like(text) RETURNS SETOF contact_ids AS $$
  SELECT id FROM individual_contacts WHERE xml_text(name) ILIKE words_to_like($1)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_individuals(text) RETURNS SETOF contact_ids AS $$
-- this should probably be made smarter
-- need to check altnames, perhaps??
  SELECT individuals_like($1)
$$ LANGUAGE sql STRICT;

-- can this go wrong???
CREATE OR REPLACE
FUNCTION family_name(xml) RETURNS text AS $$
  SELECT x[1] FROM xml_subtext('f', $1) x
  WHERE array_length(x) = 1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION individuals_by_last_other(text, text) RETURNS SETOF contact_ids AS $$
  SELECT id FROM individual_contacts
  WHERE $1 = family_name(name) AND name_matches(name, $2)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION individuals_by_last_other(text, text) IS
'(last name, other name(s)) -> set of individual contacts who have
the indicated last name, and the other name is either
one of their alternate names or is one or more words in their name';

CREATE OR REPLACE
FUNCTION emps_by_name_org(text, text) RETURNS SETOF contact_ids AS $$
  SELECT emp.id FROM employee_contacts emp
  LEFT JOIN org_contacts org ON (org.id = works_for)
  LEFT JOIN individual_contacts ind ON (ind.id = staffed_by)
  WHERE xml_text(ind.name) ILIKE words_to_like($1)
  AND xml_text(org.name) ILIKE words_to_like($2)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION emps_by_name_org(text, text) IS
'(individual name(s), org name(s)) -> set of employee contacts who have
the indicated name(s), and work for the indicated organization';

CREATE OR REPLACE
FUNCTION find_contacts(text) RETURNS SETOF contact_ids AS $$
  SELECT find_orgs($1) UNION
  SELECT find_individuals($1) ORDER BY 1
$$ LANGUAGE sql STRICT;

-- should really be an error if there's more than one!!!
CREATE OR REPLACE
FUNCTION contacts_id(handles) RETURNS contact_ids AS $$
  SELECT COALESCE(
    (SELECT id FROM individual_contacts_row_handles WHERE handle = $1),
    (SELECT id FROM org_contacts_row_handles WHERE handle = $1),
    employee_contacts_id($1)	-- should bomb if fails
  )
$$ LANGUAGE sql STRICT;

-- Sub-Concept: Individual Contacts

CREATE OR REPLACE
FUNCTION make_individual_contact_(contact_ids, XML) RETURNS contact_ids AS $$
  INSERT INTO individual_contacts(id, name) VALUES ($1, $2);
  SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_individual_contact(XML) RETURNS contact_ids AS $$
  SELECT make_individual_contact_(next_contact_id(), $1)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION make_individual_contact(XML) IS
'This will happily make a duplicate, so be sure this is really
distinct from any other contacts of the same name!!';

-- Sub-Concept: Organization Contacts

CREATE OR REPLACE
FUNCTION make_org_contact_(contact_ids, XML) RETURNS contact_ids AS $$
  INSERT INTO org_contacts(id, name) VALUES ($1, $2);
  SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_org_contact(xml) RETURNS contact_ids AS $$
  SELECT make_org_contact_(next_contact_id(), $1)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION make_org_contact(XML) IS
'This will happily make a duplicate, so be sure this is really
distinct from any other contacts of the same name!!';

-- Sub-Concept: Subaccount Contacts

-- Subacct code is NOT DONE!!!

-- finding and/or creating simple subaccounts

CREATE OR REPLACE
FUNCTION find_subacct(text, contact_ids) RETURNS SETOF contact_ids AS $$
  SELECT id FROM abstract_contacts, client_subaccounts
  WHERE xml_text(name) = $1 AND id = subacct_id AND client_id = $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_subacct(contact_ids) RETURNS SETOF contact_ids AS $$
  SELECT id FROM abstract_contacts, client_subaccounts
  WHERE id = subacct_id AND client_id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_subacct_like(text, contact_ids) RETURNS SETOF contact_ids AS $$
  SELECT id FROM abstract_contacts, client_subaccounts
  WHERE xml_text(name) ILIKE '%' || $1 || '%'
  AND id = subacct_id AND client_id = $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION notes_text_on(subaccount_keys) RETURNS text AS $$
  SELECT attributed_notes_text(client_subaccounts_notes_array(($1).client_id, ($1).subacct_id))
$$ LANGUAGE SQL STRICT;
COMMENT ON FUNCTION notes_text_on(subaccount_keys) IS
'notes_text_on(subaccount_keys) -> nicely formatted notes';

CREATE OR REPLACE
FUNCTION subacct_note(contact_ids, contact_ids, text, xml) RETURNS subaccount_keys AS $$
  SELECT add_client_subaccounts_note(make_attributed_note($3, $4), $1, $2);
  SELECT row($1,$2)::subaccount_keys
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION subacct_note(subaccount_keys, text, xml) RETURNS subaccount_keys AS $$
  SELECT subacct_note( ($1).client_id, ($1).subacct_id, $2, $3);
  SELECT $1
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION make_subacct(contact_ids, contact_ids) 
 RETURNS void AS $$
  INSERT INTO client_subaccounts(client_id, subacct_id) 
      VALUES ($1, $2)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_subacct(subaccount_keys) 
 RETURNS subaccount_keys AS $$
  SELECT make_subacct( ($1).client_id,($1).subacct_id);
  SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_subacct(subaccount_keys, text, xml) 
 RETURNS subaccount_keys AS $$
  SELECT subacct_note($1,$2,$3);
  SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_subacct_category(contact_ids, XML) RETURNS contact_ids AS $$
  SELECT id FROM client_subaccounts, abstract_contacts
  WHERE client_id = $1 AND name::text = $2::text AND id < 0
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION new_subacct_category_(contact_ids,XML) RETURNS contact_ids AS $$
  INSERT INTO sub_account_contacts (id,name)
     VALUES ($1,$2);
   SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION new_subacct_category(XML) RETURNS contact_ids AS $$
  SELECT new_subacct_category_ ( next_sub_contact_id(), $1 )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION get_subacct_category(contact_ids, XML) RETURNS contact_ids AS $$
  SELECT COALESCE(
    find_subacct_category($1, $2),
    new_subacct_category($2)
  )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_client_category(contact_ids, XML) RETURNS contact_ids AS $$
  INSERT INTO client_subaccounts( client_id, subacct_id)
      VALUES ($1, get_subacct_category($1, $2));
  SELECT find_subacct_category($1, $2)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION is_subaccount(contact_ids) RETURNS bool AS $$
  SELECT $1 IN (SELECT subacct_id FROM client_subaccounts)
$$ LANGUAGE sql STRICT;

-- Sub-Concept: Employee Contacts

CREATE OR REPLACE
FUNCTION is_employee(contact_ids) RETURNS bool AS $$
  SELECT $1 IN (SELECT staffed_by FROM employee_contacts)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION employee_of_position(contact_ids) RETURNS contact_ids AS $$
  SELECT staffed_by FROM employee_contacts WHERE id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION employer_of_position(contact_ids) RETURNS contact_ids AS $$
  SELECT works_for FROM employee_contacts WHERE id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_employee_by_position(text) RETURNS SETOF contact_ids AS $$
  SELECT id FROM employee_contacts WHERE xml_text(name) = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_employee_by_employer(contact_ids) RETURNS SETOF contact_ids AS $$
  SELECT id FROM employee_contacts WHERE works_for = $1
$$ LANGUAGE sql STRICT;

--  find_employee(employer id, employee id)
CREATE OR REPLACE
FUNCTION find_employee(contact_ids, contact_ids)
RETURNS contact_ids AS $$
  SELECT id FROM employee_contacts
  WHERE works_for = $1 AND staffed_by = $2
$$ LANGUAGE sql STRICT;

--  make_employee_(new id, position name, employer id, employee id)
CREATE OR REPLACE
FUNCTION make_employee_(contact_ids, xml, contact_ids, contact_ids)
RETURNS contact_ids AS $$
  INSERT INTO employee_contacts(id, name, works_for, staffed_by)
    VALUES ($1, $2, $3, $4);
  SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE -- Fix naming convention && fix unique constraint issue !!
FUNCTION make_employee(xml, contact_ids, contact_ids) RETURNS contact_ids AS $$
  SELECT COALESCE(
    find_employee($2, $3),
    make_employee_(next_contact_id(), $1, $2, $3)
   )::contact_ids
$$ LANGUAGE sql STRICT;

-- Concept Linkage: Contact Communication Vias Linkages

CREATE OR REPLACE
FUNCTION find_comm_vias(regclass, contact_ids)
RETURNS SETOF comm_via_ids AS $$
  SELECT via.id
  FROM abstract_comm_vias via, contact_comm_vias link
  WHERE via.tableoid = $1 AND link.comm_via_id = via.id AND link.contact_id = $2
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION find_comm_vias(regclass,contact_ids) IS
'return the contact vias of a specific type
associated with a specific business contact';

CREATE OR REPLACE
FUNCTION make_contact_comm_via(contact_ids, comm_via_ids) RETURNS void AS $$
BEGIN
  BEGIN
    INSERT INTO contact_comm_vias(contact_id, comm_via_id) VALUES($1, $2);
  EXCEPTION WHEN unique_violation THEN
      RAISE NOTICE 'add_contact_comm_via(%, %): already exists', $1, $2;
      -- we could throw an exception here!
  END;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION set_comm_feature_set(
  contact_ids, comm_via_ids, comm_feature_sets
) RETURNS void AS $$
BEGIN
  BEGIN
    UPDATE contact_comm_vias SET features = $3
    WHERE contact_id = $1 AND comm_via_id = $2;
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'set_comm_feature_set(%, %): does not exist', $1, $2;
    -- we could throw an exception here!
  END;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION make_contact_comm_via(
  contact_ids, comm_via_ids, comm_feature_sets
) RETURNS void AS $$
BEGIN
  BEGIN
    INSERT INTO contact_comm_vias(contact_id, comm_via_id, features)
      VALUES($1, $2, $3);
  EXCEPTION WHEN unique_violation THEN
      RAISE NOTICE 'add_contact_comm_via(%, %, features): already exists', $1, $2;
  END;
  PERFORM set_comm_feature_set($1, $2, $3);
END
$$ LANGUAGE plpgsql STRICT;

-- should throw an exception if not found!!
CREATE OR REPLACE
FUNCTION comm_feature(text) RETURNS comm_features AS $$
  SELECT non_null(id, 'comm_feature(text)')
  FROM comm_via_features WHERE name = $1
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION comm_feature_set(text[]) RETURNS comm_feature_sets AS $$
  SELECT to_bitset(ARRAY(
    SELECT comm_feature(feat)::integer
    FROM array_to_list($1) feat
  ))::comm_feature_sets
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION in_comm_feature_set(comm_features, comm_feature_sets)
RETURNS boolean AS $$
  SELECT in_bitset($1::integer, $2::bitsets)
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION comm_feature_set_text(comm_feature_sets) RETURNS text[] AS $$
  SELECT ARRAY(SELECT name FROM comm_via_features
  WHERE in_comm_feature_set(id, $1))
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION get_comm_feature_set(contact_ids, comm_via_ids)
RETURNS comm_feature_sets AS $$
  SELECT features FROM contact_comm_vias WHERE contact_id = $1 AND comm_via_id = $2
$$ LANGUAGE sql STRICT;

-- Concept Phone

CREATE OR REPLACE
FUNCTION find_phones(contact_ids)
RETURNS SETOF comm_via_ids AS $$
  SELECT find_comm_vias('phone_numbers'::regclass, $1)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION naked_phone(text) RETURNS text AS $$
  SELECT regexp_replace($1, '[^0-9]', '', 'g')
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION bare_phone(text) RETURNS numeric AS $$
  SELECT naked_phone($1)::numeric
$$ LANGUAGE sql STRICT;

-- phone_matches(stored phone_number: text or xml, stored bare phone number: numeric, test text)
-- make smarter???
CREATE OR REPLACE
FUNCTION phone_matches(text, numeric, text) RETURNS boolean AS $$
  SELECT clothed LIKE ('%' || $3 || '%') OR bare LIKE ('%' || naked || '%')
  FROM CAST($1 AS text) clothed, CAST($2 AS text) bare, naked_phone($3) naked
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_phone(text) RETURNS comm_via_ids AS $$
  SELECT id FROM phone_numbers WHERE phone_matches(number, bare_number, $1)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION make_phone_(comm_via_ids, text) RETURNS comm_via_ids AS $$
  INSERT INTO phone_numbers (id, number, bare_number)
    VALUES ($1, $2, bare_phone($2));
  SELECT $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION make_phone(text) RETURNS comm_via_ids AS $$
  SELECT COALESCE(
    find_phone($1), make_phone_(next_comm_via_id(), $1)
  )::comm_via_ids
$$ LANGUAGE sql;
COMMENT ON FUNCTION make_phone(text) IS 'warn if exists???';

-- should throw an exception if not found!!
CREATE OR REPLACE
FUNCTION phone_feature(text) RETURNS phone_features AS $$
  SELECT non_null(id, 'phone_feature(text)')
  FROM phone_number_features WHERE name = $1
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION phone_feature_set(text[]) RETURNS phone_feature_sets AS $$
  SELECT to_bitset(ARRAY(
    SELECT phone_feature(feat)::integer
    FROM array_to_list($1) feat
  ))::phone_feature_sets
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION in_phone_feature_set(phone_features, phone_feature_sets)
RETURNS boolean AS $$
  SELECT in_bitset($1::integer, $2::bitsets)
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION phone_feature_set_text(phone_feature_sets) RETURNS text[] AS $$
  SELECT ARRAY(SELECT name FROM phone_number_features
  WHERE in_phone_feature_set(id, $1))
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION get_phone_feature_set(comm_via_ids)
RETURNS phone_feature_sets AS $$
  SELECT features FROM phone_numbers WHERE id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION set_phone_feature_set(comm_via_ids, phone_feature_sets)
RETURNS comm_via_ids AS $$
  UPDATE phone_numbers SET features = $2 WHERE id = $1;
  SELECT $1
$$ LANGUAGE sql STRICT;

-- Concept Email Address

CREATE OR REPLACE
FUNCTION find_emails(contact_ids)
RETURNS SETOF comm_via_ids AS $$
  SELECT find_comm_vias('email_addresses'::regclass, $1)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION canonical_email(text) RETURNS text AS $$
  SELECT trim(FROM lower($1))
$$ LANGUAGE sql;
COMMENT ON FUNCTION canonical_email(text) IS
'improve this so it strips out any comment parts or padding!';

-- email_matches(email address, text)
-- make this smarter???
CREATE OR REPLACE
FUNCTION email_matches(text, text) RETURNS boolean AS $$
  SELECT $1 = $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_email(text) RETURNS comm_via_ids AS $$
  SELECT id FROM email_addresses WHERE email = $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION make_email_(comm_via_ids, text) RETURNS comm_via_ids AS $$
  INSERT INTO email_addresses (id, email)
    VALUES ($1, canonical_email($2));
  SELECT $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION make_email(text) RETURNS comm_via_ids AS $$
  SELECT COALESCE(
    find_email($1), make_email_(next_comm_via_id(), $1)
  )::comm_via_ids
$$ LANGUAGE sql;
COMMENT ON FUNCTION make_email(text) IS 'warn if exists???';

-- should throw an exception if not found!!
CREATE OR REPLACE
FUNCTION email_feature(text) RETURNS email_features AS $$
  SELECT non_null(id, 'email_feature(text)')
  FROM email_address_features WHERE name = $1
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION email_feature_set(text[]) RETURNS email_feature_sets AS $$
  SELECT to_bitset(ARRAY(
    SELECT email_feature(feat)::integer
    FROM array_to_list($1) feat
  ))::email_feature_sets
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION in_email_feature_set(email_features, email_feature_sets)
RETURNS boolean AS $$
  SELECT in_bitset($1::integer, $2::bitsets)
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION email_feature_set_text(email_feature_sets) RETURNS text[] AS $$
  SELECT ARRAY(SELECT name FROM email_address_features
  WHERE in_email_feature_set(id, $1))
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION get_email_feature_set(comm_via_ids)
RETURNS email_feature_sets AS $$
  SELECT features FROM email_addresses WHERE id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION set_email_feature_set(comm_via_ids, email_feature_sets)
RETURNS comm_via_ids AS $$
  UPDATE email_addresses SET features = $2 WHERE id = $1;
  SELECT $1
$$ LANGUAGE sql STRICT;

-- Concept Postal Address

CREATE OR REPLACE
FUNCTION find_postals(contact_ids)
RETURNS SETOF comm_via_ids AS $$
  SELECT find_comm_vias('postal_addresses'::regclass, $1)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION canonical_postal_address(text) RETURNS text AS $$
  SELECT $1
$$ LANGUAGE sql;
COMMENT ON FUNCTION canonical_postal_address(text) IS
'This should run the address through the USPS!!';

-- zip_matches(zip, text)
-- make this smarter???
CREATE OR REPLACE
FUNCTION zip_matches(postal_codes, text) RETURNS boolean AS $$
  SELECT $1 = $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_postal_by_zip(text) RETURNS SETOF comm_via_ids AS $$
  SELECT id FROM postal_addresses WHERE zip_matches(zip, $1)
$$ LANGUAGE sql STRICT;

-- state_matches(state, text)
-- make this smarter???
CREATE OR REPLACE
FUNCTION state_matches(state_codes, text) RETURNS boolean AS $$
  SELECT $1 = $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_postal_by_state(text) RETURNS SETOF comm_via_ids AS $$
  SELECT id FROM postal_addresses WHERE state_matches(state, $1)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_postal_by_state(state_codes) RETURNS SETOF comm_via_ids AS $$
  SELECT id FROM postal_addresses WHERE state = $1
$$ LANGUAGE sql STRICT;

-- city_matches(city, text)
-- make this smarter???
CREATE OR REPLACE
FUNCTION city_matches(city_names, text) RETURNS boolean AS $$
  SELECT $1 = $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_postal_by_city(text) RETURNS SETOF comm_via_ids AS $$
  SELECT id FROM postal_addresses WHERE city_matches(city, $1)
$$ LANGUAGE sql STRICT;

-- street_matches(street address lines, text)
-- make this smarter???
CREATE OR REPLACE
FUNCTION street_matches(text[], text) RETURNS boolean AS $$
  SELECT array_to_string($1, ' ') ILIKE words_to_like($2)
$$ LANGUAGE sql STRICT;

-- street_matches(street address string, text)
-- make this smarter???
CREATE OR REPLACE
FUNCTION street_matches(text, text) RETURNS boolean AS $$
  SELECT $1 ILIKE words_to_like($2)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_postal_by_street(text)
RETURNS SETOF comm_via_ids AS $$
  SELECT id FROM postal_addresses
  WHERE street_matches(addr_lines, $1)
$$ LANGUAGE sql STRICT;

-- country_matches(country, text)
-- make this smarter???
CREATE OR REPLACE
FUNCTION country_matches(country_codes, text) RETURNS boolean AS $$
  SELECT $1 = $2
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_postal(
  text, text, text, text, text
) RETURNS SETOF comm_via_ids AS $$
  SELECT id FROM postal_addresses
  WHERE COALESCE( street_matches(addr_lines, $1), true )
  AND COALESCE( city_matches(city, $2), true)
  AND COALESCE( state_matches(state, $3), true)
  AND COALESCE( country_matches(country, $4), true)
  AND COALESCE( zip_matches(zip, $5), true)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION find_strict_postal(
  text[], city_names, state_codes, country_codes, postal_codes
) RETURNS comm_via_ids AS $$
  SELECT id FROM postal_addresses
  WHERE addr_lines = $1 AND city = $2 AND state = $3 AND country = $4 AND zip = $5
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_postal_( comm_via_ids,
  text[], city_names, state_codes, country_codes, postal_codes
) RETURNS comm_via_ids AS $$
  INSERT INTO postal_addresses (id, addr_lines, city, state, country, zip)
    VALUES ($1, $2, $3, $4, $5, $6);
  SELECT $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION make_postal(text[], city_names, state_codes, country_codes, postal_codes)
RETURNS comm_via_ids AS $$
  SELECT COALESCE(
    find_strict_postal($1, $2, $3, $4, $5),
    make_postal_( next_comm_via_id(), $1, $2, $3, $4, $5 )
  )::comm_via_ids
$$ LANGUAGE sql;
COMMENT ON
FUNCTION make_postal(text[], city_names, state_codes, country_codes, postal_codes)
IS 'warn if exists???';

-- should throw an exception if not found!!
CREATE OR REPLACE
FUNCTION postal_feature(text) RETURNS postal_features AS $$
  SELECT non_null(id, 'postal_feature(text)')
  FROM postal_address_features WHERE name = $1
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION postal_feature_set(text[]) RETURNS postal_feature_sets AS $$
  SELECT to_bitset(ARRAY(
    SELECT postal_feature(feat)::integer
    FROM array_to_list($1) feat
  ))::postal_feature_sets
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION in_postal_feature_set(postal_features, postal_feature_sets)
RETURNS boolean AS $$
  SELECT in_bitset($1, $2)
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION postal_feature_set_text(postal_feature_sets) RETURNS text[] AS $$
  SELECT ARRAY(SELECT name FROM postal_address_features
  WHERE in_postal_feature_set(id, $1))
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION get_postal_feature_set(comm_via_ids)
RETURNS postal_feature_sets AS $$
  SELECT features FROM postal_addresses WHERE id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION set_postal_feature_set(comm_via_ids, postal_feature_sets)
RETURNS comm_via_ids AS $$
  UPDATE postal_addresses SET features = $2 WHERE id = $1;
  SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION flatten_addr_lines(text[]) RETURNS text[]AS $$
   SELECT ARRAY(
       SELECT foo FROM array_to_LIST($1) AS FOO 
       WHERE char_length(foo) > 0
   )
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION postal_address_text(comm_via_ids)
RETURNS text AS $$
  SELECT array_to_string(flatten_addr_lines(addr_lines), E'\n')
    || E'\n' || city || ', ' || state || E'\n'
    || country || ' ' || zip
  FROM postal_addresses WHERE id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION postal_address_html(comm_via_ids)
RETURNS text AS $$
  SELECT ( array_to_string(flatten_addr_lines(addr_lines), E'<br />\n')
    || E'<br />\n' || city || ', ' || state || E'<br />\n'
    || zip )
--    || country || ' ' || zip )
  FROM postal_addresses WHERE id = $1
$$ LANGUAGE sql STRICT;

-- Concept: Business Client

CREATE OR REPLACE
FUNCTION get_client_package(contact_ids) RETURNS deal_package_ids AS $$
  SELECT pkg_id FROM clients_packages
  WHERE client_id = $1 AND is_current(starting, ending)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION close_client_package(contact_ids) RETURNS contact_ids AS $$
  UPDATE clients_packages SET ending = event_time()
  WHERE client_id = $1 AND is_current(starting, ending);
  SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION set_client_package(contact_ids, deal_package_ids) RETURNS contact_ids AS $$
  SELECT close_client_package($1);
  INSERT INTO clients_packages(client_id, pkg_id, starting, ending)
    VALUES ($1, $2, time_range_start(), time_range_end());
  SELECT $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_client(contact_ids) RETURNS contact_ids AS $$
BEGIN
  BEGIN
    INSERT INTO client_keys(key) VALUES ($1);
  EXCEPTION
    WHEN unique_violation THEN
      RAISE NOTICE 'make_client(%): already a client',$1;
  END;
  RETURN $1;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION make_client(contact_ids,text) RETURNS contact_ids AS $$
BEGIN
  BEGIN
    INSERT INTO client_keys (key,ident) VALUES ($1,$2);
  EXCEPTION
    WHEN unique_violation THEN
      RAISE NOTICE 'make_client(%,%): already a client or duplicate ident',$1,$2;
  END;
  RETURN $1;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION make_client(contact_ids, deal_package_ids) RETURNS contact_ids AS $$
  SELECT make_client($1);
  SELECT set_client_package($1, $2);
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_client(contact_ids, text, deal_package_ids) RETURNS contact_ids AS $$
  SELECT make_client($1,$2);
  SELECT set_client_package($1, $3);
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_normal_client(contact_ids) RETURNS contact_ids AS $$
  SELECT make_client($1, base_price_pkg())
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_normal_client(contact_ids,text) RETURNS contact_ids AS $$
  SELECT make_client($1, $2, base_price_pkg())
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_normal_client(text) RETURNS contact_ids AS $$
  SELECT make_normal_client( contacts_id($1) )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_normal_client(text,text) RETURNS contact_ids AS $$
  SELECT make_normal_client( contacts_id($1),$2 )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION unmake_client(contact_ids) RETURNS contact_ids AS $$
BEGIN
  PERFORM close_client_package($1);
  DELETE FROM client_keys WHERE key = $1;
  IF NOT FOUND THEN
      RAISE NOTICE 'unmake_client(%): not a  client', $1;
  END IF;
  RETURN $1;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION is_client(contact_ids) RETURNS bool AS $$
  SELECT $1 IN (SELECT key FROM client_keys)
$$ LANGUAGE sql STRICT;

-- * finding contacts by contact_texts

CREATE OR REPLACE
FUNCTION ct_pair(contact_text_fields, text) RETURNS contact_text_pairs AS $$
  SELECT ROW($1, CASE WHEN $2 = '' THEN NULL ELSE $2 END)::contact_text_pairs
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION ct_pair(contact_text_fields, contact_text_pairs[]) RETURNS text AS $$
  SELECT (pair).val FROM array_to_list($2) pair WHERE (pair).field = $1 LIMIT 1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION contact_text(contact_text_pairs[]) RETURNS contact_texts AS $$
  SELECT ROW(
    ct_pair('ct_any_name', $1),
    ct_pair('ct_org_name', $1),
    ct_pair('ct_ind_name', $1),
    ct_pair('ct_family_name', $1),
    ct_pair('ct_phone', $1),
    ct_pair('ct_email', $1),
    ct_pair('ct_address', $1),
    ct_pair('ct_city', $1),
    ct_pair('ct_state', $1),
    ct_pair('ct_country', $1),
    ct_pair('ct_zip', $1)
  )::contact_texts
$$ LANGUAGE sql STRICT;

-- see biz-client-lookup.sql

-- Concept: create xml note with attribute
--   Attribute src is an individual contact id

CREATE OR REPLACE
FUNCTION make_note_xml(contact_ids,text) RETURNS XML AS $$
   SELECT ('<note src="'||$1||'">'||$2||'</note>')::xml
$$ LANGUAGE sql;

-- handles unknown (not allowed) or system inserted note
CREATE OR REPLACE
FUNCTION make_note_xml(text) RETURNS XML AS $$
   SELECT make_note_xml(0::contact_ids,$1)
$$ LANGUAGE sql;
