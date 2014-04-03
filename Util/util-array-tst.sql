-- utility_array_test.sql
-- $Id: utility_array_test.sql,v 1.1 2008/04/18 02:02:40 lynn Exp $
-- Lynn Dobbs and Greg Davidson
-- April 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

SELECT test_func(
  'the_value(ANYELEMENT)',
  the_value('x'::text),
  'x'
);

SELECT test_func(
  'the_array(ANYARRAY)',
  the_array(ARRAY['hello']),
  ARRAY['hello']
);

SELECT test_func(
  'array_element(ANYARRAY, INTEGER)',
  array_element(ARRAY['one', 'two'], 2),
  'two'
);

SELECT test_func(
  'array_is_empty(ANYARRAY)',
  array_is_empty(ARRAY['one', 'two']),
  false
);

SELECT test_func(
  'array_length(ANYARRAY)',
  array_length(ARRAY['one', 'two']),
  2
);

SELECT test_func(
  'array_or_empty(ANYARRAY)',
  array_or_empty(ARRAY['one', 'two']),
  ARRAY['one', 'two']
);

SELECT test_func(
  'array_head(ANYARRAY)',
  array_head(ARRAY['one', 'two']),
  'one'
);

SELECT test_func(
  'array_tail(ANYARRAY)',
  array_tail(ARRAY['one', 'two']),
  ARRAY['two']
);

SELECT test_func(
  'array_indices(ANYARRAY, integer)',
  ARRAY( SELECT array_indices(ARRAY['one', 'two', 'three', 'four', 'five'], 2) ),
  ARRAY[1, 3, 5]
);

SELECT test_func(
  'array_indices(ANYARRAY)',
  ARRAY( SELECT array_indices(ARRAY['one', 'two']) ),
  ARRAY[1, 2]
);

SELECT test_func(
  'array_rindices(ANYARRAY)',
  ARRAY( SELECT array_rindices(ARRAY['one', 'two']) ),
  ARRAY[2, 1]
);

-- SELECT test_func(
--   'array_to_set(ANYARRAY)',
--   ARRAY( SELECT array_to_set(ARRAY['one', 'two']) ),
--   ARRAY[ ROW(1, 'one'), ROW(2, 'two') ]
-- );

SELECT test_func(
  'array_to_list(ANYARRAY)',
  ARRAY( SELECT array_to_list(ARRAY['one', 'two']) ),
  ARRAY['one', 'two']
);

SELECT test_func(
  'array_to_list(ANYARRAY)',
  array_to_list('{}'::text[] ) IS NULL
);

SELECT test_func(
  'array_to_rlist(ANYARRAY)',
  ARRAY( SELECT array_to_rlist(ARRAY['one', 'two']) ),
  ARRAY['two', 'one']
);

SELECT test_func(
  'array_reverse(ANYARRAY)',
  array_reverse(ARRAY['one', 'two']),
  ARRAY['two', 'one']
);

SELECT test_func(
  'array_without(ANYARRAY, integer)',
  array_without(ARRAY['one', 'two'], 1),
  ARRAY['two']
);

SELECT test_func(
  'array_minus(ANYARRAY, ANYELEMENT)',
  array_minus(ARRAY['one', 'two'], 'one'),
  ARRAY['two']
);

SELECT test_func(
  'array_minus_array(ANYARRAY, ANYARRAY)',
  array_minus_array(ARRAY['one', 'two', 'three'], ARRAY['one', 'two']),
  ARRAY['three']
);

SELECT test_func(
  'array_interpose(ANYARRAY, ANYELEMENT)',
  array_interpose(ARRAY['one', 'two'], 'and'),
  ARRAY['one', 'and', 'two']
);

SELECT test_func(
  'array_join(ANYARRAY, TEXT)',
  array_join(ARRAY['one', 'two'], ' and '),
  'one and two'
);

