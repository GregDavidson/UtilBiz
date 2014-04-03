-- biz_client_test_data.sql
-- $Id: biz_client_test_data.sql,v 1.3 2008/05/12 16:07:10 lynn Exp $
-- generic support for business clients
-- Lynn Dobbs and Greg Davidson
-- 25 March 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- individual contacts
-- with and without internal handles (row names)
-- with and without contact vias

SELECT make_individual_contact('<g>Jean Paul</g> <f>Gaultier</f> de Sade');

SELECT set_individual_contacts_row(
  'lbd',
  make_individual_contact('<g>Lynn</g> B. <f>Dobbs</f>')
);

SELECT make_contact_comm_via(individual_contacts_id('lbd'),
   set_phone_feature_set(make_phone('858-496-1004'), phone_feature_set(array['Voice'])),
   comm_feature_set(array['Work']));

SELECT make_contact_comm_via(individual_contacts_id('lbd'),
   set_email_feature_set(make_email('lynn@creditlink.com'),email_feature_set(array['authenticated'])),
   comm_feature_set(array['Work']));

SELECT make_contact_comm_via(
	individual_contacts_id('lbd'),
	set_postal_feature_set(make_postal(array['9320 Chesapeake Dr','Suite 112'],
	   'San Diego', 'CA','USA','92123'), postal_feature_set(array['Primary'])),
	comm_feature_set(array['Work']));

SELECT set_individual_contacts_row(
  'lynn',
  make_individual_contact('<g>Lynn</g> Bruce <f>Dobbs</f>')
);

SELECT make_contact_comm_via(individual_contacts_id('lynn'),
   set_phone_feature_set(make_phone('858-761-1648'), phone_feature_set(array['Cell'])),
   comm_feature_set(array['Home']));

SELECT make_contact_comm_via(individual_contacts_id('lynn'),
   set_email_feature_set(make_email('lynn@bethechange.net'),email_feature_set(array['authenticated'])),
   comm_feature_set(array['Home']));

SELECT make_contact_comm_via(
	individual_contacts_id('lynn'),
	set_postal_feature_set(make_postal(array['11171 Alejo Place',''],
	   'San Diego', 'CA','USA','92124'),postal_feature_set(array['Special'])),
	comm_feature_set(array['Home']));

SELECT set_individual_contacts_row(
  'sfm',
  make_individual_contact('<g>Stacey</g> F. <f>Moffitt</f>')
);

SELECT make_contact_comm_via(
	individual_contacts_id('sfm'),
	set_phone_feature_set(make_phone('858-999-3333'), phone_feature_set(array['Voice']))) ;

SELECT make_individual_contact('<g a="James">J.</g> <n>Greg</n> <f>Davidson</f>');
SELECT make_individual_contact('<g>David</g> <f>Moffitt</f>');

SELECT make_contact_comm_via(
	make_individual_contact('<g>John</g> <f>Smith</f>'),
	set_phone_feature_set(make_phone('760 123-4567'), phone_feature_set(array['Voice'])) );

SELECT make_individual_contact('<g>Johann</g> Sebastian <f>Smith</f>');

SELECT make_contact_comm_via(
	make_individual_contact('<g>John</g> <f>Smith</f>'),
	set_phone_feature_set(make_phone('619 321-9876'), phone_feature_set(array['Data'])) );

-- organizational contacts
	
SELECT make_org_contact('<x a="IBM">International Business Machines Corporation</x>');

SELECT set_org_contacts_row(
  'creditlink',
  make_org_contact('<n>CreditLink</n> Corporation')
);

SELECT make_contact_comm_via(
	org_contacts_id('creditlink'),
	set_phone_feature_set(make_phone('858-496-1010'), phone_feature_set(array['Voice'])) );

-- city_names, state_codes, country_codes, postal_codes
SELECT make_contact_comm_via(
	org_contacts_id('creditlink'),
	set_postal_feature_set(make_postal(array['9320 Chesapeake Dr','Suite 112'],
	   'San Diego', 'CA','USA','92123'), postal_feature_set(array['Billing'])));

SELECT set_org_contacts_row(
  'a_g',
  make_org_contact('Allied Gardens')
);

SELECT make_contact_comm_via(
	org_contacts_id('a_g'),
	set_phone_feature_set(make_phone('858-222-3333'), phone_feature_set(array['FAX'])) );

SELECT set_org_contacts_row(
       'ABC',
       make_org_contact('ABC Management')
);

SELECT make_contact_comm_via(
	org_contacts_id('ABC'),
	set_phone_feature_set(make_phone('858-222-3333'), phone_feature_set(array['FAX']))) ;

SELECT make_contact_comm_via(
	org_contacts_id('ABC'),
	set_postal_feature_set(make_postal(array['123 Market Street','Suite 1'],
	   'Enterprise Town', 'CA','USA','92123'), postal_feature_set(array['Primary'])));

SELECT make_contact_comm_via(
	org_contacts_id('ABC'),
	set_phone_feature_set(make_phone('888-222-1234'), phone_feature_set(array['Voice'])) );

-- making contacts into a client

SELECT make_normal_client(org_contacts_id('ABC'),'#ABC');

SELECT make_normal_client(org_contacts_id('creditlink'),'#1');

SELECT make_normal_client(individual_contacts_id('sfm'),'#sfm');

-- employees

SELECT set_employee_contacts_row(
  'chief_cook',
  make_employee('Chief Cook and Bottle Washer',
       org_contacts_id('ABC'),
       individual_contacts_id('lbd'))
);
SELECT make_contact_comm_via(
	employee_contacts_id('chief_cook'),
	set_phone_feature_set(make_phone('619.555.7777'), phone_feature_set(array['Voice'])),
	comm_feature_set(array['Work']));

SELECT make_contact_comm_via(
	employee_contacts_id('chief_cook'),
	set_phone_feature_set(make_phone('619.555.8888'), phone_feature_set(array['FAX'])),
	comm_feature_set(array['Work']));

SELECT set_employee_contacts_row(
  'lynn',
  make_employee('CTO',
       org_contacts_id('creditlink'),
       individual_contacts_id('lynn'))
);
INSERT INTO note_authors VALUES (employee_contacts_id('lynn'));
SELECT set_note_authors_row('lynn',employee_contacts_id('lynn'));

SELECT add_employee_contacts_note(
              make_attributed_note('lbd', make_note_xml(
	                     individual_contacts_id('lbd'),
  			     'CreditLink God')), 
	      employee_contacts_id('lbd')
);

SELECT set_employee_contacts_row(
  'boss',
  make_employee('CEO',
       org_contacts_id('creditlink'),
       (set_individual_contacts_row('david',
             make_individual_contact('<g>David</g> <f>Moffitt</f>'))).id)
);
INSERT INTO note_authors VALUES (employee_contacts_id('boss'));
SELECT set_note_authors_row('boss',employee_contacts_id('boss'));

SELECT set_employee_contacts_row(
  'nobody',
  make_employee('Resident Manager',
       org_contacts_id('ABC'),
       (set_individual_contacts_row('mary',
             make_individual_contact('<g>Mary</g> <f>Tillotson</f>'))).id)
);

SELECT make_contact_comm_via(
	employee_contacts_id('nobody'),
	set_phone_feature_set(make_phone('619.123.9876'), phone_feature_set(array['Cell'])),
	comm_feature_set(array['Work']));


-- subaccount

 SELECT make_subacct( org_contacts_id('ABC'), org_contacts_id('a_g') );

 SELECT make_subacct( org_contacts_id('ABC'),
   get_subacct_category( org_contacts_id('ABC'), 'Fresno')
 );

SELECT make_contact_comm_via(
	-1,			-- Fresno
	set_postal_feature_set(make_postal(array['621 Market St','Ste 12'],
	   'Fresno', 'CA','USA','90111'), postal_feature_set(array['Primary'])),
	comm_feature_set(array['Work']));

 SELECT make_subacct( org_contacts_id('ABC'),
   get_subacct_category( org_contacts_id('ABC'), 'Merced')
 ); 

SELECT make_contact_comm_via(
	-2,			-- Merced
	set_postal_feature_set(make_postal(array['885 Main St',''],
	   'Merced', 'CA','USA','90001'), postal_feature_set(array['Primary'])),
	comm_feature_set(array['Work']));

SELECT make_contact_comm_via(
	org_contacts_id('a_g'),
	set_postal_feature_set(make_postal(array['123 Hot Ave',''],
	   'San Diego', 'CA','USA','92111'), postal_feature_set(array['Primary'])),
	comm_feature_set(array['Work']));

SELECT make_contact_comm_via(
	org_contacts_id('a_g'),
	set_phone_feature_set(make_phone('619.555.1214'), phone_feature_set(array['Voice'])),
	comm_feature_set(array['Work']));

-- all all notes AFTER text orgs, clients, employees, and subaccounts are set up
-- make a note-author of each creditlink employee

-- this set deals with client ABC Management
SELECT add_individual_contacts_note(
            make_attributed_note('lynn', 
	    	make_note_xml(individual_contacts_id('nobody'),
		'Best Girl!')), 
            individual_contacts_id('sfm'));

SELECT add_individual_contacts_note(
             make_attributed_note('lynn', 
 	           make_note_xml(employee_contacts_id('chief_cook'),
                                 'smart feller!')), 
             individual_contacts_id('lbd')
);

SELECT add_org_contacts_note(
            make_attributed_note('lynn', 
 	        make_note_xml(employee_contacts_id('chief_cook'),
 		  'A BIG client')), 
            org_contacts_id('ABC')
);

SELECT add_employee_contacts_note(
             make_attributed_note('boss', 
	     		make_note_xml(employee_contacts_id('chief_cook'),
			'A chief cook note')), 
  	     employee_contacts_id('chief_cook')
);

SELECT add_employee_contacts_note(
             make_attributed_note('boss', 
	     		make_note_xml(employee_contacts_id('nobody'),
			'A chief cook note')), 
  	     employee_contacts_id('chief_cook')
);

SELECT add_employee_contacts_note(
              make_attributed_note('lynn', 
	                 make_note_xml(employee_contacts_id('boss'),
			 'Accountant')), 
	      employee_contacts_id('nobody')
);

 SELECT add_client_subaccounts_note(
 		make_attributed_note('lynn', 
		       make_note_xml(0::contact_ids,
 		       'This is a test note')),
		org_contacts_id('ABC'), 
		org_contacts_id('a_g')
 ); 

SELECT add_client_subaccounts_note(
 		make_attributed_note('boss',
		    make_note_xml(0::contact_ids,
		    'This is a Fresno test note')),
		org_contacts_id('ABC'), 
		-1 
 ); 

SELECT add_client_subaccounts_note(
 		make_attributed_note('boss',
		     make_note_xml(0::contact_ids,
 		     'This is a Merced test note')),
		org_contacts_id('ABC'),  
		-2
 ); 

-- This set is about creditlink

SELECT add_org_contacts_note(
            make_attributed_note('lynn', 
 	        make_note_xml(employee_contacts_id('lynn'),
 		  'Our Company')), 
            org_contacts_id('creditlink')
);

SELECT add_org_contacts_note(
            make_attributed_note('lynn', 
 	        make_note_xml(employee_contacts_id('boss'),
 		  'Bread and Butter')), 
            org_contacts_id('creditlink')
);

SELECT add_employee_contacts_note(
             make_attributed_note('boss', 
	     		make_note_xml(employee_contacts_id('chief_cook'),
			'A chief cook note')), 
  	     employee_contacts_id('chief_cook')
);


