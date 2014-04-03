-- biz_services_code.sql
-- $Id: biz_services_code.sql,v 1.4 2008/04/30 17:17:05 lynn Exp $
-- generic support for business services
-- Lynn Dobbs and Greg Davidson
-- Sun Apr 13 15:48:53 PDT 2008

-- ** Copyright

--	Copyright (c) 2005 -2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- Concept: Business Services

CREATE OR REPLACE
FUNCTION make_service(text) RETURNS service_ids AS $$
DECLARE
  the_id maybe_service_ids;
BEGIN
  BEGIN
    INSERT INTO services(service_name) VALUES ($1) RETURNING id INTO the_id;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE NOTICE 'make_service(%): already exists', $1;
      SELECT INTO the_id id FROM services WHERE service_name = $1;
  END;
  RETURN the_id::service_ids;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION service_text(service_ids) RETURNS text AS $$
  SELECT service_name FROM services WHERE id = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION services_id(text) RETURNS service_ids AS $$
DECLARE
  the_id maybe_service_ids;
BEGIN
  SELECT INTO the_id id FROM services WHERE service_name = $1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'services_id(%): no such service', $1;
  END IF;
  RETURN the_id::service_ids;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION service_description(service_ids) RETURNS text AS $$
  SELECT COALESCE(
    ( SELECT xml_text(description) FROM service_descriptions
      WHERE service_id = $1 AND starting < event_time() AND
      (event_time() < ending OR ending IS NULL) ),
    service_text($1)
  )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION new_service_description(service_ids, event_times, xml) RETURNS service_ids AS $$
BEGIN
  BEGIN
    INSERT INTO service_descriptions(service_id, starting, ending, description)
      VALUES ($1, time_range_start($2), time_range_end(), $3);
    EXCEPTION WHEN unique_violation THEN
      RAISE NOTICE 'new_service_description(%, %, %): already exists', $1, $2, $3;
      UPDATE service_descriptions
        SET ending = $2 - 1 -- the day before the new description goes into effect
        WHERE service_id = $1 AND starting != $2::date AND ending IS NULL;
  END;
  RETURN $1;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION make_service(text, xml) RETURNS service_ids AS $$
  SELECT new_service_description(make_service($1), event_time(), $2)
$$ LANGUAGE sql STRICT;

--	Concept: Business Services

--
-- Functions that deal with client authorizations
--

CREATE OR REPLACE
FUNCTION add_client_auth(contact_ids,service_ids) RETURNS void AS $$
BEGIN
 INSERT INTO client_authorizations (client_id,allowed_services)
   VALUES ($1,to_bitset($2));
EXCEPTION
  WHEN unique_violation THEN
  UPDATE client_authorizations 
  	 SET allowed_services=allowed_services | to_bitset($2)
  	 WHERE client_id=$1;
END
$$ LANGUAGE plpgsql STRICT;

-- Should we remove the tuple when no allowed services are left???
CREATE OR REPLACE
FUNCTION delete_client_auth(contact_ids,service_ids) RETURNS void AS $$
  UPDATE client_authorizations 
  	 SET allowed_services=bitset_drop(allowed_services, $2)
  	 WHERE client_id=$1
$$ LANGUAGE sql STRICT;

-- client_has_subacct(client_id, subacct_id) --> boolean
CREATE OR REPLACE
FUNCTION client_has_subacct(contact_ids,contact_ids) RETURNS bool AS $$
  SELECT $2 IN (SELECT subacct_id FROM client_subaccounts WHERE client_id=$1)
$$ LANGUAGE sql STRICT;

-- client_allowed(client, service)
-- where client is NOT an employee!
CREATE OR REPLACE
FUNCTION client_allowed(contact_ids,service_ids) RETURNS bool AS $$
  SELECT in_bitset($2 ,allowed_services)
  FROM client_authorizations WHERE client_id=$1
$$ LANGUAGE sql STRICT;

-- client_allowed(client,subacct,service)
-- where client is NOT an employee!
CREATE OR REPLACE
FUNCTION client_allowed(contact_ids,contact_ids,service_ids) RETURNS bool AS $$
BEGIN
  IF NOT client_has_subacct($1, $2) THEN
    RAISE EXCEPTION 'client_allowed: % not subacct of %', $2, $1;
  END IF;
  RETURN client_allowed($1, $3);
END
$$ LANGUAGE plpgsql STRICT;

--
-- Functions that deal with employee permissions.
--

-- Create, Edit, and Delete permissions.

-- add_employee_auth(employee_id, service_id)
CREATE OR REPLACE
FUNCTION add_employee_auth(contact_ids,service_ids) RETURNS void AS $$
DECLARE
  employer maybe_contact_ids;
BEGIN
  SELECT INTO employer works_for FROM employee_contacts WHERE id = $1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'add_emplyee_auth: % not employee', $1;
  END IF;
  IF NOT is_client(employer) THEN
    RAISE EXCEPTION 'add_employee_auth: not client %', employer;
  END IF;
  IF NOT client_allowed(employer, $2) THEN
    RAISE EXCEPTION 'add_employee_auth: employer % not allowed %', employer, $2;
  END IF;
  INSERT INTO employee_authorizations (empcon_id, allowed_services)
    VALUES ($1, to_bitset($2));
EXCEPTION
  WHEN unique_violation THEN
  UPDATE employee_authorizations 
  	 SET allowed_services=allowed_services | to_bitset($2)
  	 WHERE empcon_id=$1;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION delete_employee_auth(contact_ids,service_ids) RETURNS void AS $$
  UPDATE employee_authorizations 
  	 SET allowed_services=bitset_drop(allowed_services, $2)
  	 WHERE empcon_id=$1
$$ LANGUAGE sql STRICT;

-- add_employee_auth(staffed_by, subacct_id,service_id)
CREATE OR REPLACE
FUNCTION add_employee_auth(contact_ids,contact_ids,service_ids) RETURNS void AS $$
DECLARE
  employer contact_ids;
BEGIN
  SELECT INTO employer works_for FROM employee_contacts WHERE staffed_by = $1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'add_emplyee_auth: %1 not employee';
  END IF;
  IF NOT is_client(employer) THEN
    RAISE EXCEPTION 'add_employee_auth: not client %', employer;
  END IF;
  IF NOT client_allowed(employer, $2) THEN
    RAISE EXCEPTION 'add_employee_auth: employer % not allowed %', employer, $2;
  END IF;
  INSERT INTO employee_subaccount_authorizations
    (client_id, empcon_id, subacct_id, allowed_services) VALUES (employer, $1, $2, to_bitset($3));
EXCEPTION
  WHEN unique_violation THEN
  UPDATE employee_subaccount_authorizations 
  	 SET allowed_services=allowed_services | to_bitset($3)
  	 WHERE empcon_id=$1 AND subacct_id = $2;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION delete_employee_auth(contact_ids,contact_ids,service_ids) RETURNS void AS $$
  UPDATE employee_subaccount_authorizations 
  	 SET allowed_services=bitset_drop(allowed_services, $3)
  	 WHERE empcon_id=$1 AND subacct_id = $2
$$ LANGUAGE sql STRICT;

-- employee_allowed_(employee,subacct,service)
CREATE OR REPLACE
FUNCTION employee_allowed_(contact_ids,contact_ids,service_ids) RETURNS bool AS $$
  select in_bitset($3, allowed_services)
  from employee_subaccount_authorizations where empcon_id = $1 and subacct_id = $2
$$ LANGUAGE sql STRICT;

-- employee_allowed_(employee,service)
CREATE OR REPLACE
FUNCTION employee_allowed_(contact_ids,service_ids) RETURNS bool AS $$
  select in_bitset($2, allowed_services)
  from employee_authorizations where empcon_id = $1
$$ LANGUAGE sql STRICT;

-- employee_allowed(employee,subacct,service)
-- a specific employee; an subacct which might be NULL; and a service
CREATE OR REPLACE
FUNCTION employee_allowed(contact_ids,contact_ids,service_ids) RETURNS bool AS $$
  SELECT CASE
    WHEN NOT client_allowed(works_for, $3) THEN false
    WHEN employee_allowed_($1, $3) THEN true
    ELSE $2 IS NOT NULL AND client_has_subacct(works_for, $2) AND employee_allowed_($1, $2, $3)
  END
  FROM employee_contacts WHERE staffed_by = $1
$$ LANGUAGE sql;

-- contact_allowed(client,service); client possibly an employee
CREATE OR REPLACE
FUNCTION contact_allowed(contact_ids,service_ids) RETURNS bool AS $$
  SELECT CASE
    WHEN is_employee($1) THEN employee_allowed($1, NULL, $2)
    ELSE client_allowed($1, $2)
  END
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION contact_allowed(contact_ids,service_ids) IS
'contact_allowed(client or employee,service) checks if the given
client or employee has permission to receive the given service';

-- contact_allowed(client,subacct,service); client possibly an employee
CREATE OR REPLACE
FUNCTION contact_allowed(contact_ids,contact_ids,service_ids) RETURNS bool AS $$
  SELECT CASE
    WHEN is_employee($1) THEN employee_allowed($1, $2, $2)
    ELSE client_allowed($1, $2, $3)
  END
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION contact_allowed(contact_ids,contact_ids,service_ids) IS
'contact_allowed(client or employee,subacct,service) checks if the given
client or employee has permission to receive the given service associated with
the given subaccount';

-- list all auths
CREATE OR REPLACE
FUNCTION list_client_auths(contact_ids) RETURNS SETOF service_stati AS $$
 SELECT ROW(id,client_allowed($1,id))::service_stati FROM services
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION list_employee_auths(contact_ids) RETURNS SETOF service_stati AS $$
 SELECT ROW(id,employee_allowed_($1,id))::service_stati FROM services
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION list_employee_auths(contact_ids,contact_ids) RETURNS SETOF service_stati AS $$
 SELECT ROW(id,employee_allowed_($1,$2,id))::service_stati FROM services
$$ LANGUAGE sql STRICT;

-- CREATE OR REPLACE
-- VIEW view_client_auths AS
-- SELECT s.service_id, ca.client_id, client_allowed(ca.client_id, s.service_id)
-- FROM services s
-- LEFT JOIN client_authorizations ca ON

CREATE OR REPLACE
FUNCTION make_service_request_(
  service_ids,
  contact_ids,
  maybe_contact_ids
) RETURNS service_request_ids AS $$
DECLARE
  the_id maybe_service_ids;
BEGIN
  INSERT INTO service_requests(service_id,customer_id, subacct_id, request_time)
  VALUES ( $1, $2, $3, event_time() ) RETURNING id INTO the_id;
  RETURN the_id;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION make_service_request(service_ids, contact_ids, contact_ids)
RETURNS service_request_ids AS $$
  SELECT make_service_request_($1, $2, $3)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_service_request(service_ids, contact_ids)
RETURNS service_request_ids AS $$
  SELECT make_service_request_($1, $2, NULL)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION make_service_request(text, contact_ids)
RETURNS service_request_ids AS $$
  SELECT make_service_request_(services_id($1), $2, NULL)
$$ LANGUAGE sql STRICT;
