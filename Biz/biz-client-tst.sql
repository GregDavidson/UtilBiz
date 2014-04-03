-- biz_client_test.sql
-- $Id: biz_client_test.sql,v 1.1 2008/04/14 17:33:01 lynn Exp $
-- generic support for business clients
-- Lynn Dobbs and Greg Davidson
-- 25 March 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- This needs to eventually produce output only when
-- (1) debugging is turned on or
-- (2) results deviate from what is expected

-- Meta Functions

-- select regclass_to_name('note_makers');

--  regclass_to_name 
-- ------------------
--  note_makers
-- (1 row)

\set ECHO all

SELECT xml_text(name) FROM individual_contacts;

SELECT contact_text(contacts_by_subtext('g','Lynn'));

SELECT contact_text(contacts_by_attr('a','James'));

SELECT contact_text(individuals_by_givenname('Lynn'));

SELECT contact_text(individuals_by_givenname('John'));

SELECT contact_text(individuals_by_surname('Dobbs'));

SELECT contact_text(individuals_by_surname('Smith'));

SELECT contact_text(contacts_like('David'));

SELECT contact_text(contacts_like('creditlink'));

SELECT * FROM view_individuals;

SELECT * FROM view_orgs;

SELECT * FROM view_employees;

SELECT * FROM view_phone_vias;

SELECT * FROM view_email_vias;

SELECT * FROM view_postal_vias;

SELECT * FROM view_contact_vias;

-- Example of finding contact data from a search on contact name.

-- this gives a memory allocation error: !!
-- select * from individuals_by_surname('Smith') as contact_id 
--  left join view_contact_vias_ using (contact_id);

select * from individuals_by_surname('Smith') as x, view_contact_vias_ as v where x = v.contact_id;

SELECT contact_text(ARRAY[
  ct_pair('ct_org_name', 'ABC'),
  ct_pair('ct_ind_name', 'Lynn'),
  ct_pair('ct_family_name', 'Dobbs'),
  ct_pair('ct_phone', '858-496-1010')
]);

-- select debug_on('find_org_by_contact_texts(contact_texts)', true);
-- select debug_on('find_org_row_by_contact_texts(contact_texts)', true);
-- select debug_on('find_ind_by_contact_texts(contact_texts)', true);
-- select debug_on('find_ind_row_by_contact_texts(contact_texts)', true);

-- select debug_on('find_org_by_contact_texts(contact_texts)', false);
-- select debug_on('find_org_row_by_contact_texts(contact_texts)', false);
-- select debug_on('find_ind_by_contact_texts(contact_texts)', false);
-- select debug_on('find_ind_row_by_contact_texts(contact_texts)', false);

SELECT find_org_by_contact_texts(contact_text(ARRAY[
  ct_pair('ct_org_name', 'ABC'),
  ct_pair('ct_ind_name', 'Lynn'),
  ct_pair('ct_family_name', 'Dobbs'),
  ct_pair('ct_phone', '858-496-1010')
]));

SELECT match_contact_texts_do_de_di_so_se_si(
  contact_text(ARRAY[ct_pair('ct_phone', '858-496-1010')]),
  x, y, y, y, y, y
) FROM view_org_rows f(x), cast(null as entity_rows) y
WHERE (x).number = '858-496-1010';

SELECT match_contact_texts_do_de_di_so_se_si(
  contact_text(ARRAY[ct_pair('ct_phone', '858-496-1010')]),
  x, x, x, x, x, x
) FROM view_org_rows f(x), cast(null as entity_rows) y
WHERE (x).number = '858-496-1010';

SELECT match_contact_texts_do_de_di_so_se_si(
  contact_text(ARRAY[ct_pair('ct_phone', '858-496-1010')]),
  dom_org,  dom_emp,  dom_ind,
  sub_org,  sub_emp,  sub_ind
) FROM view_dom_sub_accts;

SELECT dom_org FROM view_dom_sub_accts
WHERE phone_matches(
  (dom_org).number,
  (dom_org).bare_number,
  '858-496-1010'
);

SELECT find_org_by_contact_texts(contact_text(ARRAY[
  ct_pair('ct_phone', '858-496-1010')
]));

SELECT find_org_row_by_contact_texts(contact_text(ARRAY[
  ct_pair('ct_phone', '858-496-1010')
]));

SELECT find_org_row_by_contact_texts(contact_text(ARRAY[
  ct_pair('ct_org_name', 'ABC'),
  ct_pair('ct_ind_name', 'Lynn'),
  ct_pair('ct_family_name', 'Dobbs'),
  ct_pair('ct_phone', '858-496-1004')
]));

SELECT find_ind_by_contact_texts(contact_text(ARRAY[
--  ct_pair('ct_org_name', 'ABC'),
  ct_pair('ct_ind_name', 'Lynn'),
  ct_pair('ct_family_name', 'Dobbs'),
  ct_pair('ct_phone', '858-496-1004')
]));

SELECT find_ind_row_by_contact_texts(contact_text(ARRAY[
--  ct_pair('ct_org_name', 'ABC'),
  ct_pair('ct_ind_name', 'Lynn'),
  ct_pair('ct_family_name', 'Dobbs'),
  ct_pair('ct_phone', '858-496-1004')
]));

-- SELECT * FROM view_all_orgs WHERE
--   phone_matches(number, bare_number, '858-496-1004');

SELECT find_org_row_by_contact_texts(contact_text(ARRAY[
    ct_pair('ct_phone', '858-496-1004')
]));

-- SELECT * FROM view_all_inds WHERE
--   phone_matches(number, bare_number, '858-496-1004');

SELECT find_ind_row_by_contact_texts(contact_text(ARRAY[
  ct_pair('ct_phone', '858-496-1004')
]));

-- SELECT * FROM view_all_inds WHERE
--   street_matches(addr_lines, 'Chesapeake');

SELECT find_ind_row_by_contact_texts(contact_text(ARRAY[
  ct_pair('ct_address', 'Suite 112')
]));

create or replace function rowmaker() returns record as $$
  select row('lynn','dobbs');
$$ language sql;
