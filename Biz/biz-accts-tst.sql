-- biz_accounting_test.sql
-- $Id: biz_accounting_test.sql,v 1.1 2008/04/18 02:05:48 lynn Exp $
-- Lynn Dobbs and Greg Davidson
-- April 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

update service_actions set ending=event_time() where id=service_actions_id('lbd_profile_action');

update service_actions set state='service_state_complete' where id=service_actions_id('lbd_profile_action');

select * from view_service_actions;

select * from view_service_actions where whole_id IS NULL AND trans_id NOT IN (select whole_id from service_action_trees);
