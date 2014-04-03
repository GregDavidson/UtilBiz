-- utility_money_schema.sql
-- $Id: utility_money_test_data.sql,v 1.4 2008/04/30 17:17:02 lynn Exp $
-- part of domain-independent support structures
-- Lynn Dobbs and Greg Davidson

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

SELECT make_chargeable_item('pencil');
SELECT make_chargeable_item('pen');
SELECT make_chargeable_item('tax');

SELECT make_fixed_price('pencil', 23);
SELECT make_fixed_price('pen', 59);

SELECT make_chargeable_item('Profile');
SELECT make_chargeable_item('Agent Assist');
SELECT make_chargeable_item('CO SurCharge');
SELECT make_chargeable_item('Profile Plus');
SELECT make_creditable_item('Paymnt Rec''d');
SELECT make_chargeable_item('Fin Chrg');

SELECT make_fixed_price('Profile', '1395');
SELECT make_fixed_price('Agent Assist', '300');
SELECT make_fixed_price('CO SurCharge', '300');
SELECT make_fixed_price('Profile Plus', '3495');

SELECT make_deal(
  line_item('Fin Chrg'),
  'deal_kind_special',
  base_price_pkg(),
  1,				-- selects finance charge policy
  time_range()
);


SELECT make_deal_package(
  'Affiliate', base_price_pkg(), time_range()
);

SELECT make_deal(
  'Profile',
  'deal_kind_percent',
  'Affiliate',
  percent_pennies(90),
  time_range()
);
