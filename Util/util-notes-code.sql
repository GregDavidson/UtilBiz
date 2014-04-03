-- * Header  -*-Mode: sql;-*-
-- SELECT module_file_id('Util-SQL/util_notes_code.sql', '$Id$');

--	PostgreSQL Utilities Attributed Notes Code And Metacode

-- ** Copyright

--	Copyright (c) 2005, 2006, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

-- SELECT module_requires('util-modules-schema-code');

-- ** Attributed Notes Associated With Table Rows

-- This module provides machinery for managing a table of
-- timestamped and attributed notes and associating them
-- with a row of any table type.  The association mechanism
-- is very similar to that used in handles.

-- For example, given:
--	TABLE my_table(
--	  x x_types,
--	  y y_types,
--	  PRIMARY KEY(x, y),
--	  .. other fields of my_table
--	)
-- SELECT notes_for('my_table');
-- will create:
--  TABLE my_table_row_notes (
--    x x_types,
--    y y_types,
--    PRIMARY KEY(x, y),
--    FOREIGN KEY(x, y) REFERENCES my_table(x, y) ?? ON DELETE CASCADE ?? ,
--    note_id attributed_note_ids REFERENCES attributed_notes
--  );
--  FUNCTION add_my_table_note(attributed_note_ids, x_types, y_types)
--  FUNCTION del_my_table_note(attributed_note_ids, x_types, y_types)
--  FUNCTION my_table_notes_set(x_types, y_types) RETURNS SETOF attributed_note_ids
--  FUNCTION my_table_notes_array(x_types, y_types) RETURNS attributed_notes[]

-- Proposed new features:
--  TYPE my_table_primary_keys AS ( ... )  - just the primary fields of my_table
--  FUNCTION find_my_table_with_note AS (attributed_note_ids)
--	RETURNS SETOF my_table_primary_keys

-- ** These functions create the above naming conventions:

CREATE OR REPLACE
FUNCTION notes_table_name_(regclass) RETURNS text AS $$
  SELECT $1::text || '_row_notes'
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION notes_add_func_name_(regclass) RETURNS text AS $$
  SELECT 'add_' || $1::text || '_note'
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION notes_del_func_name_(regclass) RETURNS text AS $$
  SELECT 'del_' || $1::text || '_note'
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION notes_set_func_name_(regclass) RETURNS text AS $$
  SELECT $1::text || '_notes_set'
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION notes_array_func_name_(regclass) RETURNS text AS $$
  SELECT $1::text || '_notes_array'
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE		-- not in use yet
FUNCTION notes_find_func_name_(regclass) RETURNS text AS $$
  SELECT 'find_' || $1::text || '_with_note'
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- attributed_notes service functions

CREATE OR REPLACE
FUNCTION new_attributed_note(
  attributed_note_ids, event_times, note_author_ids, xml, note_feature_sets
) RETURNS attributed_note_ids AS $$
  INSERT INTO attributed_notes(id, time_, author_id, note, features)
  VALUES($1, $2, $3, $4, $5);
  SELECT $1
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION make_attributed_note(note_author_ids, xml, note_feature_sets)
RETURNS attributed_note_ids AS $$
  SELECT new_attributed_note(
    next_attributed_note_id(), event_time(), $1, $2, $3
  )
$$ LANGUAGE SQL STRICT;
COMMENT ON FUNCTION make_attributed_note(note_author_ids, xml, note_feature_sets)
IS 'makes a new attributed_notes instance';

CREATE OR REPLACE
FUNCTION make_attributed_note(text, xml) RETURNS attributed_note_ids AS $$
  SELECT make_attributed_note(note_authors_id($1), $2, empty_bitset())
$$ LANGUAGE SQL STRICT;
COMMENT ON FUNCTION make_attributed_note(text, xml)
IS '(note_authors.name, note) convenience function';

CREATE OR REPLACE
FUNCTION attributed_note_time_text(event_times) RETURNS text AS $$
  SELECT to_char ($1,  'YYYY-MM-DD HH12:MIam')
$$ LANGUAGE SQL STRICT;
COMMENT ON FUNCTION attributed_note_time_text(event_times) IS 'attributed_notes.time_ to text';

CREATE OR REPLACE
FUNCTION attributed_note_text(attributed_note_ids) RETURNS text AS $$
  SELECT attributed_note_time_text(time_) || ' '
  || get_note_authors_handle(author_id ) || E'\n'
  ||  note::text
  FROM attributed_notes WHERE id = $1
$$ LANGUAGE SQL STRICT;
COMMENT ON FUNCTION attributed_note_text(attributed_note_ids)
IS 'attributed_note_ids to lines of text';

CREATE OR REPLACE
FUNCTION attributed_notes_text(attributed_note_id_arrays) RETURNS text AS $$
  SELECT CASE WHEN array_is_empty($1) THEN ''
  ELSE array_to_string(ARRAY(
    SELECT attributed_note_text(id::attributed_note_ids)
    FROM array_to_list($1) id
  ), E'\n')
  END
$$ LANGUAGE SQL;
COMMENT ON FUNCTION attributed_notes_text(attributed_note_id_arrays) IS
'attributed_note_id_arrays to groups of lines';

CREATE OR REPLACE
FUNCTION sort_notes_by_time(attributed_note_id_arrays)
RETURNS attributed_note_id_arrays AS $$
  SELECT ARRAY(
    SELECT id::integer FROM attributed_notes, array_to_list($1) note_id
    WHERE id = note_id ORDER BY time_
  )::attributed_note_id_arrays
$$ LANGUAGE SQL STRICT;

-- ** Attributed Notes Features

-- should throw an exception if not found!!
CREATE OR REPLACE
FUNCTION note_feature(text) RETURNS note_feature_ids AS $$
  SELECT non_null(id, 'note_feature(text)')
  FROM note_features WHERE name = $1
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION note_feature_set(text[]) RETURNS note_feature_sets AS $$
  SELECT to_bitset(ARRAY(
    SELECT note_feature(feat)::integer
    FROM array_to_list($1) feat
  ))::note_feature_sets
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION in_note_feature_set(note_feature_ids, note_feature_sets)
RETURNS boolean AS $$
  SELECT in_bitset($1, $2)
--  SELECT in_bitset($1::integer, $2::bitsets)
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION note_feature_set_text(note_feature_sets) RETURNS text[] AS $$
  SELECT ARRAY(
    SELECT name FROM note_features WHERE in_note_feature_set(id, $1)
  )
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION get_note_feature_set(attributed_note_ids)
RETURNS note_feature_sets AS $$
  SELECT features FROM attributed_notes WHERE id = $1
$$ LANGUAGE sql STRICT;

-- * Associating notes with rows: the meta-functions

CREATE OR REPLACE
FUNCTION meta_notes_table_for(regclass, meta_columns[]) RETURNS meta_tables AS $$
  SELECT meta_table(
      notes_table_name_($1),
      the_cols,			-- column order matters for add_note function
      NULL::check_constraints[],
      NULL::index_constraints,	-- there may be many notes for a single row
      ARRAY[ index_constraint(
	  NULL::text,
	  meta_cols_name_array(the_cols), -- UNIQUE(note_id, row)
	  constraint_deferring()
      ) ],
      ARRAY[meta_cols_same_forn_keys_cascade($1, $2)],
      NULL::regclass[],		-- no inherited classes
      false,			-- no oids
      'note ids associated with ' || $1::text || ' rows'
  )
  FROM the_array(ARRAY[ meta_column('note_id', 'attributed_note_ids') ] || $2) the_cols
$$ LANGUAGE SQL STRICT;

-- WHAT ABOUT UNIQUENESS OF NOTE IDS?

CREATE OR REPLACE
FUNCTION create_notes_table_for(regclass, meta_columns[]) RETURNS regclass AS $$
  SELECT create_table( meta_notes_table_for($1, $2) )
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION meta_func_add_note_for(regclass, meta_columns[])
RETURNS meta_funcs AS $$
  SELECT meta_func(
    true,
    notes_add_func_name_($1),
    ARRAY[ meta_arg('note_id', 'attributed_note_ids') ]
    || meta_cols_meta_arg_array($2),
    'attributed_note_ids',
    false,
    'meta_func_sql_',
    meta_func_stability(),
    true,
    ARRAY[
      'INSERT INTO ' || notes_table_name_($1) || ' VALUES ('
      || list_args_with_array(
           ARRAY[ meta_column('note_id', 'attributed_note_ids') ] || $2
	 )
      || ')',
      'SELECT $1'
    ]
  )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION create_func_add_note_for(regclass, meta_columns[])
RETURNS regprocedure AS $$
  SELECT create_func(
    meta_func_add_note_for($1, $2),
    'create note for row of ' || $1::text || ' given the primary field values'
  )
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION meta_func_del_note_for(regclass, meta_columns[])
RETURNS meta_funcs AS $$
  SELECT meta_func(
    true,
    notes_del_func_name_($1),
    ARRAY[ meta_arg('note_id', 'attributed_note_ids') ]
    || meta_cols_meta_arg_array($2),
    'void',
    false,
    'meta_func_sql_',
    meta_func_stability(),
    true,
    ARRAY[
      'DELETE FROM ' || notes_table_name_($1) || ' WHERE '
      || equate_args_with_array(
	   ARRAY[ meta_column('note_id', 'attributed_note_ids') ] || $2
         ),
      'SELECT $1'
    ]
  )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION create_func_del_note_for(regclass, meta_columns[])
RETURNS regprocedure AS $$
  SELECT create_func(
    meta_func_del_note_for($1, $2),
    'create note for row of ' || $1::text || ' given the primary field values'
  )
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION meta_func_note_set_for(regclass, meta_columns[])
RETURNS meta_funcs AS $$
  SELECT meta_func(
    true,
    notes_set_func_name_($1),
    meta_cols_meta_arg_array($2),
    'attributed_note_ids',
    true,
    'meta_func_sql_',
    meta_func_stability(),
    true,
    ARRAY[
      'SELECT note_id FROM ' || notes_table_name_($1)
      || E'\nWHERE ' || equate_args_with_array($2)
    ]
  )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION create_func_note_set_for(regclass, meta_columns[])
RETURNS regprocedure AS $$
  SELECT create_func(
    meta_func_note_set_for($1, $2),
    'return SETOF notes for a row of ' || $1::text || ' given the primary field values'
  )
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION meta_func_note_array_for(regclass, meta_columns[])
RETURNS meta_funcs AS $$
  SELECT meta_func(
    true,
    notes_array_func_name_($1),
    args,
    'attributed_note_id_arrays',
    false,
    'meta_func_sql_',
    meta_func_stability(),
    true,
    ARRAY[
      E'SELECT sort_notes_by_time( ARRAY(\n'
        '  SELECT id::integer FROM ' || notes_set_func_name_($1)
	|| '(' || list_args_with_array(args) || E') id\n' ||
      ')::attributed_note_id_arrays )'
    ]
  )
  FROM meta_cols_meta_arg_array($2) args
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION create_func_note_array_for(regclass, meta_columns[])
RETURNS regprocedure AS $$
  SELECT create_func(
    meta_func_note_array_for($1, $2),
    'return array of notes for a row of ' || $1::text || ' given the primary field values'
  )
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION notes_for(regclass) RETURNS tables_procs AS $$
  SELECT
    ARRAY[ create_notes_table_for($1, colms) ],
    ARRAY[ create_func_add_note_for($1, colms),
	   create_func_add_note_for($1, colms),
	   create_func_note_set_for($1, colms),
	   create_func_note_array_for($1, colms)
    ]
  FROM primary_meta_column_array($1) colms
$$ LANGUAGE SQL STRICT;
COMMENT ON FUNCTION notes_for(regclass) IS
'Creates an associated row_notes table with service functions.';

-- * Provides

-- SELECT module_provides('notes_on(regclass, integer)'::regprocedure);
-- SELECT module_provides('note_on(regclass, integer, note_author_ids, text)'::regprocedure);
-- SELECT module_provides('note_on(regclass, integer, text, text)'::regprocedure);
