-- biz_client_lookup.sql
-- $Id$
-- generic support for business clients;
-- views and functions for client lookup
-- Lynn Dobbs and Greg Davidson
-- Monday 15 December 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.


CREATE OR REPLACE
FUNCTION entity_row(
  contact_kinds, contact_ids, xml,
  text, numeric, text,
  text[], city_names, state_codes, country_codes, postal_codes
) RETURNS entity_rows AS $$
  SELECT ROW($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)::entity_rows
$$ LANGUAGE sql;

CREATE OR REPLACE
VIEW 	view_phone_contacts AS
SELECT 	via.contact_id AS id, phone.number, phone.bare_number
FROM 	phone_numbers phone, contact_comm_vias via
WHERE 	phone.id = via.comm_via_id;

CREATE OR REPLACE
VIEW 	view_email_contacts AS
SELECT 	via.contact_id AS id, email.email
FROM 	email_addresses email, contact_comm_vias via
WHERE 	email.id = via.comm_via_id;

CREATE OR REPLACE
VIEW 	view_postal_contacts AS
SELECT 	via.contact_id AS id, postal.addr_lines,
	postal.city, postal.state, postal.country, postal.zip
FROM 	postal_addresses postal, contact_comm_vias via
WHERE 	postal.id = via.comm_via_id;

CREATE OR REPLACE
VIEW view_org_rows_(
  id, name, number, bare_number, email,
  addr_lines, city, state, country, zip
) AS
SELECT org.id, org.name,
  phone.number, phone.bare_number, email.email,
  postal.addr_lines, postal.city, postal.state, postal.country, postal.zip
FROM org_contacts org
LEFT JOIN view_phone_contacts phone USING(id)
LEFT JOIN view_email_contacts email USING(id)
LEFT JOIN view_postal_contacts postal USING(id);

CREATE OR REPLACE
VIEW view_org_rows AS
SELECT entity_row(
  'ckind_org'::contact_kinds,
  id, name, number, bare_number,
  email, addr_lines, city, state, country, zip
) AS org_row
FROM view_org_rows_;

CREATE OR REPLACE
VIEW view_ind_rows_(
  id, name, number, bare_number,
  email, addr_lines, city, state, country, zip
) AS
SELECT ind.id, ind.name,
  phone.number, phone.bare_number, email.email,
  postal.addr_lines, postal.city, postal.state, postal.country, postal.zip
FROM individual_contacts ind
LEFT JOIN view_phone_contacts phone USING(id)
LEFT JOIN view_email_contacts email USING(id)
LEFT JOIN view_postal_contacts postal USING(id);

CREATE OR REPLACE
VIEW view_ind_rows AS
SELECT entity_row(
  'ckind_ind'::contact_kinds,
  id, name, number, bare_number,
  email, addr_lines, city, state, country, zip
) AS ind_row
FROM view_ind_rows_;

CREATE OR REPLACE
VIEW view_emp_rows_(
  id, name, number, bare_number, email,
  addr_lines, city, state, country, zip,
  works_for, staffed_by
) AS
SELECT emp.id, emp.name,
  phone.number, phone.bare_number, email.email,
  postal.addr_lines, postal.city, postal.state, postal.country, postal.zip,
  emp.works_for, emp.staffed_by
FROM employee_contacts emp
LEFT JOIN view_phone_contacts phone USING(id)
LEFT JOIN view_email_contacts email USING(id)
LEFT JOIN view_postal_contacts postal USING(id);

CREATE OR REPLACE
VIEW view_emp_rows AS
SELECT entity_row(
  'ckind_emp'::contact_kinds,
  id, name, number, bare_number, email,
  addr_lines, city, state, country, zip
) AS emp_row, works_for, staffed_by
FROM view_emp_rows_;

CREATE OR REPLACE
VIEW view_orgs_emps_inds_ AS
SELECT org_row, emp_row, ind_row
FROM view_org_rows, view_emp_rows, view_ind_rows
WHERE works_for = (org_row).id AND staffed_by = (ind_row).id;

CREATE OR REPLACE
VIEW view_orgs_emps_inds(org_row, emp_row, ind_row) AS
  SELECT org_row, NULL::entity_rows, NULL::entity_rows
  FROM view_org_rows
UNION ALL
  SELECT NULL::entity_rows, NULL::entity_rows, ind_row
  FROM view_ind_rows
UNION ALL
  SELECT org_row, emp_row, ind_row
  FROM view_orgs_emps_inds_;

CREATE OR REPLACE
VIEW view_dom_sub_accts_ AS
SELECT
  dom.org_row AS dom_org,
  dom.emp_row AS dom_emp,
  dom.ind_row AS dom_ind,
  sub.org_row AS sub_org,
  sub.emp_row AS sub_emp,
  sub.ind_row AS sub_ind
FROM
  view_orgs_emps_inds dom,
  view_orgs_emps_inds sub,
  client_subaccounts sub_dom
WHERE
  sub_dom.client_id = (dom.org_row).id AND
  sub_dom.subacct_id = (sub.org_row).id;

CREATE OR REPLACE
VIEW view_dom_sub_accts AS
  SELECT
    org_row AS dom_org,
    emp_row AS dom_emp,
    ind_row AS dom_ind,
    NULL::entity_rows AS sub_org,
    NULL::entity_rows AS sub_emp,
    NULL::entity_rows AS sub_ind
  FROM view_orgs_emps_inds
UNION ALL
  SELECT dom_org, dom_emp, dom_ind,
	 sub_org, sub_emp, sub_ind
  FROM view_dom_sub_accts_;

-- Further exploration of this wonderful space
-- is left for those with need or passion!

CREATE OR REPLACE
FUNCTION match_contact_texts_do_de_di_so_se_si(
  contact_texts,
  entity_rows, entity_rows, entity_rows,
  entity_rows, entity_rows, entity_rows
) RETURNS boolean AS $$
SELECT CASE WHEN ($1).any_name IS NULL THEN true
   ELSE	COALESCE(name_matches(($2).name, ($1).any_name), false)
     OR	COALESCE(name_matches(($3).name, ($1).any_name), false)
     OR	COALESCE(name_matches(($4).name, ($1).any_name), false)
     OR	COALESCE(name_matches(($5).name, ($1).any_name), false)
     OR	COALESCE(name_matches(($6).name, ($1).any_name), false)
     OR	COALESCE(name_matches(($7).name, ($1).any_name), false)
END AND CASE WHEN ($1).org_name IS NULL THEN true
   ELSE	COALESCE(name_matches(($2).name, ($1).org_name), false)
     OR	COALESCE(name_matches(($5).name, ($1).org_name), false)
END AND CASE WHEN ($1).ind_name IS NULL THEN true
   ELSE	COALESCE(name_matches(($4).name, ($1).ind_name), false)
     OR	COALESCE(name_matches(($7).name, ($1).ind_name), false)
END AND CASE WHEN ($1).family_name IS NULL THEN true
   ELSE	COALESCE(name_matches(family_name(($4).name),(($1).family_name)), false)
     OR	COALESCE(name_matches(family_name(($7).name),(($1).family_name)), false)
END AND CASE WHEN ($1).phone IS NULL THEN true
   ELSE	COALESCE(phone_matches(($2).number, ($2).bare_number, ($1).phone), false)
     OR	COALESCE(phone_matches(($3).number, ($3).bare_number, ($1).phone), false)
     OR	COALESCE(phone_matches(($4).number, ($4).bare_number, ($1).phone), false)
     OR	COALESCE(phone_matches(($5).number, ($5).bare_number, ($1).phone), false)
     OR	COALESCE(phone_matches(($6).number, ($6).bare_number, ($1).phone), false)
     OR	COALESCE(phone_matches(($7).number, ($7).bare_number, ($1).phone), false)
END AND CASE WHEN ($1).email IS NULL THEN true
   ELSE	COALESCE(email_matches(($2).email, ($1).email), false)
     OR	COALESCE(email_matches(($3).email, ($1).email), false)
     OR	COALESCE(email_matches(($4).email, ($1).email), false)
     OR	COALESCE(email_matches(($5).email, ($1).email), false)
     OR	COALESCE(email_matches(($6).email, ($1).email), false)
     OR	COALESCE(email_matches(($7).email, ($1).email), false)
END AND CASE WHEN ($1).address IS NULL THEN true
   ELSE	COALESCE(street_matches(($2).addr_lines, ($1).address), false)
     OR	COALESCE(street_matches(($3).addr_lines, ($1).address), false)
     OR	COALESCE(street_matches(($4).addr_lines, ($1).address), false)
     OR	COALESCE(street_matches(($5).addr_lines, ($1).address), false)
     OR	COALESCE(street_matches(($6).addr_lines, ($1).address), false)
     OR	COALESCE(street_matches(($7).addr_lines, ($1).address), false)
END AND CASE WHEN ($1).city IS NULL THEN true
   ELSE	COALESCE(city_matches(($2).city, ($1).city), false)
     OR	COALESCE(city_matches(($3).city, ($1).city), false)
     OR	COALESCE(city_matches(($4).city, ($1).city), false)
     OR	COALESCE(city_matches(($5).city, ($1).city), false)
     OR	COALESCE(city_matches(($6).city, ($1).city), false)
     OR	COALESCE(city_matches(($7).city, ($1).city), false)
END AND CASE WHEN ($1).state IS NULL THEN true
   ELSE	COALESCE(state_matches(($2).state, ($1).state), false)
     OR	COALESCE(state_matches(($3).state, ($1).state), false)
     OR	COALESCE(state_matches(($4).state, ($1).state), false)
     OR	COALESCE(state_matches(($5).state, ($1).state), false)
     OR	COALESCE(state_matches(($6).state, ($1).state), false)
     OR	COALESCE(state_matches(($7).state, ($1).state), false)
END AND CASE WHEN ($1).country IS NULL THEN true
   ELSE	COALESCE(country_matches(($2).country, ($1).country), false)
     OR	COALESCE(country_matches(($3).country, ($1).country), false)
     OR	COALESCE(country_matches(($4).country, ($1).country), false)
     OR	COALESCE(country_matches(($5).country, ($1).country), false)
     OR	COALESCE(country_matches(($6).country, ($1).country), false)
     OR	COALESCE(country_matches(($7).country, ($1).country), false)
END AND CASE WHEN ($1).zip IS NULL THEN true
   ELSE	COALESCE(zip_matches(($2).zip, ($1).zip), false)
     OR	COALESCE(zip_matches(($3).zip, ($1).zip), false)
     OR	COALESCE(zip_matches(($4).zip, ($1).zip), false)
     OR	COALESCE(zip_matches(($5).zip, ($1).zip), false)
     OR	COALESCE(zip_matches(($6).zip, ($1).zip), false)
     OR	COALESCE(zip_matches(($7).zip, ($1).zip), false)
END
$$ LANGUAGE sql;

-- ** find organizations

CREATE OR REPLACE
FUNCTION find_org_by_contact_texts(contact_texts)
RETURNS SETOF contact_ids AS $$
  SELECT DISTINCT (dom_org).id FROM view_dom_sub_accts,
    debug_enter('find_org_by_contact_texts(contact_texts)', 'contact_text', $1)
  WHERE
    match_contact_texts_do_de_di_so_se_si(
      $1, dom_org, dom_emp, dom_ind, sub_org, sub_emp, sub_ind
    )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_org_row_by_contact_texts(contact_texts)
RETURNS SETOF entity_rows AS $$
  SELECT (dom_org).*
  FROM
    view_dom_sub_accts,
    debug_enter(
      'find_org_row_by_contact_texts(contact_texts)',
      'contact_text',
      $1
    )
  WHERE
    match_contact_texts_do_de_di_so_se_si(
      $1, dom_org, dom_emp, dom_ind, sub_org, sub_emp, sub_ind
    )
$$ LANGUAGE sql STRICT;

-- ** find organizations

-- does this cover all the bases?
CREATE OR REPLACE
FUNCTION find_ind_by_contact_texts(contact_texts)
RETURNS SETOF contact_ids AS $$
  SELECT DISTINCT (dom_ind).id FROM view_dom_sub_accts
  WHERE
    match_contact_texts_do_de_di_so_se_si(
      $1, dom_org, dom_emp, dom_ind, sub_org, sub_emp, sub_ind
    )
UNION ALL
  SELECT DISTINCT (sub_ind).id FROM view_dom_sub_accts
  WHERE
    match_contact_texts_do_de_di_so_se_si(
      $1, sub_org, sub_emp, sub_ind, dom_org, dom_emp, dom_ind
    )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_ind_row_by_contact_texts(contact_texts)
RETURNS SETOF entity_rows AS $$
  SELECT (dom_ind).* FROM view_dom_sub_accts
  WHERE
    match_contact_texts_do_de_di_so_se_si(
      $1, dom_org, dom_emp, dom_ind, sub_org, sub_emp, sub_ind
    )
UNION ALL
  SELECT (sub_ind).* FROM view_dom_sub_accts
  WHERE
    match_contact_texts_do_de_di_so_se_si(
      $1, sub_org, sub_emp, sub_ind, dom_org, dom_emp, dom_ind
    )
$$ LANGUAGE sql STRICT;

-- ** find employees?

-- ** find sub-accounts?

-- ** find clients

CREATE OR REPLACE
FUNCTION find_client_by_contact_texts(contact_texts) RETURNS SETOF contact_ids AS $$
  SELECT x FROM 
     find_org_by_contact_texts($1) x 
     WHERE is_client(x)
  UNION
  SELECT x FROM 
     find_ind_by_contact_texts($1) x 
     WHERE is_client(x)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_clients_by_contact_texts(contact_texts)
RETURNS contact_id_arrays AS $$
  SELECT ARRAY(
    SELECT DISTINCT x::integer FROM find_client_by_contact_texts($1) x
  )::contact_id_arrays
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_ind_or_org_by_contact_texts(contact_texts)
RETURNS SETOF contact_ids AS $$
  SELECT x FROM 
     find_org_by_contact_texts($1) x 
  UNION
  SELECT x FROM 
     find_ind_by_contact_texts($1) x 
$$ LANGUAGE sql STRICT;

-- Walk up the tree looking for a client given any contact_id
-- for a given contact_id, this function returns ONE row.
-- This will fail when there are multiple clients for a given
-- contact.
-- This will fail disastrously if there is a cycle in the database.
-- So rewrite this someday using arrays and iteration!!
CREATE OR REPLACE
FUNCTION find_client_id(contact_ids) RETURNS contact_ids AS $$
  SELECT COALESCE(
         ( SELECT key FROM client_keys WHERE key = $1 ),
         find_client_id( (
           SELECT client_id as id FROM client_subaccounts WHERE subacct_id = $1
         ) ),
         ( SELECT find_client_id(works_for) FROM employee_contacts WHERE id = $1 ),
         0
  )::contact_ids
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION get_client_by_contact_texts__(contact_texts) RETURNS SETOF contact_ids AS $$
  SELECT DISTINCT find_client_id(x) FROM find_ind_or_org_by_contact_texts($1) x
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION get_client_by_contact_texts_(contact_texts) RETURNS SETOF contact_ids AS $$
  SELECT x FROM get_client_by_contact_texts__($1) x WHERE x != 0
$$ LANGUAGE sql STRICT;

-- later we might want this to return do_de_di_so_se_si rows
-- so that we can set the defaults on the client form
CREATE OR REPLACE
FUNCTION get_clients_by_contact_texts(contact_texts) RETURNS contact_id_arrays AS $$
  SELECT ARRAY(
    SELECT DISTINCT get_client_by_contact_texts_($1)::integer
  )::contact_id_arrays
$$ LANGUAGE sql STRICT;

