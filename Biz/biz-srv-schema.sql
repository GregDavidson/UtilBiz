-- biz_services_schema.sql
-- $Id: biz_services_schema.sql,v 1.4 2008/04/30 17:17:04 lynn Exp $
-- realizing Business::Services classes
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

-- This part of the schema should reflect the needs
-- of business logic.

-- Realizes:

--	Concept: Business Services
--	Concept: Business Deals
--	Concept: Client Permissions

-- Note:
--	Use the historical-mapping pattern to be sure that
--	the Deals are correlated with when they were available!


-- Concept Business Service or Product

CREATE DOMAIN service_ids AS integer NOT NULL;
CREATE DOMAIN maybe_service_ids AS integer;

CREATE SEQUENCE service_id_seq;

CREATE OR REPLACE
FUNCTION next_service_id() RETURNS service_ids AS $$
  SELECT nextval('service_id_seq')::service_ids
$$ LANGUAGE sql;

CREATE TABLE services (
  id service_ids PRIMARY KEY DEFAULT next_service_id(),
  service_name TEXT UNIQUE NOT NULL
);

ALTER SEQUENCE service_id_seq OWNED BY services.id;

SELECT notes_for('services');
SELECT handles_for('services');

CREATE TABLE service_descriptions (
  service_id service_ids NOT NULL REFERENCES services,
  starting date NOT NULL,
  ending date,
  UNIQUE(service_id, starting),
  description XML NOT NULL
);
COMMENT ON TABLE service_descriptions IS
'describes what this service promises at a particular time';

-- Concept Business Deal

-- A deal pricing structure for services

CREATE TYPE explained_price AS (
  deal_id maybe_deal_ids,	-- NULL means a base price
  price us_pennies
);

CREATE TABLE client_deals (
  client_id contact_ids NOT NULL,
  deal_id deal_ids NOT NULL,
  starting date NOT NULL,
  PRIMARY KEY(client_id, deal_id, starting),
  ending date
);


-- Concept: Business Permissions
--    Permissions are really services that are permitted

-- Concept: Business Authorizations
-- Concept: Business Permissions
--    Permissions are really services that are permitted

CREATE DOMAIN service_sets AS bitsets;

CREATE TABLE client_authorizations (
       client_id contact_ids PRIMARY KEY REFERENCES client_keys,
       allowed_services service_sets DEFAULT empty_bitset()
);
COMMENT ON TABLE client_authorizations IS 
'One tuple for each authorization a credentialed client has.
 As of this writing, there are only two authorization kinds.';

CREATE TABLE employee_authorizations (
       empcon_id contact_ids PRIMARY KEY REFERENCES employee_contacts,
       allowed_services service_sets DEFAULT empty_bitset()
);
COMMENT ON TABLE employee_authorizations IS 
'Permissions an employee has independent of subaccount.';
COMMENT ON COLUMN employee_authorizations.empcon_id IS 
'We can get the credentialed client and the employee from the employee_id';       
COMMENT ON COLUMN employee_authorizations.allowed_services IS 
'Bitset of services limited by the credentialed client authorizations';

CREATE TABLE employee_subaccount_authorizations (
       client_id contact_ids REFERENCES org_contacts,
       empcon_id contact_ids REFERENCES individual_contacts,
       subacct_id contact_ids,
       PRIMARY KEY(empcon_id,subacct_id),
       FOREIGN KEY (client_id, subacct_id)
       REFERENCES client_subaccounts(client_id, subacct_id),
       -- FOREIGN KEY (client_id, empcon_id)
       -- REFERENCES employee_contacts(works_for, staffed_by),
       allowed_services service_sets DEFAULT empty_bitset()
);
COMMENT ON TABLE employee_subaccount_authorizations IS 
'One tuple for each subaccount on which the employee has
 permissions.';
COMMENT ON COLUMN employee_subaccount_authorizations.empcon_id IS 
'We can get the credentialed client and the employee from the employee_id';       
COMMENT ON COLUMN employee_subaccount_authorizations.subacct_id IS 
'Either the employee''s employer or one of that employer''s  "subaccounts"
 - our code needs to check this';
COMMENT ON COLUMN employee_subaccount_authorizations.allowed_services IS 
'Bitset of services limited by the credentialed client authorizations';

-- Service Status

CREATE TYPE service_stati AS (
  service_id service_ids,status bool
);

CREATE DOMAIN service_request_ids AS integer NOT NULL;
-- CREATE DOMAIN maybe_service_request_ids AS integer;

CREATE SEQUENCE request_id_seq;

CREATE OR REPLACE
FUNCTION next_request_id() RETURNS service_request_ids AS $$
  SELECT nextval('request_id_seq')::service_request_ids
$$ LANGUAGE sql;

CREATE TABLE service_requests (
  id service_request_ids PRIMARY KEY DEFAULT next_request_id(),
  service_id service_ids REFERENCES services,
  customer_id contact_ids,
  subacct_id maybe_contact_ids,
  request_time event_times DEFAULT event_time()
);
COMMENT ON TABLE service_requests IS
'All requests (for products or adminstration issues).
 Referenced by service_request_actions';
COMMENT ON COLUMN service_requests.customer_id IS
'Either a client or an employee';

SELECT handles_for('service_requests');
