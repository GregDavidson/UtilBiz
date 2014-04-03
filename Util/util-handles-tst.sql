-- * Header  -*-Mode: sql;-*-
-- SELECT module_file_id('utility_handles_test.sql', '$Id: util_handles_test.sql,v 1.1 2008/11/15 08:19:31 greg Exp greg $');

--	PostgreSQL Utility Row Handles Test

-- ** Copyright

--	Copyright (c) 2005 -2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * meta_func_default_handle_for

SELECT test_func(
  'meta_func_default_handle_for(regclass, meta_columns[])',
  default_handle_for_text('meta_entity_traits'),
$$CREATE  OR REPLACE
FUNCTION meta_entity_traits_default_handle(meta_entities)
RETURNS text LANGUAGE 'sql' STRICT AS
'SELECT ''entity='' || ($1)::text
FROM meta_entity_traits
WHERE entity=$1';
$$
);

SELECT test_func(
  'meta_func_default_handle_for(regclass, meta_columns[])',
  default_handle_for_text('table_with_2_primaries'),
$$CREATE  OR REPLACE
FUNCTION table_with_2_primaries_default_handle(integer, text)
RETURNS text LANGUAGE 'sql' STRICT AS
'SELECT ''i='' || ($1)::text|| '';'' ||''n='' || ($2)::text
FROM table_with_2_primaries
WHERE i=$1 AND n=$2';
$$
);

-- * meta_handle_table_for

SELECT test_func(
  'meta_handle_table_for(regclass, meta_columns[])',
  handle_table_for_text('meta_entity_traits'),
$$CREATE TABLE meta_entity_traits_row_handles (
  handle handles NOT NULL UNIQUE,
  entity meta_entities PRIMARY KEY REFERENCES meta_entity_traits
);
$$
);

SELECT test_func(
  'meta_handle_table_for(regclass, meta_columns[])',
  handle_table_for_text('table_with_2_primaries'),
$$CREATE TABLE table_with_2_primaries_row_handles (
  handle handles NOT NULL UNIQUE,
  i integer,
  n text,
   PRIMARY KEY(i, n),
   FOREIGN KEY(i, n) REFERENCES table_with_2_primaries(i, n)ON DELETE CASCADE
);
$$
);

-- * meta_func_get_handle_for

SELECT test_func(
  'meta_func_get_handle_for(regclass, meta_columns[])',
  get_handle_for_text('meta_entity_traits'),
$$CREATE  OR REPLACE
FUNCTION get_meta_entity_traits_handle(meta_entities)
RETURNS text LANGUAGE 'sql' STRICT AS
'SELECT COALESCE(
  (SELECT handle FROM meta_entity_traits_row_handles WHERE entity=$1),
  meta_entity_traits_default_handle($1)
)';
$$
);

SELECT test_func(
  'meta_func_get_handle_for(regclass, meta_columns[])',
  get_handle_for_text('table_with_2_primaries'),
$$CREATE  OR REPLACE
FUNCTION get_table_with_2_primaries_handle(integer, text)
RETURNS text LANGUAGE 'sql' STRICT AS
'SELECT COALESCE(
  (SELECT handle FROM table_with_2_primaries_row_handles WHERE i=$1 AND n=$2),
  table_with_2_primaries_default_handle($1, $2)
)';
$$
);

-- * meta_func_handle_field_for

SELECT test_func(
  'meta_func_handle_field_for(regclass, meta_columns)',
  handle_field_text(
    'meta_entity_traits',
    meta_column('entity', 'meta_entities')
  ),
$$CREATE  OR REPLACE
FUNCTION meta_entity_traits_entity(handles)
RETURNS meta_entities LANGUAGE 'sql' STRICT AS
'  SELECT non_null(
  the_field,
  ''meta_func_handle_field_for(regclass, meta_columns)''::regprocedure, ''entity''
) FROM (
  SELECT entity FROM meta_entity_traits_row_handles WHERE handle = $1
) foo(the_field)';
$$
);

SELECT handle_field_texts('table_with_2_primaries');


-- * handles_for

SELECT handles_for('meta_entity_traits');

SELECT handles_for('table_with_2_primaries');

SELECT test_func(
  'meta_func_default_handle_for(regclass, meta_columns[])',
  table_with_2_primaries_default_handle(5, 'five'),
  'i=5;n=five'
);

SELECT test(
  $$ table_with_2_primaries_default_handle(9, 'nine') IS NULL $$
);

-- * meta_func_set_handle_for

SELECT test_func(
  'meta_func_set_handle_for(regclass, meta_columns[])',
  set_handle_for_text('meta_entity_traits'),
$$CREATE  OR REPLACE
FUNCTION set_meta_entity_traits_row(handles, meta_entities)
RETURNS meta_entity_traits_row_handles LANGUAGE 'sql' STRICT AS
'INSERT INTO meta_entity_traits_row_handles VALUES ($1, $2);
SELECT * FROM meta_entity_traits_row_handles WHERE $1 = handle';
$$
);

SELECT test_func(
  'meta_func_set_handle_for(regclass, meta_columns[])',
  set_handle_for_text('table_with_2_primaries'),
$$CREATE  OR REPLACE
FUNCTION set_table_with_2_primaries_row(handles, integer, text)
RETURNS table_with_2_primaries_row_handles LANGUAGE 'sql' STRICT AS
'INSERT INTO table_with_2_primaries_row_handles VALUES ($1, $2, $3);
SELECT * FROM table_with_2_primaries_row_handles WHERE $1 = handle';
$$
);

SELECT test_func(
  'meta_func_set_handle_for(regclass, meta_columns[])',
  (set_table_with_2_primaries_row('handletest',5,'five')).i,
  5
);
