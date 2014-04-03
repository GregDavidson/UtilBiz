-- biz_client_views.sql
-- $Id: biz_client_views.sql,v 1.1 2008/11/12 23:42:50 lynn Exp lynn $
-- generic support for business clients
-- Lynn Dobbs and Greg Davidson
-- 25 March 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

CREATE OR REPLACE
VIEW view_individuals_ AS
  SELECT
    c.id, ch.handle AS handle, c.name,
	attributed_notes_text(individual_contacts_notes_array(c.id)) AS notes
  FROM individual_contacts c
  LEFT JOIN individual_contacts_row_handles ch USING(id);

CREATE OR REPLACE
VIEW view_individuals AS
SELECT COALESCE(v.handle, v.id::text) AS id, v.name, v.notes
FROM view_individuals_ v;

CREATE OR REPLACE
VIEW view_orgs_ AS
  SELECT
    c.id, ch.handle AS handle, c.name,
    attributed_notes_text(org_contacts_notes_array(c.id)) AS notes
  FROM org_contacts c
  LEFT JOIN org_contacts_row_handles ch USING(id);

CREATE OR REPLACE
VIEW view_orgs AS
SELECT COALESCE(v.handle, v.id::text) AS id, v.name, v.notes
FROM view_orgs_ v;

CREATE OR REPLACE
VIEW view_employees__ AS
  SELECT
    c.id, COALESCE(ic.handle, ic.id::text) AS employee_id,
    ic.name as employee_name, ic.notes as employee_notes,
    COALESCE(oc.handle, oc.id::text) AS employer_id, oc.name as employer_name,
    c.name AS position_name,
    attributed_notes_text(employee_contacts_notes_array(c.id)) AS notes
  FROM
    employee_contacts c,
    view_individuals_ ic, view_orgs_ oc
    WHERE  c.works_for=oc.id AND c.staffed_by=ic.id;

CREATE OR REPLACE
VIEW view_employees_ AS
  SELECT
    ch.handle AS handle, cc.*
  FROM 
       view_employees__ cc 
  LEFT JOIN employee_contacts_row_handles ch USING(id);

CREATE OR REPLACE
VIEW view_employees AS
SELECT
    COALESCE(v.handle, v.id::text) AS handle,
    v.employee_id,
    v.employee_name,
    v.employer_id,
    v.employer_name,
    v.position_name,
    (v.notes || v.employee_notes) AS notes
  FROM view_employees_ v;

CREATE OR REPLACE
VIEW view_subaccts__ AS
  SELECT
    s.client_id,
    vo.handle AS client_handle,
    vo.name AS client_name,
    ac.id AS subacct_id, ac.name AS subacct_name
  FROM client_subaccounts s,
       view_orgs_ vo,
       abstract_contacts ac
  WHERE s.client_id = vo.id AND s.subacct_id = ac.id;

CREATE OR REPLACE
VIEW view_subaccts_ AS
  SELECT
    h.handle AS handle, vs.*,
    attributed_notes_text(client_subaccounts_notes_array(client_id,subacct_id))
    AS notes
  FROM view_subaccts__ vs
  LEFT JOIN client_subaccounts_row_handles h USING(client_id, subacct_id);

CREATE OR REPLACE
VIEW view_subaccts AS
  SELECT client_handle, client_name, subacct_name, notes
  FROM view_subaccts_;

CREATE OR REPLACE
VIEW view_contacts AS
    SELECT id, handle, 'individual' AS type, xml_text(name) AS name
    FROM view_individuals_
  UNION
    SELECT id, handle, 'organization' AS type, xml_text(name) AS name
    FROM view_orgs_
  UNION
    SELECT id, handle, 'employee' AS type,
      xml_text(employee_name) || ' as ' || xml_text(position_name)
      || ' for ' || xml_text(employer_name) AS name
    FROM view_employees_;

-- phone views 

CREATE OR REPLACE
VIEW view_phones AS
SELECT id, number, bare_number,
  array_to_string(phone_feature_set_text(features), ', ') AS features
  FROM phone_numbers;

CREATE OR REPLACE
VIEW view_phone_vias__ AS
SELECT
  v.id AS ccvid,
  v.contact_id,
  array_to_string(comm_feature_set_text(v.features), ', ') AS contact_features,
  c.handle AS contact_handle, c.type AS contact_type, c.name AS contact_name,
  p.*
  FROM view_contacts c, view_phones p, contact_comm_vias v
WHERE v.contact_id = c.id AND v.comm_via_id = p.id;


CREATE OR REPLACE
VIEW view_phone_vias_ AS
SELECT h.handle AS via_handle, v.*,
  attributed_notes_text(phone_numbers_notes_array(v.id)) AS notes
  FROM view_phone_vias__ v
LEFT JOIN contact_comm_vias_row_handles h
  ON(v.ccvid = h.id);


CREATE OR REPLACE
VIEW view_phone_vias AS
SELECT via_handle,
  COALESCE(contact_handle, contact_id::text) AS contact_handle,
  contact_name, id AS phone_id, number,
  str_comma(contact_features, features) AS features
  FROM view_phone_vias_;

-- email views

CREATE OR REPLACE
VIEW view_emails AS
SELECT id, email,
  array_to_string(email_feature_set_text(features), ', ') AS features
  FROM email_addresses;

CREATE OR REPLACE
VIEW view_email_vias__ AS
SELECT
  v.id AS ccvid,
  v.contact_id,
  array_to_string(comm_feature_set_text(v.features), ', ') AS contact_features,
  c.handle AS contact_handle, c.type AS contact_type, c.name AS contact_name,
  e.*
  FROM view_contacts c, view_emails e, contact_comm_vias v
WHERE v.contact_id = c.id AND v.comm_via_id = e.id;

CREATE OR REPLACE
VIEW view_email_vias_ AS
SELECT h.handle AS via_handle, v.*,
  attributed_notes_text(email_addresses_notes_array(v.id)) AS notes
  FROM view_email_vias__ v
LEFT JOIN contact_comm_vias_row_handles h
  ON(v.ccvid = h.id);

CREATE OR REPLACE
VIEW view_email_vias AS
SELECT via_handle,
  COALESCE(contact_handle, contact_id::text) AS contact_handle,
  contact_name, id AS email_id, email,
  str_comma(contact_features, features) AS features
  FROM view_email_vias_;

-- postal views

CREATE OR REPLACE
VIEW view_postals AS
SELECT id, postal_address_text(id) AS address,
  array_to_string(postal_feature_set_text(features), ', ') AS features
  FROM postal_addresses;

CREATE OR REPLACE
VIEW view_postal_vias__ AS
SELECT
  v.id AS ccvid,
  v.contact_id,
  array_to_string(comm_feature_set_text(v.features), ', ') AS contact_features,
  c.handle AS contact_handle, c.type AS contact_type, c.name AS contact_name,
  p.*
  FROM view_contacts c, view_postals p, contact_comm_vias v
WHERE v.contact_id = c.id AND v.comm_via_id = p.id;

CREATE OR REPLACE
VIEW view_postal_vias_ AS
SELECT h.handle AS via_handle, v.*,
  attributed_notes_text(postal_addresses_notes_array(v.id)) AS notes
  FROM view_postal_vias__ v
LEFT JOIN contact_comm_vias_row_handles h
  ON(v.ccvid = h.id);

CREATE OR REPLACE
VIEW view_postal_vias AS
SELECT via_handle,
  COALESCE(contact_handle, contact_id::text) AS contact_handle,
  contact_name, id AS postal_id, address,
  str_comma(contact_features, features) AS features
  FROM view_postal_vias_;

-- combined via views

CREATE OR REPLACE
VIEW view_contact_vias_ AS
SELECT via_handle, contact_id, contact_features, contact_handle,
  contact_type, contact_name, id, 
  'phone' as via_type, number AS via,
  features, notes
FROM view_phone_vias_
  UNION
SELECT via_handle, contact_id, contact_features, contact_handle,
  contact_type, contact_name, id,
  'email' as via_type, email AS via,
  features, notes
FROM view_email_vias_
  UNION
SELECT via_handle, contact_id, contact_features, contact_handle,
  contact_type, contact_name, id,
  'postal' as via_type, address AS via,
  features, notes
FROM view_postal_vias_;

CREATE OR REPLACE
VIEW view_contact_vias AS
SELECT contact_handle, contact_name,
  'phone' as type, phone_id AS via_id, number AS via, features
FROM view_phone_vias
  UNION
SELECT contact_handle, contact_name,
  'email' as type, email_id AS via_id, email AS via, features
FROM view_email_vias
  UNION
SELECT contact_handle, contact_name,
  'postal' as type, postal_id AS via_id, address AS via, features
FROM view_postal_vias;

CREATE OR REPLACE
VIEW contact_vias_with_employer AS 
SELECT v.*,e.works_for FROM view_contact_vias_ v
LEFT JOIN employee_contacts e ON e.staffed_by=v.contact_id;

CREATE OR REPLACE
 VIEW contact_vias_with_subaccounts AS 
SELECT v.*,c.client_id from view_contact_vias_ v
LEFT JOIN client_subaccounts c ON c.client_id=v.contact_id;
