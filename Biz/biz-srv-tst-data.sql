-- biz_services_test_data.sql
-- $Id: biz_services_test_data.sql,v 1.2 2008/04/18 02:05:48 lynn Exp $
-- generic support for business services
-- Lynn Dobbs and Greg Davidson
-- 25 March 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

SELECT make_service('Profile', 'Provide a credit check, fico score and bad check report');

SELECT make_service('Background Check');

-- SELECT make_deal( 'affiliate profile price',
--        line_item('credit report'),
--        new_price_deal('1295') );
-- -- add to affiliate package !!!

-- SELECT make_deal( 'affiliate assist price',
--        line_item('Agent Assist'),
--        new_price_deal('1595') );
-- -- add to affiliate package !!!

-- SELECT make_deal( '10% solution',
--        line_item('credit report'),
--        percent_price_deal('10') );

-- SELECT make_deal( 'finance charge',
--        line_item('Fin Chrg'),
--        percent_price_deal('5') );

-- SELECT price_a_deal( deal_from_text('affiliate profile price'), '9999');

-- SELECT price_a_deal( deal_from_text('10% solution'), '100');

-- SELECT make_client_deal(
-- 	individual_contacts_id('lbd'),
-- 	deal_from_text('affiliate profile price'),
-- 	event_time());

-- SELECT make_client_deal(
-- 	individual_contacts_id('lbd'),
-- 	deal_from_text('10% solution'),
-- 	event_time());

-- SELECT best_deal(
-- 	individual_contacts_id('lbd'),
-- 	line_item('credit report'),
-- 	event_time(),
-- 	'1395');

-- SELECT best_deal(
-- 	individual_contacts_id('lbd'),
-- 	line_item('credit report'),
-- 	event_time(),
-- 	'1495'
-- );

-- SELECT base_price( line_item('credit report'), event_time() );

-- SELECT best_price(
-- 	individual_contacts_id('lbd'),
-- 	line_item('credit report'),
-- 	event_time()
-- );

-- SELECT set_service_requests_row(
--   'cl_crdchk',
--   make_service_request(
--     services_id('Profile'), org_contacts_id('creditlink'),
--     individual_contacts_id('lbd'), NULL)
-- );
