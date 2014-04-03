-- * Header  -*-Mode: sql;-*-
-- SELECT module_file_id('utility_test.sql', '$Id$');

--	PostgreSQL Utilities Test Framework

-- ** Copyright

--	Copyright (c) 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

CREATE OR REPLACE
FUNCTION testif(bool) RETURNS bool AS $$
BEGIN
  IF $1 IS NULL OR NOT $1 THEN
    RAISE EXCEPTION 'Test failed!';
  END IF;
  RETURN $1;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION test(text, bool) RETURNS bool AS $$
BEGIN
  IF $2 IS NULL OR NOT $2 THEN
    RAISE EXCEPTION 'Test % failed!', $1;
  END IF;
  RETURN $2;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION test_func(regprocedure, bool) RETURNS regprocedure AS $$
BEGIN
  IF $2 IS NULL OR NOT $2 THEN
    RAISE EXCEPTION 'FUNCTION % failed!', $1::text;
  END IF;
  RETURN $1;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION test_func(regprocedure, ANYELEMENT, ANYELEMENT)
RETURNS regprocedure AS $$
BEGIN
  IF $2 IS NULL != $3 IS NULL OR $2 != $3 THEN
    RAISE EXCEPTION '%>>> % RETURNED:% %>>> NOT:% %>>> END',
    E'\n', $1, E'\n', $2, E'\n', $3;
  END IF;
  RETURN $1;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION test(text) RETURNS bool AS $$
DECLARE
  the_result boolean;
BEGIN
  EXECUTE 'SELECT ' || $1 INTO the_result;
  IF the_result = false THEN
    RAISE EXCEPTION 'Test failed: %', E'\n\tSELECT ' || $1;
  END IF;
  RETURN the_result;
END
$$ LANGUAGE plpgsql STRICT;
