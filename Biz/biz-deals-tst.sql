-- utility_money_test.sql
-- $Id: utility_money_test.sql,v 1.3 2008/04/19 00:24:15 lynn Exp $
-- part of domain-independent support structures
-- Lynn Dobbs and Greg Davidson

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- tests concerning notes require data in biz_client_schema tables

-- SELECT note_on('line_items',line_item('pencil'),'lbd','put lead in it');

-- SELECT notes_on('line_items',line_item('pencil'));

SELECT test_func(
  'item_price(line_item_ids, deal_package_ids)',
  item_price('Profile', 'BasePrices'),
  1395::us_pennies
);

SELECT test_func(
  'item_price(line_item_ids, deal_package_ids)',
  item_price('pencil', 'Affiliate'),
  23::us_pennies
);

SELECT test_func(
  'item_price(line_item_ids, deal_package_ids)',
  item_price('Profile', 'Affiliate'),
  139::us_pennies
);


