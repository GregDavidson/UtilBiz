-- * Header  -*-Mode: sql;-*-
SELECT module_file_id('Util-SQL/util-debug-code.sql', '$Id: util-debug-code.sql,v 1.1 2006/11/02 02:04:26 greg Exp greg $');
--    (setq outline-regexp "^--[ \t]+[*+-~=]+ ")
--    (outline-minor-mode)

--	PostgreSQL Utilities
--	Debugging Code

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Requires (from utilities-schema.sql):

-- ** Provides

-- * Debugging Facilities

-- ** debug_on(regprocedure) -> BOOLEAN
CREATE OR REPLACE
FUNCTION debug_on(regprocedure)
RETURNS BOOLEAN AS $$
  SELECT $1 IN (SELECT id FROM debug_on_oids)
$$ LANGUAGE SQL STRICT STABLE;
COMMENT ON FUNCTION debug_on(regprocedure)
IS 'Is debugging turned on for this function?
E.g.: select debug_on(''debug_on(regprocedure)'')';

-- ** debug_on(regprocedure, boolean) -> void
CREATE OR REPLACE
FUNCTION debug_on(regprocedure, boolean)
RETURNS void AS $$
BEGIN
  IF $2 THEN
     BEGIN
       INSERT INTO debug_on_oids(id) VALUES ($1);
       EXCEPTION WHEN unique_violation THEN
	  -- do nothing
     END;
  ELSE
    DELETE FROM debug_on_oids WHERE id = $1;
  END IF;
END
$$ LANGUAGE plpgsql STRICT;
COMMENT ON FUNCTION debug_on(regprocedure, boolean)
IS 'Set debugging for this procedure to indicated value.
E.g.: select debug_on(''debug_on(regprocedure, boolean)'', true)';

CREATE OR REPLACE
FUNCTION debug_assert_failed(regprocedure)
RETURNS void AS $$
BEGIN
  RAISE EXCEPTION '% assertion failed!', $1;
END
$$ LANGUAGE plpgsql STRICT;
COMMENT ON FUNCTION debug_assert_failed(regprocedure)
IS 'Report failure of given function.  Used by other debug functions.';

-- ++ debug_assert(regprocedure, boolean) -> boolean
CREATE OR REPLACE
FUNCTION debug_assert(regprocedure, boolean)
RETURNS void AS $$
  SELECT CASE
    WHEN $2 IS NULL OR NOT $2 THEN debug_assert_failed($1)
  END
$$ LANGUAGE SQL;
COMMENT ON FUNCTION debug_assert(regprocedure, boolean)
IS 'Report failure of function unless boolean is true.';

CREATE OR REPLACE
FUNCTION debug_assert_failed(regprocedure, ANYELEMENT)
RETURNS void AS $$
BEGIN
  RAISE EXCEPTION '% assertion failed: %!', $1, $2;
END
$$ LANGUAGE plpgsql STRICT;
COMMENT ON FUNCTION debug_assert_failed(regprocedure, ANYELEMENT)
IS 'Report failure of given function mentioning key value.
Used by other debug functions.';

-- ++ debug_assert(regprocedure, boolean, msg) -> boolean
CREATE OR REPLACE
FUNCTION debug_assert(regprocedure, boolean, ANYELEMENT)
RETURNS ANYELEMENT AS $$
  SELECT CASE
    WHEN $2 IS NULL OR NOT $2 THEN debug_assert_failed($1, $3)
  END;
  SELECT $3
$$ LANGUAGE SQL;
COMMENT ON FUNCTION debug_assert(regprocedure, boolean, ANYELEMENT)
IS 'Report failure of function involving given value unless boolean is true;
otherwise return the given value.';

-- ++ debug_assert(regprocedure, boolean, msg, return-value) -> boolean
CREATE OR REPLACE
FUNCTION debug_assert(regprocedure, boolean, TEXT, ANYELEMENT)
RETURNS ANYELEMENT AS $$
  SELECT CASE
    WHEN $2 IS NULL OR NOT $2 THEN debug_assert_failed($1, $3)
  END;
  SELECT $4
$$ LANGUAGE SQL;
COMMENT ON FUNCTION debug_assert(regprocedure, boolean, TEXT, ANYELEMENT)
IS 'Report failure of function with message involving the given value unless boolean is true; otherwise return the given value';

-- Here's how to find out what signatures are around for
-- a given function name, e.g. debug_on:
--
-- select oid::regprocedure from pg_proc where proname = 'debug_on';

CREATE OR REPLACE
FUNCTION raise_debug_note(regprocedure, text)
RETURNS void AS $$
  BEGIN RAISE NOTICE '% note: %', $1, $2; END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION raise_debug_note(regprocedure, text)
IS 'RAISE NOTICE about given procedure with given message.';

CREATE OR REPLACE
FUNCTION debug_note(regprocedure, text)
RETURNS void AS $$
  SELECT CASE WHEN debug_on($1) THEN raise_debug_note($1, $2) END
$$ LANGUAGE sql;
COMMENT ON FUNCTION debug_note(regprocedure, text)
IS 'If debugging given procedure, RAISE NOTICE with given message.';

CREATE OR REPLACE
FUNCTION raise_debug_note(regprocedure, text, ANYELEMENT)
RETURNS ANYELEMENT AS $$
BEGIN
  IF $3 IS NULL THEN
    RAISE NOTICE '% note: % WITH NULL', $1, $2;
  ELSE
    RAISE NOTICE '% note: %: %', $1, $2, $3;
  END IF;
  RETURN $3;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION raise_debug_note(regprocedure, text, ANYELEMENT)
IS 'RAISE NOTICE about given procedure with given message and value
and return that value.';

CREATE OR REPLACE
FUNCTION debug_note(regprocedure, text, ANYELEMENT)
RETURNS ANYELEMENT AS $$
  SELECT CASE WHEN debug_on($1) THEN raise_debug_note($1, $2, $3) END;
  SELECT $3
$$ LANGUAGE sql;
COMMENT ON FUNCTION debug_note(regprocedure, text, ANYELEMENT)
IS 'If debugging given function, RAISE NOTICE with given message and value.
In any case, return the given value';

CREATE OR REPLACE
FUNCTION raise_debug_enter(regprocedure)
RETURNS void AS $$
  BEGIN RAISE NOTICE 'Entered %', $1; END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION raise_debug_enter(regprocedure)
IS 'RAISE NOTICE that we''ve entered the given function.
This is intended to be called by other debug functions!';

CREATE OR REPLACE
FUNCTION debug_enter(regprocedure)
RETURNS regprocedure AS $$
  SELECT CASE WHEN debug_on($1) THEN raise_debug_enter($1) END;
  SELECT $1
$$ LANGUAGE sql;
COMMENT ON FUNCTION debug_enter(regprocedure)
IS 'When debugging is on for the given function, RAISE NOTICE
that we have entered it.';

CREATE OR REPLACE
FUNCTION raise_debug_enter(regprocedure, text)
RETURNS void AS $$
  BEGIN RAISE NOTICE 'Entered %: %', $1, $2; END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION raise_debug_enter(regprocedure, text)
IS 'RAISE NOTICE that we''ve entered the given function along with the
given message.  This is intended to be called by other debug functions!';

CREATE OR REPLACE
FUNCTION debug_enter(regprocedure, text)
RETURNS regprocedure AS $$
  SELECT CASE WHEN debug_on($1) THEN raise_debug_enter($1, $2) END;
  SELECT $1
$$ LANGUAGE sql;
COMMENT ON FUNCTION debug_enter(regprocedure, text)
IS 'When debugging is on for the given function, RAISE NOTICE
that we have entered it and include the given message.';

CREATE OR REPLACE
FUNCTION raise_debug_enter(regprocedure, text, ANYELEMENT)
RETURNS void AS $$
BEGIN
  IF $3 IS NULL THEN
    RAISE NOTICE 'Entered %: % IS NULL', $1, $2;
  ELSE
    RAISE NOTICE 'Entered %: % = %', $1, $2, $3;
  END IF;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION raise_debug_enter(regprocedure, text, ANYELEMENT)
IS 'RAISE NOTICE that we''ve entered the given function along with the
given message and value.  This is intended to be called by other debug
functions!  ';

CREATE OR REPLACE
FUNCTION debug_enter(regprocedure, text, ANYELEMENT)
RETURNS regprocedure AS $$
  SELECT CASE WHEN debug_on($1) THEN raise_debug_enter($1, $2, $3) END;
  SELECT $1
$$ LANGUAGE sql;
COMMENT ON FUNCTION debug_enter(regprocedure, text, ANYELEMENT)
IS 'When debugging is on for the given function, RAISE NOTICE that we
have entered it and include the given message and value.';

CREATE OR REPLACE
FUNCTION raise_debug_show(regprocedure, text, ANYELEMENT)
RETURNS void AS $$
BEGIN
  IF $3 IS NULL THEN
    RAISE NOTICE '%: % IS NULL', $1, $2;
  ELSE
    RAISE NOTICE '%: % = %', $1, $2, $3;
  END IF;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION raise_debug_show(regprocedure, text, ANYELEMENT)
IS 'RAISE a NOTICE showing a named value';

CREATE OR REPLACE
FUNCTION debug_show(regprocedure, text, ANYELEMENT)
RETURNS ANYELEMENT AS $$
  SELECT CASE WHEN debug_on($1) THEN raise_debug_show($1, $2, $3) END;
  SELECT $3
$$ LANGUAGE sql;
COMMENT ON FUNCTION debug_show(regprocedure, text, ANYELEMENT)
IS 'When debuggin this function, RAISE a NOTICE showing a named value';

CREATE OR REPLACE
FUNCTION raise_debug_return(regprocedure, ANYELEMENT)
RETURNS ANYELEMENT AS $$
BEGIN
  IF $2 IS NULL THEN
    RAISE NOTICE '% returns NULL', $1;
  ELSE
    RAISE NOTICE '% returns %', $1, $2;
  END IF;
  RETURN $2;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION raise_debug_return(regprocedure, ANYELEMENT)
IS 'RAISE a NOTICE that the given function is returning the given
value and return it.';

CREATE OR REPLACE
FUNCTION debug_return(regprocedure, ANYELEMENT)
RETURNS ANYELEMENT AS $$
  SELECT CASE WHEN debug_on($1) THEN raise_debug_return($1, $2) END;
  SELECT $2
$$ LANGUAGE sql;
COMMENT ON FUNCTION debug_return(regprocedure, ANYELEMENT)
IS 'If we are debugging the given function, RAISE a NOTICE that it is
returning the given value and return it.';
