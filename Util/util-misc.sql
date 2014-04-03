-- * Header  -*-Mode: sql;-*-
-- $Id: utility_misc.sql,v 1.1 2008/11/12 23:41:44 lynn Exp lynn $

--	PostgreSQL MISC Utilities Code

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

\i /usr/local/pgsql/share/contrib/pgxml.sql

-- **  the_value(ANYELEMENT) -> the  value itself
-- move to util-misc.sql!!!
CREATE OR REPLACE
FUNCTION the_value(ANYELEMENT) RETURNS ANYELEMENT AS $$
  SELECT $1
$$ LANGUAGE SQL STRICT IMMUTABLE;
COMMENT ON FUNCTION the_value(ANYELEMENT)
IS 'returns its argument, handy for using values in FROM clauses';

SELECT module_provides('the_value(ANYELEMENT)'::regprocedure);

CREATE OR REPLACE
FUNCTION random(int) RETURNS int AS $$
  SELECT trunc((random()*$1)+1)::int
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION random(int) IS 
'Returns a random number between 1 and $1 inclusive';

CREATE OR REPLACE
FUNCTION raise_error(regprocedure, text) RETURNS void AS $$
BEGIN
  RAISE EXCEPTION '%: % is null!', $1, $2;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION non_null(ANYELEMENT, regprocedure, text)
RETURNS ANYELEMENT AS $$
  SELECT CASE
    WHEN $1 IS NULL THEN raise_error($2, $3)
  END;
  SELECT $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION non_null(ANYELEMENT, regprocedure)
RETURNS ANYELEMENT AS $$
  SELECT non_null($1, $2, 'illegal null value')
$$ LANGUAGE sql;

-- ++ abstract_table_trigger() -> trigger
CREATE OR REPLACE
FUNCTION abstract_table_trigger() RETURNS trigger AS $$
  BEGIN
     RAISE NOTICE 'Illegal attempt to perform % operation on abstract table %',
       TG_OP, TG_RELNAME;
    RETURN NULL;
  END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION abstract_trigger_for_text(regclass) RETURNS text AS $$
  SELECT 'CREATE TRIGGER ' || quote_ident(table_name || '_trigger') || E'\n  '
	 || 'BEFORE INSERT OR UPDATE OR DELETE ON ' || table_name || E'\n  '
	 || 'FOR EACH ROW EXECUTE PROCEDURE abstract_table_trigger()'
  FROM CAST($1 AS text) table_name
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION abstract_trigger_for(regclass) RETURNS regclass AS $$
BEGIN
  EXECUTE abstract_trigger_for_text($1);
  RETURN $1;
END
$$ LANGUAGE plpgsql STRICT;
COMMENT ON FUNCTION abstract_trigger_for(regclass) IS
'Attaches a trigger prohibiting inserts.';

CREATE OR REPLACE
FUNCTION list_procs_named(text)
RETURNS SETOF regprocedure AS $$
  SELECT oid::regprocedure FROM pg_proc
  WHERE proname = 'debug_on'
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION max_nonnull(ANYELEMENT, ANYELEMENT) RETURNS ANYELEMENT AS $$
  SELECT CASE
    WHEN $1 IS NULL THEN $2
    WHEN $2 IS NULL THEN $1
    WHEN $1 > $2 THEN $1
    ELSE $2
  END
$$ LANGUAGE sql;

