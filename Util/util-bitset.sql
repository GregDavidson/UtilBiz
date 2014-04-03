-- * Header  -*-Mode: sql;-*-
SELECT module_file_id('Util-SQL/util-bitset.sql', '$Id$');

--	PostgreSQL bitset Utilities Code

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

SELECT module_requires('util-modules-schema-code');

-- Let's replace this with some smart meta code!

-- * bitset support

CREATE OR REPLACE
FUNCTION empty_bitset(integer) RETURNS bit varying AS $$
  SELECT repeat('0', $1)::bit varying
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION to_bitset(num_bits integer, the_bit integer) RETURNS bit varying AS $$
  SELECT (
    SELECT empty_bitset(left_pad) || B'1' || empty_bitset($2)
    FROM
      debug_assert(this, $1 > 0, 'num_ bits > 0', $1) num_bits,
      debug_assert(this, $2 >= 0, 'the_bit >= 0', $1) the_bit,
      debug_assert(this, $1 > $2, 'num_bits > the_bit', $1 - $2 - 1) left_pad
  ) FROM debug_enter('to_bitset(integer, integer)') this
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION to_bitset(integer, integer) IS
'to_bitset(num_bits,the_bit) = {the_bit}::bit_varying(num_bits)';

CREATE OR REPLACE
FUNCTION in_bitset(num_bits integer, the_bit integer, bit_set bit varying) RETURNS boolean AS $$
  SELECT ( to_bitset($1, $2) & $3::integer ) != 0
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION in_bitset(integer, integer, bit varying) IS
'$2 is an element of $3, given $3 bit varying($1)';

CREATE OR REPLACE
FUNCTION ni_bitset(num_bits, the_bit integer, bit_set bit varying) RETURNS boolean AS $$
  SELECT NOT in_bitset($1, $2, $3)
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION ni_bitset(integer, integer, bit varying) IS
'$2 is NOT an element of $3, given $3 bit varying($1)';
