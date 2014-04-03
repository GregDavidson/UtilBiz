-- * Header  -*-Mode: sql;-*-
SELECT module_file_id('Util-SQL/util-bitset.sql', '$Id$');

--	PostgreSQL bitset Utilities Schema

-- ** Copyright

--	Copyright (c) 2005-2009, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

SELECT module_requires('util-modules-schema-code');

-- Size and/or Type-Specific bitsets could be meta-generated,
-- but we're being simpler here.

-- These integer bitsets can grow as needed.  Our bitset operations
-- do not require uniformity of length.

CREATE DOMAIN bitsets AS int8[] NOT NULL;

-- The definitions in this schema file are dependent on our
-- choices for chunk size and type.  All of the definitions
-- below end in _ indicating that they are not part of the
-- bitsets API.

CREATE DOMAIN bitset_chunks_ AS int8 NOT NULL;
CREATE DOMAIN bitset_chunk_bits_ AS bit(64) NOT NULL;

CREATE FUNCTION bitset_chunksize_() RETURNS integer AS $$
  SELECT 64
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE FUNCTION bitset_box_(int8) RETURNS bitsets AS $$
  SELECT ARRAY[$1]::bitsets
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE FUNCTION bitset_cons_(bitset_chunks_, bitsets) RETURNS bitsets AS $$
  SELECT $1::int8 || $2
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE FUNCTION bitset_array_(bitsets) RETURNS int8[] AS $$
  SELECT $1
$$ LANGUAGE sql STRICT IMMUTABLE;

