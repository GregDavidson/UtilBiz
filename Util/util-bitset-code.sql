-- * Header  -*-Mode: sql;-*-
SELECT module_file_id('Util-SQL/util-bitset-code.sql', '$Id$');

--	PostgreSQL bitset Utilities Code

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

SELECT module_requires('util-bitset-schema');

-- The code here is independent of the choices of
-- chunk size and type established in the schema file.

-- * bitset support

CREATE OR REPLACE
FUNCTION empty_bitset_chunk() RETURNS bitset_chunks_ AS $$
  SELECT 0::bitset_chunks_
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION to_bitset_chunk(integer) RETURNS bitset_chunks_ AS $$
  SELECT (1::bitset_chunks_ << $1)::bitset_chunks_
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION to_bitset_chunk(integer) IS'
  Converts a small integer value to a bitset singleton,
  i.e. a bitset with only that one value on, all others off.
';

CREATE OR REPLACE
FUNCTION in_bitset_chunk(integer, bitset_chunks_) RETURNS boolean AS $$
  SELECT ( to_bitset_chunk($1) & $2 ) != 0
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION in_bitset_chunk(integer, bitset_chunks_) IS'
  Returns true iff bit $1 in bitset $2 is on.
  $2 can be either a bit varying type or an integer with a bitset value.
';

CREATE OR REPLACE
FUNCTION empty_bitset() RETURNS bitsets AS $$
  SELECT '{}'::bitsets
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION to_bitset(integer) RETURNS bitsets AS $$
  SELECT CASE WHEN $1 < bitset_chunksize_() THEN
    bitset_box_(to_bitset_chunk($1))
  ELSE
    bitset_cons_( empty_bitset_chunk(), to_bitset($1 - bitset_chunksize_()) )
  END
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION bitset_trim_(bitsets) RETURNS bitsets AS $$
  SELECT CASE
    WHEN array_is_empty($1) THEN $1
    WHEN array_head($1) = 0 THEN bitset_trim_(array_tail(bitset_array_($1)))
    ELSE $1
  END::bitsets
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION bitset_trim(bitsets) RETURNS bitsets AS $$
  SELECT array_reverse(bitset_array_(bitset_trim_(array_reverse(bitset_array_($1)))))::bitsets
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION bitset_diff_(bitsets, bitsets) RETURNS bitsets AS $$
  SELECT ARRAY(
    SELECT COALESCE(($1)[i], 0) & ~ COALESCE(($2)[i], 0)
    FROM generate_series(1, upper) i
  )::bitsets
  FROM max_nonnull( array_upper($1, 1), array_upper($2, 1) ) upper
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION bitset_diff(bitsets, bitsets) RETURNS bitsets AS $$
  SELECT CASE
    WHEN array_is_empty($1) THEN $1
    WHEN array_is_empty($2) THEN $1
    ELSE bitset_trim(bitset_diff_($1, $2))
  END
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION bitset_drop(bitsets, integer) RETURNS bitsets AS $$
  SELECT bitset_diff($1, to_bitset($2))
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION bitset_intersect_(bitsets, bitsets) RETURNS bitsets AS $$
  SELECT ARRAY(
    SELECT COALESCE(($1)[i], 0) & COALESCE(($2)[i], 0)
    FROM generate_series(1, upper) i
  )::bitsets
  FROM max_nonnull( array_upper($1, 1), array_upper($2, 1) ) upper
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION bitset_intersect(bitsets, bitsets) RETURNS bitsets AS $$
  SELECT CASE
    WHEN array_is_empty($1) THEN $1
    WHEN array_is_empty($2) THEN $2
    ELSE bitset_trim(bitset_intersect_($1, $2))
  END
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION bitset_union(bitsets, bitsets) RETURNS bitsets AS $$
  SELECT CASE
    WHEN array_is_empty($1) THEN $2
    WHEN array_is_empty($2) THEN $1
    ELSE ARRAY(
      SELECT COALESCE(($1)[i], 0) | COALESCE(($2)[i], 0)
      FROM generate_series(1, upper) i
    )
  END::bitsets
  FROM max_nonnull( array_upper($1, 1), array_upper($2, 1) ) upper
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION to_bitset(integer[]) RETURNS bitsets AS $$
  SELECT CASE WHEN array_is_empty($1) THEN empty_bitset()
  ELSE
    bitset_union(to_bitset(array_head($1)), to_bitset(array_tail($1)))
  END
$$ LANGUAGE sql STRICT IMMUTABLE;


CREATE OR REPLACE
FUNCTION in_bitset(integer, bitsets) RETURNS boolean AS $$
  SELECT debug_assert('in_bitset(integer, bitsets)', $1 >= 0, 'bit >= 0', false);
  SELECT CASE WHEN chunk > array_length($2) THEN false
  ELSE in_bitset_chunk($1, ($2)[chunk])
  END
  FROM CAST( $1 / bitset_chunksize_() + 1 AS integer ) chunk
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION in_bitset(integer, bitsets) IS
'$1 is in bitset $2';

CREATE OR REPLACE
FUNCTION ni_bitset(integer, bitsets) RETURNS boolean AS $$
  SELECT NOT in_bitset($1, $2)
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION ni_bitset(integer, bitsets) IS
'$1 is NOT in bitset $2';

CREATE OR REPLACE
FUNCTION bitset_chunk_text(bitset_chunks_) RETURNS text AS $$
  SELECT $1::bitset_chunk_bits_::text
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION bitset_chunk_text(bitset_chunks_) IS
'represent a bitset chunk as untrimmed text';

CREATE OR REPLACE
FUNCTION bitset_chunk_text_trimmed(bitset_chunks_) RETURNS text AS $$
  SELECT regexp_replace(bitset_chunk_text($1),'^0+','')
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION bitset_chunk_text(bitset_chunks_) IS
'represent a bitset chunk as trimmed text';

CREATE OR REPLACE
FUNCTION bitset_text(bitsets) RETURNS text AS $$
  SELECT CASE
    WHEN array_is_empty($1) THEN '0'
    ELSE bitset_chunk_text_trimmed( ($1)[array_upper($1,1)] ) ||
      array_to_string(
        ARRAY( SELECT bitset_chunk_text( chunk )
	       FROM array_to_list(array_tail(array_reverse(bitset_array_($1)))) chunk
	       WHERE chunk IS NOT NULL
	),
      ''
      )
  END
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION bitset_text(bitsets) IS
'represent a bitset as text';
