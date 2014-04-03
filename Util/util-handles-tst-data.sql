-- * Header  -*-Mode: sql;-*-
-- SELECT module_file_id('utility_handles_test_data.sql', '$Id: util_handles_test_data.sql,v 1.1 2008/11/15 08:19:05 greg Exp greg $');

--	PostgreSQL Utility Row Handles Test Data

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- We need a table with two primary keys with some rows

CREATE TABLE table_with_2_primaries (
  i integer,
  n text,
  PRIMARY KEY(i, n)
);

INSERT INTO table_with_2_primaries(i, n) VALUES (5, 'five');

-- We need some convenience functions for generating text

CREATE OR REPLACE
FUNCTION default_handle_for_text(regclass) RETURNS text AS $$
  SELECT meta_func_text(meta_func_default_handle_for($1, colms))
  FROM primary_meta_column_array($1) colms
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION handle_table_for_text(regclass) RETURNS text AS $$
  SELECT meta_table_text(meta_handle_table_for($1, colms))
  FROM primary_meta_column_array($1) colms
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION get_handle_for_text(regclass) RETURNS text AS $$
  SELECT meta_func_text(meta_func_get_handle_for($1, colms))
  FROM primary_meta_column_array($1) colms
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION handle_field_text(regclass, meta_columns) RETURNS text AS $$
  SELECT meta_func_text(meta_func_handle_field_for($1, $2))
  FROM primary_meta_column_array($1) colms
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION handle_field_texts(regclass)
RETURNS SETOF text AS $$
  SELECT handle_field_text($1, c)
  FROM array_to_list(primary_meta_column_array($1)) c
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION set_handle_for_text(regclass) RETURNS text AS $$
  SELECT meta_func_text(meta_func_set_handle_for($1, colms))
  FROM primary_meta_column_array($1) colms
$$ LANGUAGE SQL STRICT;
