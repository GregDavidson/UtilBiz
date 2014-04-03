-- biz_client_schema.sql
-- $Id: biz_client_schema.sql,v 1.4 2008/05/12 16:07:10 lynn Exp $
-- generic support for business clients
-- Lynn Dobbs and Greg Davidson
-- 25 March 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- Include this file at most once!

-- Remarkably convenient in form for the needs
-- of CreditLink, yet innocently pure
-- and free from explicit business logic.

-- Some of our find functions do fuzzy matching of names,
-- addresses, etc.  We will want to build appropriate
-- full-text indexes in this schema to support full-text
-- search.  Currently, we're just using ILIKE.

-- Concept: Business Contacts

-- A contact_id might represent a real contact or
-- a group/division/account/subaccount/etc. of a real contact.
-- Call them sub_contacts and represent them by negative ids.

CREATE DOMAIN contact_ids AS integer NOT NULL;
CREATE DOMAIN maybe_contact_ids AS integer;
CREATE DOMAIN contact_id_arrays AS integer[];

CREATE SEQUENCE contact_id_seq;

CREATE SEQUENCE sub_contact_id_seq START -1 INCREMENT -1;

CREATE OR REPLACE
FUNCTION next_contact_id() RETURNS contact_ids AS $$
  SELECT nextval('contact_id_seq')::contact_ids
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION next_sub_contact_id() RETURNS contact_ids AS $$
  SELECT nextval('sub_contact_id_seq')::contact_ids
$$ LANGUAGE sql;

CREATE TABLE abstract_contacts (
  id contact_ids PRIMARY KEY DEFAULT next_contact_id(),
  name XML NOT NULL
-- add a soundx-like field later!!
);
COMMENT ON TABLE abstract_contacts IS
'what is in common between persons and organizations
from the viewpoint of a business-to-business relationship;
aka generic contact; but also might just represent a
person or an organization in a business role - later we
might want to separate these concepts';
COMMENT ON COLUMN abstract_contacts.name IS
'the name of a person or organization or the name of an employee''s
position.  Now XML so we can''t have indexes on it.  If often
searching on name components, creating one or more link tables with
indexes may be appropriate - a trigger could analyze the name and
create external links as appropriate';

ALTER SEQUENCE contact_id_seq OWNED BY abstract_contacts.id;

ALTER SEQUENCE sub_contact_id_seq OWNED BY abstract_contacts.id;

CREATE TABLE contact_keys (
  id contact_ids,
  -- if id's are unique and all tables derive from one base:
  PRIMARY KEY(id)
  -- otherwise:
--  tableid regclass
--  PRIMARY KEY(id, tableid)
);
COMMENT ON TABLE contact_keys IS
'used to maintain referential integrity when referencing
a tuple of any table inheriting from abstract_contacts';

CREATE OR REPLACE
FUNCTION new_contact_trigger() RETURNS trigger AS $$
BEGIN
  RAISE NOTICE 'new_contact_trigger: TG_OP=%, NEW.id=%, NEW.tableoid=%',
    TG_OP, NEW.id, NEW.tableoid;
  IF TG_OP = 'INSERT' THEN
--    INSERT INTO contact_keys(id, tableid) VALUES (NEW.id, NEW.tableoid);
    INSERT INTO contact_keys(id) VALUES (NEW.id);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
--    DELETE FROM contact_keys WHERE id = OLD.id AND tableid = OLD.tableoid;
    DELETE FROM contact_keys WHERE id = OLD.id;
  ELSE
    NULL;			-- check if OP is valid??
  END IF;
END
$$ LANGUAGE plpgsql;

-- Concept: Individual Contact

CREATE TABLE individual_contacts (
  PRIMARY KEY(id)
--  FOREIGN KEY (id, tableoid) REFERENCES contact_keys(id, tableid) INITIALLY DEFERRED
) INHERITS (abstract_contacts);
COMMENT ON TABLE individual_contacts IS
'a business contact who is an individual person';

CREATE TRIGGER individual_contact_trigger
       BEFORE INSERT ON individual_contacts
       FOR EACH ROW EXECUTE PROCEDURE new_contact_trigger();

SELECT notes_for('individual_contacts');
SELECT handles_for('individual_contacts');

-- Concept: Organization Contact

CREATE TABLE org_contacts (
  PRIMARY KEY(id)
) INHERITS (abstract_contacts);
COMMENT ON TABLE org_contacts IS
'a business contact which is an organization';

CREATE TRIGGER org_contact_trigger
       BEFORE INSERT ON org_contacts
       FOR EACH ROW EXECUTE PROCEDURE new_contact_trigger();

SELECT notes_for('org_contacts');
SELECT handles_for('org_contacts');

-- Concept: Business Client

-- A client is a contact who has one or more accounts with us

CREATE TABLE client_keys (
  key contact_ids PRIMARY KEY REFERENCES contact_keys,
  ident TEXT UNIQUE
);
COMMENT ON TABLE client_keys IS
'clients are contacts who have accounts with us;
is this a permanent condition??';
COMMENT ON COLUMN client_keys.ident IS
'Useful for handles, account codes, etc.  Likely to appear
outside of the database, e.g. on bills.';

CREATE TABLE clients_packages (
  client_id contact_ids REFERENCES contact_keys,
  pkg_id deal_package_ids REFERENCES deal_packages
) INHERITS (time_ranges);
COMMENT ON TABLE clients_packages IS
'Associates clients with deal packages with history.';
COMMENT ON COLUMN clients_packages.client_id IS
'References contact_keys instead of client_keys to preserve
history in case a contact is no longer a client.';

-- Concept: Business Client Account

-- A business client account is an id against which
-- we charge for services.

-- CREATE DOMAIN account_ids AS integer NOT NULL;
-- CREATE DOMAIN maybe_account_ids AS integer;

-- CREATE SEQUENCE account_id_seq;

-- CREATE OR REPLACE
-- FUNCTION next_account_id() RETURNS account_ids AS $$
--   SELECT nextval('account_id_seq')::account_ids
-- $$ LANGUAGE sql;

-- CREATE TABLE client_accounts (
--   id account_ids PRIMARY KEY DEFAULT next_account_id(),
--   owner_id contact_ids NOT NULL REFERENCES client_keys,
--   name text NOT NULL,
--   UNIQUE(owner_id, name),
--   starting date NOT NULL DEFAULT event_time()::date,
--   ending date
-- );
-- COMMENT ON TABLE client_accounts IS 
-- 'Relates one of our clients to one of the organizational entities
-- they manage or serve, e.g. one of their properties, stores, etc.
-- These relationships are used to limit employee access to services
-- involving these entities and to create sub accounts for the accounting system.';
-- COMMENT ON COLUMN client_accounts.name IS
-- 'Name assigned by business client for the sub account';

-- ALTER SEQUENCE account_id_seq OWNED BY client_accounts.id;

-- Concept: Employee Contact

CREATE TABLE employee_contacts (
  PRIMARY KEY(id),
--  works_for contact_ids NOT NULL REFERENCES contact_keys,
  works_for contact_ids NOT NULL REFERENCES client_keys,
  staffed_by contact_ids REFERENCES individual_contacts,
  UNIQUE(works_for, staffed_by)
--  UNIQUE(name, works_for, staffed_by)  (name is xml oops.)
) INHERITS (abstract_contacts, time_ranges);
COMMENT ON TABLE employee_contacts IS
'an employee or representative for an organization';
COMMENT ON COLUMN employee_contacts.name IS
'the name of the position this employee holds';

CREATE TRIGGER employee_contact_trigger
       BEFORE INSERT ON employee_contacts
       FOR EACH ROW EXECUTE PROCEDURE new_contact_trigger();

SELECT notes_for('employee_contacts');
SELECT handles_for('employee_contacts');

-- Concept: A Client's Sub-Account

-- we may want to have a way to distinguish
-- -- client organization's divisions
-- -- a client's own accounts with other individuals or organizations
-- -- a client's own categories
-- which they want us to track
-- -- as categories on our bills to them
-- -- authorizations vis-a-vis their employees

-- solutions
-- -- (1) client categories are simply names unique to them
-- -- (2) client categories are a kind of contact
-- -- -- we can give them names, contact via's
-- -- -- they might show up associated with our other clients
-- -- -- they might show up as clients of ours in their own right
-- -- (3) they could be id numbers which
-- -- -- if negative are merely categories as in (1)
-- -- -- if positive are business contacts in (2)
-- Let's say we use solution (3) - we can pretend we've used solution
-- (1) if we just extract the name from the id and ignore the rest.

-- When the sub_account is just a category name,
-- it must be one of the following:

CREATE TABLE sub_account_contacts (
  PRIMARY KEY(id),
  CONSTRAINT sub_account_contacts_id CHECK(id < 0)
) INHERITS (abstract_contacts);
COMMENT ON TABLE sub_account_contacts IS
'a category meaningful to one of our business clients which
 we need to know for accounting, billing or communication purposes';

CREATE TRIGGER sub_account_contact_trigger
       BEFORE INSERT ON sub_account_contacts
       FOR EACH ROW EXECUTE PROCEDURE new_contact_trigger();

SELECT notes_for('sub_account_contacts');
SELECT handles_for('sub_account_contacts');

-- Clients and their subaccounts must be linked using the following table:

CREATE TYPE subaccount_keys AS (
  client_id contact_ids,
  subacct_id contact_ids
);

CREATE TABLE client_subaccounts (
  client_id contact_ids NOT NULL REFERENCES org_contacts,
  subacct_id contact_ids NOT NULL REFERENCES contact_keys,
  PRIMARY KEY(client_id, subacct_id)
) INHERITS (time_ranges);

COMMENT ON TABLE client_subaccounts IS
'represents a subaccount of one of our client''s';
COMMENT ON COLUMN client_subaccounts.subacct_id IS
'if negative, just a category of that client''s - use the name;
 if positive, this is also a legitimate contact id in our database
 but here it represents that entity via this client of ours';
COMMENT ON COLUMN client_subaccounts.client_id IS
'our client whose subaccount this is';

SELECT notes_for('client_subaccounts');
SELECT handles_for('client_subaccounts');

-- Concept: Contact Communication Vias

CREATE DOMAIN comm_via_ids AS integer NOT NULL;
CREATE DOMAIN maybe_comm_via_ids AS integer;

CREATE SEQUENCE comm_via_id_seq;

CREATE OR REPLACE
FUNCTION next_comm_via_id() RETURNS comm_via_ids AS $$
  SELECT nextval('comm_via_id_seq')::comm_via_ids
$$ LANGUAGE sql;

CREATE TABLE abstract_comm_vias (
  id comm_via_ids PRIMARY KEY DEFAULT next_comm_via_id()
);
COMMENT ON TABLE abstract_comm_vias IS
'the generic notion of a way to contact a business client';

ALTER SEQUENCE comm_via_id_seq OWNED BY abstract_comm_vias.id;

CREATE DOMAIN comm_features AS integer;
CREATE DOMAIN comm_feature_sets AS bitsets;

CREATE TABLE comm_via_features (
  id comm_features PRIMARY KEY,
  name text
);
COMMENT ON TABLE comm_via_features IS
'Comm_Via features table (static at runtime)';

INSERT INTO comm_via_features (id,name) VALUES
(0, 'Allowed'), (1, 'Home'), (2, 'Secure'), (3, 'Work'), (4, 'Preferred');

-- NOT USED
-- CREATE TYPE contact_comm_via_keys AS (
--   contact_id contact_ids,
--   comm_via_id comm_via_ids
-- );

CREATE DOMAIN contact_comm_via_ids AS integer NOT NULL;
CREATE DOMAIN maybe_contact_comm_via_ids AS integer;
CREATE DOMAIN contact_comm_via_ids_arrays AS integer[];

CREATE SEQUENCE contact_comm_via_id_seq;

CREATE OR REPLACE
FUNCTION next_contact_comm_via_id() RETURNS contact_comm_via_ids AS $$
  SELECT nextval('contact_comm_via_id_seq')::contact_comm_via_ids
$$ LANGUAGE sql;

CREATE TABLE abstract_contact_comm_vias (
  id contact_comm_via_ids PRIMARY KEY 
     DEFAULT next_contact_comm_via_id()
);

ALTER SEQUENCE contact_comm_via_id_seq 
      OWNED BY abstract_contact_comm_vias.id;

CREATE TABLE contact_comm_vias (
  contact_id contact_ids,
  comm_via_id comm_via_ids,
  features comm_feature_sets DEFAULT empty_bitset(),
  PRIMARY KEY (id),
  UNIQUE (contact_id, comm_via_id)
) INHERITS (abstract_contact_comm_vias,time_ranges);

CREATE INDEX conact_comm_vias_contact_idx 
  ON contact_comm_vias(contact_id);

SELECT notes_for('contact_comm_vias');
SELECT handles_for('contact_comm_vias');

COMMENT ON TABLE contact_comm_vias IS
'links business clients with ways to contact them - many to many';

-- Concept: Telephone Number

CREATE DOMAIN phone_features AS integer NOT NULL;
CREATE DOMAIN phone_feature_sets AS bitsets;

CREATE TABLE phone_number_features (
  id phone_features PRIMARY KEY,
  name text
);
COMMENT ON TABLE phone_number_features IS
'Phone features table (static at runtime)';

INSERT INTO phone_number_features (id,name) values
(0, 'Data'), (1, 'FAX'), (2, 'Cell'), (3, 'Voice'),
-- add any new codes here
-- Work and Preferred are not to be used directly
-- they are mirrors of the comm_via_features with the same names
(4,'Work'), (5,'Preferred');

CREATE TABLE phone_numbers (
  PRIMARY KEY(id),
  number text UNIQUE NOT NULL,
  bare_number numeric UNIQUE NOT NULL,
  features phone_feature_sets DEFAULT empty_bitset()
) INHERITS(abstract_comm_vias);
COMMENT ON COLUMN phone_numbers.number IS
'a human-friendly representation of the phone number';
COMMENT ON COLUMN phone_numbers.bare_number IS
'a canonical representation - just the digits';
-- why can't we pull bare_number out of number???

SELECT notes_for('phone_numbers');
SELECT handles_for('phone_numbers');

-- Concept: Email Address

CREATE DOMAIN email_features AS integer NOT NULL;
CREATE DOMAIN email_feature_sets AS bitsets;

CREATE TABLE email_address_features (
  id email_features PRIMARY KEY,
  name text
);
COMMENT ON TABLE email_address_features IS
'Email features table (static at runtime)';

INSERT INTO email_address_features (id,name) values
(0,'encrypted'), (1,'authenticated'),
-- add any new codes here
-- Work and Preferred are not to be used directly
-- they are mirrors of the comm_via_features with the same names
(2,'Work'), (3,'Preferred');

CREATE TABLE email_addresses (
  PRIMARY KEY(id),
  email TEXT UNIQUE NOT NULL,
  features email_feature_sets DEFAULT empty_bitset()
) INHERITS(abstract_comm_vias);
COMMENT ON COLUMN email_addresses.email IS
'strip out any non-canonical parts';

SELECT notes_for('email_addresses');
SELECT handles_for('email_addresses');

-- Concept: Postal Addresses

CREATE DOMAIN postal_features AS integer NOT NULL;
CREATE DOMAIN postal_feature_sets AS bitsets;

CREATE TABLE postal_address_features (
  id postal_features PRIMARY KEY,
  name text
);

-- the special feature can be used for any given purpose
--   as needed by the business logic.  i.e. an address
--   that has been certified as the primary business site
INSERT INTO postal_address_features (id,name) VALUES
(0,'Special'), (1,'Billing'), (2,'Primary'),
-- add any new codes here
-- Work and Preferred are not to be used directly
-- they are mirrors of the comm_via_features with the same names
(3,'Work'), (4,'Preferred');

CREATE DOMAIN city_names AS text NOT NULL;
CREATE DOMAIN state_codes AS text NOT NULL;
CREATE DOMAIN country_codes AS text NOT NULL;
CREATE DOMAIN postal_codes AS text NOT NULL;

CREATE TABLE postal_addresses (
  PRIMARY KEY(id),
  addr_lines text[],
  city city_names,
  state state_codes,
  country country_codes DEFAULT 'USA',
  zip postal_codes,
  features postal_feature_sets DEFAULT empty_bitset()
) INHERITS (abstract_comm_vias);

SELECT notes_for('postal_addresses');
SELECT handles_for('postal_addresses');

-- Concept: Business Client

-- A Business Client is just a viewpoint on a Business Contact
-- who at some point in time has deals and possibly transactions.

-- There could be a default set of deals which Business Contacts
-- with whom we have no specific deals can use to do business
-- with us.

-- Concept: Flexible Search

CREATE TYPE contact_kinds AS ENUM (
  'ckind_any',			-- abstract_contacts
  'ckind_org',			-- org_contacts
  'ckind_ind',		-- individual_contacts
  'ckind_emp',			-- employee_contacts
  'ckind_subacct',		-- sub_account_contacts
  'ckind_client'		-- client_contacts (in client_keys)
);

CREATE TYPE entity_rows AS (
  kind contact_kinds,
  id contact_ids,
  name xml,
  number text,
  bare_number numeric,
  email text,
  addr_lines text[],
  city city_names,
  state state_codes,
  country country_codes,
  zip postal_codes
);

CREATE TYPE contact_text_fields AS ENUM (
  'ct_any_name',
  'ct_org_name',
  'ct_ind_name',
  'ct_family_name',
  'ct_phone',
  'ct_email',
  'ct_address',
  'ct_city',
  'ct_state',
  'ct_country',
  'ct_zip'
);

CREATE TYPE contact_text_pairs AS (
  field contact_text_fields,
  val text
);

-- still needed or wanted???
CREATE DOMAIN maybe_hits AS integer;

CREATE TYPE contact_texts AS (
      any_name text,
      org_name text,
      ind_name text,
      family_name text,
      phone text,
      email text,
      address text,
      city text,
      state text,
      country text,
      zip text
-- ,
--   name_hits maybe_hits,
--   phone_hits maybe_hits,
--   email_hits maybe_hits,
--   addr_hits maybe_hits
);
COMMENT ON TYPE contact_texts IS
'Diverse criteria from which we might start
a search for a client or other contact.
CASE *_hits
WHEN NULL means no search done
WHEN >=0 means that many hits
WHEN <0 means that many hits AND something
inconsistent';

