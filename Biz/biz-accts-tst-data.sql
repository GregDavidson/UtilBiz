-- biz_accounting_test_data.sql
-- $Id: biz_accounting_test_data.sql,v 1.1 2008/04/18 02:05:47 lynn Exp $
-- Lynn Dobbs and Greg Davidson

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- SELECT make_service_request_action(
--   (set_service_requests_row(
--     'lbd_profile_request',		   -- handle for later tests
--     make_service_request('Profile', Lynn) -- service named 'Profile'
--   )).id,
--   (set_service_actions_row(
--     'lbd_profile_action',		 -- handle for later tests
--     make_service_action(Lynn, 'Profile') -- line_item named 'Profile'
--   )).id
-- ) FROM individual_contacts_id('lbd') Lynn;

SELECT make_service_request_action(
  make_service_request('Profile', Stacey),
  make_service_action_tree(
    make_service_action(Stacey, 'Profile'),
    ARRAY[
      make_service_action(Stacey, 'Agent Assist')::integer,
      make_service_action(Stacey, 'CO SurCharge')::integer
    ]::service_action_id_arrays
  )
) FROM individual_contacts_id('sfm') Stacey;

-- SELECT make_service_request_action(
--   make_service_request( 'Profile', Lynn ),
--   make_service_action_tree(
--     make_service_action(Lynn, 'Profile'),
--     ARRAY[
--       make_service_action_special(
-- 	make_service_action(Lynn, 'Fin Chrg'),
-- 	35, 'dey pay kina late, man'
--       )::integer
--     ]::service_action_id_arrays
--   )
-- ) FROM individual_contacts_id('lbd') Lynn;

