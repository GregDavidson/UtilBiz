-- * Header  -*-Mode: sql;-*-
-- SELECT module_file_id('utility-db_code.sql', '$Id: util_db_code.sql,v 1.1 2008/11/15 08:18:16 greg Exp greg $');

--	PostgreSQL Database Reflection Code

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

-- SELECT module_requires('util-modules-schema-code');

-- This module provides machinery for interrogating the
-- database about its contents.

-- ** pg_oid_view(oid INTEGER, name TEXT)
CREATE OR REPLACE
VIEW pg_oid_view AS
	SELECT class.oid, class.relname AS name FROM pg_class class
UNION
	SELECT proc.oid, proc.proname AS name FROM pg_proc proc;

-- ** Fancy Metaprocedure code

-- ** regprocedure_to_argtypes(regprocedure) -> TEXT
CREATE OR REPLACE
FUNCTION regprocedure_to_argtypes(regprocedure) RETURNS oidvector AS $$
  select proargtypes from pg_proc where oid = $1
$$ LANGUAGE SQL STRICT STABLE;

-- ** regprocedure_to_head(regprocedure) -> TEXT
CREATE OR REPLACE
FUNCTION regprocedure_to_head(regprocedure) RETURNS  TEXT AS $$
  SELECT
    proname || '(' || pg_catalog.oidvectortypes(proargtypes) || ')->' ||
    CASE WHEN proretset THEN 'SETOF:' ELSE '' END || pg_catalog.format_type(prorettype, NULL)
  FROM pg_proc WHERE oid = $1
$$ LANGUAGE SQL STRICT STABLE;
COMMENT ON FUNCTION regprocedure_to_head(regprocedure) IS
'returns the header of a procedure in my preferred format';

-- ** regprocedure_to_header(regprocedure) -> TEXT
CREATE OR REPLACE
FUNCTION regprocedure_to_header(regprocedure) RETURNS  TEXT AS $$
  SELECT
    'FUNCTION ' || proname || '(' || pg_catalog.oidvectortypes(proargtypes) || ') RETURNS ' ||
    CASE WHEN proretset THEN 'SETOF ' ELSE '' END || pg_catalog.format_type(prorettype, NULL)
  FROM pg_proc WHERE oid = $1
$$ LANGUAGE SQL STRICT STABLE;
COMMENT ON FUNCTION regprocedure_to_header(regprocedure) IS
'returns the header of a procedure in definition format';

-- ** equivalent_signatures(regprocedure, regprocedure) -> BOOLEAN
CREATE OR REPLACE
FUNCTION equivalent_signatures(regprocedure, regprocedure) RETURNS  BOOLEAN AS $$
  SELECT
    p1.proargtypes = p2.proargtypes AND p1.proretset = p2.proretset AND p1.prorettype = p2.prorettype
  FROM pg_proc p1, pg_proc p2 WHERE p1.oid = $1 AND p2.oid = $2
$$ LANGUAGE SQL STRICT STABLE;
COMMENT ON FUNCTION equivalent_signatures(regprocedure, regprocedure) IS
'checks the equivalence of the signatures of the two procedures of given oid values';
