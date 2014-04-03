-- * Header  -*-Mode: sql;-*-
-- SELECT module_file_id('utility_meta_schema.sql', '$Id: util_meta_schema.sql,v 1.1 2008/11/15 08:17:59 greg Exp greg $');

--	PostgreSQL Metaprogramming Utilities Schema

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

-- SELECT module_requires('util-modules-schema-code');

-- This module provides machinery for creating PostgreSQL
-- entities from specifications.  Currently supports the
-- creation of tables and functions with most features.

-- * creating comments

-- You can have a lot of different kinds of entities in a PostgreSQL
-- database, and you can attach comments to most of them.  For a list
-- of all the entities which can take comments, see the COMMENT ON
-- command in the PostgreSQL manual.

CREATE TYPE meta_entities AS ENUM (
	'meta_arg_',
	'meta_cast_',
	'meta_column_',
	'meta_constraint_',
	'meta_domain_',
	'meta_function_',
	'meta_op_class_',
	'meta_op_family_',
	'meta_operator_',
	'meta_sequence_',
	'meta_table_',
	'meta_type_',
	'meta_view_'
);
COMMENT ON TYPE meta_entities IS
'an enumeration of PostgreSQL metaprogrammable entities';

-- To be able to generate comments automatically, we'll need to know
-- the proper name of each kind of entity.  It's possible that we may
-- want to use this table to hold additional traits for purposes other
-- than generating comments, so perhaps more columns will be added
-- later.  We might then want to add some of the PostgreSQL entities
-- which do not support comments, e.g. function arguments.  Looking
-- ahead, the commentable field will allow us to know if PostgreSQL
-- can store comments for the corresponding entity.

CREATE TABLE meta_entity_traits (
  entity meta_entities PRIMARY KEY,
  name text UNIQUE,
  commentable bool NOT NULL DEFAULT true
);
COMMENT ON TABLE meta_entity_traits IS
'associates key properties with meta_entities';
COMMENT ON COLUMN meta_entity_traits.commentable IS
'is this entity supported by PostgreSQL COMMENT ON';

INSERT INTO meta_entity_traits(entity, name, commentable) VALUES
	( 'meta_arg_', NULL, false );

INSERT INTO meta_entity_traits(entity, name) VALUES
	( 'meta_cast_', 'CAST' ),
	( 'meta_column_', 'COLUMN' ),
	( 'meta_constraint_', 'CONSTRAINT' ),
	( 'meta_domain_', 'DOMAIN' ),
	( 'meta_function_', 'FUNCTION' ),
	( 'meta_op_class_', 'OPERATOR CLASS' ),
	( 'meta_op_family_', 'OPERATOR FAMILY' ),
	( 'meta_operator_', 'OPERATOR' ),
	( 'meta_sequence_', 'SEQUENCE' ),
	( 'meta_table_', 'TABLE' ),
	( 'meta_type_', 'TYPE' ),
	( 'meta_view_', 'VIEW' );

-- * meta support

CREATE TABLE name_type_pairs (
  name_ text,
  type_ regtype NOT NULL
);
COMMENT ON TABLE name_type_pairs IS
'Base type for meta_args and meta_columns.';
COMMENT ON COLUMN name_type_pairs.name_ IS
'Either arg_names or column_names';

-- * creating functions

-- ** function arguments

CREATE TYPE meta_argmodes AS ENUM (
	'meta_argmodes_in_',
	'meta_argmodes_out_',
	'meta_argmodes_inout_'
);

CREATE DOMAIN arg_names AS TEXT NOT NULL;
CREATE DOMAIN maybe_arg_names AS TEXT;
CREATE DOMAIN arg_name_arrays AS TEXT[] NOT NULL;

CREATE TABLE meta_args (
  mode_ meta_argmodes
) INHERITS(name_type_pairs);

-- ** individual function features

CREATE TYPE meta_func_stabilities AS ENUM (
	'meta_func_volatile_',	-- the default
	'meta_func_stable_',
	'meta_func_immutable_'
);

CREATE FUNCTION meta_func_stability() RETURNS meta_func_stabilities AS $$
  SELECT 'meta_func_volatile_'::meta_func_stabilities
$$ LANGUAGE sql IMMUTABLE;

CREATE TYPE meta_func_securities AS ENUM (
  'meta_func_invoker_',	-- the default
  'meta_func_definer_',	-- PostgreSQL alternative
  'meta_func_ext_invoker_', -- SAME AS 'meta_func_invoker_' in pgsql <= 8.4
  'meta_func_ext_definer_' -- SAME AS 'meta_func_definer_' in pgsql <= 8.4
);

CREATE FUNCTION meta_func_security() RETURNS meta_func_securities AS $$
  SELECT 'meta_func_invoker_'::meta_func_securities
$$ LANGUAGE sql IMMUTABLE;

CREATE TYPE meta_func_langs AS ENUM (
	'meta_func_sql_',
	'meta_func_plpgsql_',
	'meta_func_tcl_',
	'meta_func_c_'
);

CREATE TABLE meta_func_langs_names (
	lang meta_func_langs PRIMARY KEY,
	name text UNIQUE NOT NULL,
	named_args bool NOT NULL
);

INSERT INTO meta_func_langs_names(lang, name, named_args) VALUES
	( 'meta_func_sql_', 'sql', false ),
	( 'meta_func_plpgsql_', 'plpgsql', true ),
	( 'meta_func_tcl_', 'tcl', false ), -- is this true ???
	( 'meta_func_c_', 'c', false );	    -- is this true ???

CREATE TYPE meta_func_set_vars AS (
--  var_name text NOT NULL,	-- reference a system table?
  var_name text,		-- reference a system table?
  var_val text			-- 'FROM LOCAL' is special here
);

CREATE DOMAIN meta_func_bodies AS text[];

-- ** meta_funcs: putting it all together

CREATE TABLE meta_funcs (
  replace_ boolean NOT NULL default true,
  name_ text NOT NULL,
  args meta_args[] NOT NULL,
  returns_ regtype DEFAULT 'void',
  returns_set bool NOT NULL DEFAULT false,
  CHECK( NOT returns_set OR returns_ IS NOT NULL  ),
  lang meta_func_langs,
  stability meta_func_stabilities DEFAULT meta_func_stability(),
  strict_ bool DEFAULT false,
  security_ meta_func_securities NOT NULL DEFAULT meta_func_security(),
  cost integer,
  rows_ integer,
  CHECK( rows_ IS NULL OR returns_set IS NOT NULL  ),
  set_vars meta_func_set_vars[],
  body meta_func_bodies,
  obj_file text,
  CHECK( obj_file IS NULL OR body IS NOT NULL  ),
  link_symbol text,
  CHECK( link_symbol IS NULL OR obj_file IS NOT NULL  )
);
COMMENT ON TABLE meta_funcs IS
'Probably just want a TYPE here, but then we couldn''t express all of
the constraints which hopefully PostgreSQL will eventually enforce for
types as it enforces for tables.  It would also be great to be able
to specify UNIQUE(name_, meta_args_types(args)).';

SELECT abstract_trigger_for('meta_funcs');

-- * creating composite types and tables

CREATE DOMAIN table_spaces AS TEXT NOT NULL;
CREATE DOMAIN maybe_table_spaces AS TEXT;

CREATE DOMAIN column_names AS TEXT NOT NULL;
CREATE DOMAIN maybe_column_names AS TEXT;
-- CREATE DOMAIN column_name_arrays AS TEXT[] NOT NULL;
-- NOT NULL constraint gave error:
-- ERROR:  23502: domain column_name_arrays does not allow null values
-- CONTEXT:  PL/pgSQL function "create_table" while storing call arguments into local variables
-- LOCATION:  domain_check_input, domains.c:128
CREATE DOMAIN column_name_arrays AS TEXT[];

-- ** constraints

CREATE TYPE constraint_deferrings AS ENUM (
	'constraint_not_deferrable_', -- the default
	'constraint_immediate_',      -- the default if DEFERRABLE
	'constraint_deferred_'
);
COMMENT ON TYPE constraint_deferrings IS
'is a constraint deferrable, and if so, how';

CREATE FUNCTION constraint_deferring() RETURNS constraint_deferrings AS $$
  SELECT 'constraint_not_deferrable_'::constraint_deferrings
$$ LANGUAGE sql IMMUTABLE;


CREATE TABLE abstract_constraints (
  cnst_name text,		-- optional constraint name
  cols column_name_arrays,	-- optional columns
  defer_ constraint_deferrings NOT NULL DEFAULT 'constraint_not_deferrable_'
);

CREATE DOMAIN check_constraint_exprs AS TEXT NOT NULL;
COMMENT ON DOMAIN check_constraint_exprs IS
'an expression yielding bool suitable as a check constraint';

SELECT abstract_trigger_for('abstract_constraints');

CREATE TABLE check_constraints (
  check_ check_constraint_exprs NOT NULL
) INHERITS (abstract_constraints);

SELECT abstract_trigger_for('check_constraints');

CREATE TYPE storage_vars_vals AS (
  var_name TEXT,		-- can I just ref a system table?
  var_val TEXT
);

CREATE TABLE index_constraints (
  withs storage_vars_vals[],
  space_ maybe_table_spaces
) INHERITS (abstract_constraints);

SELECT abstract_trigger_for('index_constraints');

CREATE TYPE foreign_key_matchings AS ENUM (
	'foreign_key_match_simple_', -- the default
	'foreign_key_match_full_',
	'foreign_key_match_partial_'
);
COMMENT ON TYPE foreign_key_matchings IS
'matching strategies for foreign key constraints';

CREATE FUNCTION foreign_key_matching() RETURNS foreign_key_matchings AS $$
  SELECT 'foreign_key_match_simple_'::foreign_key_matchings
$$ LANGUAGE sql IMMUTABLE;


CREATE TYPE foreign_key_actions AS ENUM (
	'foreign_key_error_',	-- the default "NO ACTION"
	'foreign_key_restrict_',
	'foreign_key_cascade_',
	'foreign_key_set_null_',
	'foreign_key_set_default_'
);
COMMENT ON TYPE foreign_key_actions IS
'action to perform when foreign key is broken';

CREATE FUNCTION foreign_key_action() RETURNS foreign_key_actions AS $$
  SELECT 'foreign_key_error_'::foreign_key_actions
$$ LANGUAGE sql IMMUTABLE;

CREATE TABLE meta_foreign_keys (
  forn_table regclass NOT NULL,
  forn_cols column_name_arrays,
  matching foreign_key_matchings
    NOT NULL DEFAULT foreign_key_matching(),
  deleting foreign_key_actions
    NOT NULL DEFAULT foreign_key_action(),
  updating foreign_key_actions
    NOT NULL DEFAULT foreign_key_action()
) INHERITS (abstract_constraints);

SELECT abstract_trigger_for('meta_foreign_keys');

-- ** TYPE meta_columns

CREATE DOMAIN sql_exprs AS TEXT NOT NULL;
COMMENT ON DOMAIN sql_exprs IS
'an sql expression yielding a value';
CREATE DOMAIN maybe_sql_exprs AS TEXT;

CREATE TABLE meta_columns (
  default_ maybe_sql_exprs,
  not_null boolean,
  comment_ text
) INHERITS (name_type_pairs);
COMMENT ON TABLE meta_columns IS
'describes a single row of a PostgreSQL table';


-- *** meta_temp_tables

-- *** meta_temp_tables


CREATE TYPE meta_temp_tables AS ENUM (
	'temp_table_false_',	-- not a temp table
	'temp_table_preserve_',	-- temp table default
	'temp_table_delete_',
	'temp_table_drop_'
);


-- ** meta_types

CREATE TABLE meta_composite_types (
  name_ text NOT NULL,
  cols meta_columns[] NOT NULL,
  comment_ text
);
COMMENT ON TABLE meta_composite_types IS
'  A model for PostgreSQL composite types created along with tables or
created with "CREATE TYPE ... AS".  Currently PostgreSQL types do not
support all of the integrity constraints which tables support.  Should
such features be added in later versions of PostgreSQL, they can
simply be moved from meta_tables to meta_composite_types.
  Ironically this table is being created just for its type, so that we
can use the richer featureset of tables to get the types we want,
e.g. inheritance.
  Although bettern than what is available for types, the constraint
system for tables is also too limited to allow the expression of
all of the needed constraints, e.g. requiring that the names of
columns in a meta_columns array be unique.  For this reason, constructor
functions should be provided for creating all instances of types.';

SELECT abstract_trigger_for('meta_composite_types');

-- ** meta_tables

CREATE TABLE meta_tables (
  checks check_constraints[],
  primary_key index_constraints,
  uniques index_constraints[],
  forn_keys meta_foreign_keys[],
  inherits_ regclass[],
  with_oids boolean NOT NULL default false,
  temp_ meta_temp_tables NOT NULL default 'temp_table_false_',
  space_ maybe_table_spaces,
  withs storage_vars_vals[]
-- currently unimplemented features:
--  likes meta_table_likes[],		-- a poor substitute for inherits?
--  local_ bool NOT NULL DEFAULT false,	-- does nothing in PostgreSQL
) INHERITS (meta_composite_types);
COMMENT ON TABLE meta_tables IS
'See the "COMMENT ON TABLE meta_composite_types".  Given the limitations
on table constraints it is essential to provide and use constructor
functions for all table insertions and mutator functions for all
table updates.';

SELECT abstract_trigger_for('meta_tables');
