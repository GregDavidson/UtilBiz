-- * Header  -*-Mode: sql;-*-
SELECT module_file_id('Util-SQL/util-array.sql', '$Id: util-array.sql,v 1.3 2007/07/24 04:27:47 greg Exp greg $');

--	PostgreSQL Array Utilities Code

-- ** Copyright

--	Copyright (c) 2005 - 2007, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

SELECT module_requires('util-modules-schema-code');

-- **  the_array(ANYARRAY) -> the  array itself
CREATE OR REPLACE
FUNCTION the_array(ANYARRAY) RETURNS ANYARRAY AS $$
  SELECT $1
$$ LANGUAGE SQL STRICT IMMUTABLE;
COMMENT ON FUNCTION the_array(ANYARRAY)
IS 'returns its argument, handy for using arrays in FROM clauses';

-- **  array_element(ANYARRAY, INTEGER) -> the  array itself
CREATE OR REPLACE
FUNCTION array_element(ANYARRAY, INTEGER) RETURNS ANYELEMENT AS $$
  SELECT $1[$2]
$$ LANGUAGE SQL STRICT IMMUTABLE;
COMMENT ON FUNCTION array_element(ANYARRAY, INTEGER)
IS 'returns the element of the given array at the given index;
handy for using array indices in FROM clauses';

-- **  array_is_empty(ANYARRAY) -> Boolean
CREATE OR REPLACE
FUNCTION array_is_empty(ANYARRAY) RETURNS boolean AS $$
  SELECT $1 IS NULL OR array_upper($1, 1) IS NULL
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION array_is_empty(ANYARRAY)
IS 'true for NULL or empty arrays';

-- **  array_length(ANYARRAY) -> INTEGER
CREATE OR REPLACE
FUNCTION array_length(ANYARRAY) RETURNS INTEGER AS $$
  SELECT CASE
    WHEN array_is_empty($1) THEN 0
    ELSE array_upper($1, 1) - array_lower($1, 1) + 1
  END
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION array_length(ANYARRAY)
IS 'gives 0 for NULL arrays';

CREATE OR REPLACE
FUNCTION array_or_empty(ANYARRAY) RETURNS ANYARRAY AS $$
  SELECT COALESCE($1, '{}')
$$ LANGUAGE sql;
COMMENT ON FUNCTION array_or_empty(ANYARRAY)
IS 'normalizes NULL arrays to empty arrays';

CREATE OR REPLACE
FUNCTION array_head(ANYARRAY) RETURNS ANYELEMENT AS $$
  SELECT CASE WHEN low IS NOT NULL THEN $1[low] END
  FROM array_lower($1, 1) low
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION array_head(ANYARRAY)
IS 'first element of array or NULL';

CREATE OR REPLACE
FUNCTION array_tail(ANYARRAY, OUT ANYARRAY) AS $$
  SELECT CASE
    WHEN len = 1 THEN '{}'
    WHEN len > 1 THEN
      COALESCE($1[ (array_lower($1,1)+1) : array_upper($1,1) ])
  END
  FROM array_length($1) len
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION array_tail(ANYARRAY)
IS 'all but first element of array or NULL';

-- **  array_indices(array, step) -> set of indices of the array
CREATE OR REPLACE
FUNCTION array_indices(ANYARRAY, integer) RETURNS SETOF integer AS $$
  SELECT CASE
    WHEN lo IS NOT NULL
    THEN CASE
      WHEN $2 > 0 THEN generate_series(lo, hi, $2)
      WHEN $2 < 0 THEN generate_series(hi, lo, $2)
    END
  END FROM array_lower($1, 1) lo, array_upper($1, 1) hi
$$ LANGUAGE SQL STRICT IMMUTABLE;
COMMENT ON FUNCTION array_indices(ANYARRAY, integer) IS
'returns every step $2 index of the array $1';

-- **  array_indices(array) -> set of indices of the array
CREATE OR REPLACE
FUNCTION array_indices(ANYARRAY) RETURNS SETOF integer AS $$
  SELECT array_indices($1, 1)
$$ LANGUAGE SQL STRICT IMMUTABLE;
COMMENT ON FUNCTION array_indices(ANYARRAY) IS
'returns the indices of the array from lowest to highest';

-- **  array_rindices(array) -> reversed set of indices of the array
CREATE OR REPLACE
FUNCTION array_rindices(ANYARRAY) RETURNS SETOF integer AS $$
  SELECT array_indices($1, -1)
$$ LANGUAGE SQL STRICT IMMUTABLE;
COMMENT ON FUNCTION array_rindices(ANYARRAY) IS
'returns the indices of the array from highest to lowest';

-- this would copy a non-empty array:
-- select ARRAY(select a[i] from array_indices(a) i) from the_array(array[1,2]) a;

-- this would convert a set to an array:
-- ARRAY( select ....; )
-- where the select returns rows of one column

-- **  array_to_set(array) -> set of (index, value) records
-- requires "column definition list" when used, e.g.:
--  select *  from array_to_set( $${'a','b','c'}$$::TEXT[] ) AS ("index" integer, "value" text);
CREATE OR REPLACE
FUNCTION array_to_set(ANYARRAY) RETURNS SETOF RECORD AS $$
  SELECT index, $1[index] as "value"  FROM array_indices($1) index
$$ LANGUAGE SQL STRICT IMMUTABLE;
COMMENT ON FUNCTION array_to_set(ANYARRAY) IS
'returns the array as a set of RECORD(index, value) pairs';

-- **  array_to_list(array) -> set of array values
-- question: can we guarantee the values will be seen in order?
CREATE OR REPLACE
FUNCTION array_to_list(ANYARRAY) RETURNS SETOF ANYELEMENT AS $$
    SELECT $1[i]  FROM array_indices($1) i
$$ LANGUAGE SQL STRICT IMMUTABLE;
COMMENT ON FUNCTION array_to_list(ANYARRAY) IS
'returns the array as a set of its elements from lowest to highest';

-- **  array_to_rlist(array) -> set of array values reversed
CREATE OR REPLACE
FUNCTION array_to_rlist(ANYARRAY) RETURNS SETOF ANYELEMENT AS $$
    SELECT $1[i]  FROM array_rindices($1) i
$$ LANGUAGE SQL STRICT IMMUTABLE;
COMMENT ON FUNCTION array_to_rlist(ANYARRAY) IS
'returns the array as a set of its elements from hiighest to lowest';

CREATE OR REPLACE
FUNCTION array_reverse(ANYARRAY) RETURNS ANYARRAY AS $$
  SELECT CASE
    WHEN array_length($1) < 2 THEN $1
    ELSE ARRAY( SELECT array_to_rlist($1) )
  END
$$ LANGUAGE sql STRICT IMMUTABLE;

-- ** array_without(ANYARRAY, integer) -> ANYARRAY
CREATE OR REPLACE
FUNCTION array_without(ANYARRAY, integer) RETURNS ANYARRAY AS $$
  SELECT CASE
    WHEN array_is_empty($1) THEN $1
    ELSE $1[array_lower($1, 1):$2-1] ||  $1[$2+1:array_upper($1, 1)]
  END
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION array_without(ANYARRAY, integer)
IS 'return a shorter array omitting the element at the specified index';

-- ** array_minus(ANYARRAY, ANYELEMENT) -> ANYARRAY
CREATE OR REPLACE
FUNCTION array_minus(ANYARRAY, ANYELEMENT) RETURNS ANYARRAY AS $$
  SELECT CASE
    WHEN array_is_empty($1) THEN $1
    ELSE ARRAY( SELECT $1[i] FROM array_indices($1) i WHERE $1[i] != $2 )
  END
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION array_minus(ANYARRAY, ANYELEMENT)
IS 'return a (possibly) shorter array omitting the specified element';

-- ** array_minus_array(ANYARRAY, ANYARRAY) -> ANYARRAY
CREATE OR REPLACE
FUNCTION array_minus_array(ANYARRAY, ANYARRAY) RETURNS ANYARRAY AS $$
  SELECT CASE WHEN array_lower($1, 1) IS NULL THEN $1
    ELSE ARRAY( SELECT $1[i] FROM array_indices($1) i WHERE $1[i] != ALL($2) )
  END
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION array_minus_array(ANYARRAY, ANYARRAY)
IS 'return first array elements not in second array';

-- ~~~ array_interpose(array, element-to-interpose) -> new-array
-- ARRAY MUST START WITH AN ODD INDEX -- 
-- To be fixed !!!
CREATE OR REPLACE
FUNCTION array_interpose(ANYARRAY, ANYELEMENT) RETURNS ANYARRAY AS $$
  SELECT ARRAY(
    SELECT CASE WHEN i % 2 = 1 THEN $1[(i+1)/2] ELSE $2 END
    FROM generate_series(array_lower($1, 1), array_upper($1, 1)*2-1) i
  )
$$ LANGUAGE sql STRICT; -- monotonic
COMMENT ON FUNCTION array_interpose(ANYARRAY, ANYELEMENT)
IS 'the elements of the first array interleaved by the specified element';

-- ++ array_join(ANYARRAY, join_with TEXT) -> TEXT
-- Given: an array of elements convertable to TEXT and a value to join them with
-- Result: the elements of the array as TEXT joined with the given join_with value
CREATE OR REPLACE
FUNCTION array_join(ANYARRAY, TEXT) RETURNS TEXT AS $$
  SELECT array_to_string( ARRAY(SELECT value::TEXT FROM array_to_list($1) value), $2 )
$$ LANGUAGE SQL STRICT; -- monotonic
COMMENT ON FUNCTION array_join(ANYARRAY, TEXT)
IS 'same as array_to_string except that the elements do not have to be text,
merely of some type which can be cast to text';

-- * hitmap filtering functions

-- Now moved to util-hitmap-arrays.sql

-- * Provides

SELECT module_provides('the_array(ANYARRAY)'::regprocedure);
SELECT module_provides('array_is_empty(ANYARRAY)'::regprocedure);
SELECT module_provides('array_indices(ANYARRAY)'::regprocedure);
SELECT module_provides('array_rindices(ANYARRAY)'::regprocedure);
SELECT module_provides('array_reverse(ANYARRAY)'::regprocedure);
SELECT module_provides('array_minus(ANYARRAY, ANYELEMENT)'::regprocedure);
SELECT module_provides('array_minus_array(ANYARRAY, ANYARRAY)'::regprocedure);
SELECT module_provides('array_length(ANYARRAY)'::regprocedure);
SELECT module_provides('array_to_set(ANYARRAY)'::regprocedure);
SELECT module_provides('array_to_list(ANYARRAY)'::regprocedure);
SELECT module_provides('array_to_rlist(ANYARRAY)'::regprocedure);
SELECT module_provides('array_interpose(ANYARRAY, ANYELEMENT)'::regprocedure);
SELECT module_provides('array_join(ANYARRAY, TEXT)'::regprocedure);
