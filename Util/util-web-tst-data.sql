-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

SELECT slot_subs( '<1>', ARRAY['one'] );

SELECT slot_subs( '<1> is <3>', ARRAY['Greg', 'Mary', 'Brilliant', 'Sexy'] );

SELECT slot_subs( 'Lynn Dobbs is a loyal friend.', ARRAY['foo', 'bar'] );

SELECT html_elem_text(
  html_element('html_tag_input',  ARRAY[
    html_attr('html_attr_type', 'checkbox'),
    html_attr('html_attr_value', '<1>')
  ]),
  ARRAY['one', 'two']
);
