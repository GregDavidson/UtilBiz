-- * Header  -*-Mode: sql;-*-
-- SELECT module_file_id('utility-meta_code.sql', '$Id: util_meta_code.sql,v 1.1 2008/11/15 08:18:16 greg Exp greg $');
--    (setq outline-regexp "^--[ \t]+[*+-~=]+ ")
--    (outline-minor-mode)

--	PostgreSQL Metaprogramming Utilities Code

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

-- * a few handy functions first

CREATE OR REPLACE
FUNCTION maybe_array(ANYELEMENT) RETURNS ANYARRAY AS $$
  SELECT ARRAY(SELECT $1 WHERE $1 IS NOT NULL)
$$ LANGUAGE sql;
COMMENT ON FUNCTION maybe_array(ANYELEMENT) IS
'return an empty array or a singleton';

CREATE OR REPLACE
FUNCTION maybe_text(text, text, text, text) RETURNS text AS $$
  SELECT COALESCE( $1 || $2 || $3,  $4  )
$$ LANGUAGE sql;
COMMENT ON FUNCTION maybe_text(text, text, text, text) IS
'maybe_text(prefix, maybe text, suffix, alternative) -> coalesced text';

CREATE OR REPLACE
FUNCTION maybe_text(text, text[], text, text, text) RETURNS text AS $$
  SELECT CASE WHEN array_is_empty($2) THEN $5
         ELSE $1 || array_to_string($2, $3) || $4
  END
$$ LANGUAGE sql;
COMMENT ON FUNCTION maybe_text(text, text[], text, text, text) IS
'maybe_text(prefix, maybe text array, text to interpose, suffix, alternative)
-> coalesced array_to_string text';

-- * comments

CREATE OR REPLACE
FUNCTION entity_text(meta_entities) RETURNS text AS $$
  SELECT name FROM meta_entity_traits WHERE entity = $1
$$ LANGUAGE sql STRICT IMMUTABLE;

-- could later do some formatting of the comment body, allow markup, etc.
-- could create versions using the proper oid for the entity
CREATE OR REPLACE
FUNCTION comment_text(meta_entities, text, text) RETURNS text AS $$
  SELECT E'\nCOMMENT ON ' || entity_text($1) || ' ' || $2
  || E' IS\n' || quote_literal($3) || E';\n'
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION comment_text(meta_entities, text, text) IS
'comment_text(entity kind, entity name, comment) -->
text for creating a comment on the given entity';

CREATE OR REPLACE
FUNCTION comment_(meta_entities, text, text) RETURNS text AS $$
DECLARE
  entity_str TEXT := entity_text($1);
  comment_str TEXT := comment_text($1, $2, $3);
BEGIN
  EXECUTE comment_str;
  RETURN entity_str || ' ' || $2 || E'\n\t' || $3;
END
$$ LANGUAGE plpgsql STRICT;

-- use comment_ to generate a comment on itself:
SELECT comment_(
  'meta_function_',			 -- kind of comment
  'comment_(meta_entities, text, text)', -- function signature
  'creates comment in database'		 -- comment
);

-- comment_*: a family of convenience functions

CREATE OR REPLACE
FUNCTION comment_func(regprocedure, text) RETURNS text AS $$
  SELECT comment_('meta_function_', $1::text, $2)
$$ LANGUAGE sql STRICT;

-- use create_ to generate a comment on itself:
SELECT comment_func(
  'comment_func(regprocedure, text)',
  'creates a comment on a function'
);

CREATE OR REPLACE
FUNCTION comment_table(regclass, text) RETURNS text AS $$
  SELECT comment_('meta_table_', $1::text, $2)
$$ LANGUAGE sql STRICT;

SELECT comment_func(
  'comment_table(regclass, text)',
  'creates a comment on a table'
);

CREATE OR REPLACE
FUNCTION comment_column(regclass, text, text) RETURNS text AS $$
  SELECT comment_('meta_column_', $1::text || '.' || $2, $3)
$$ LANGUAGE sql STRICT;

SELECT comment_func(
  'comment_column(regclass, text, text)',
  'creates a comment on a column'
);

CREATE OR REPLACE
FUNCTION comment_type(regtype, text) RETURNS text AS $$
  SELECT comment_('meta_type_', $1::text, $2)
$$ LANGUAGE sql STRICT;

SELECT comment_func(
  'comment_type(regtype, text)',
  'creates a comment on a type'
);

-- * functions

-- ** function arguments

-- meta_arg(name, type, mode) 
CREATE OR REPLACE
FUNCTION meta_arg(arg_names, regtype, meta_argmodes) RETURNS meta_args AS $$
  SELECT ROW($1, $2, $3)::meta_args
$$ LANGUAGE sql STRICT;

-- meta_arg(name, type) 
CREATE OR REPLACE
FUNCTION meta_arg(arg_names, regtype) RETURNS meta_args AS $$
  SELECT meta_arg($1, $2, 'meta_argmodes_in_')
$$ LANGUAGE sql STRICT;

-- arg_text(argument description, show names?) 
CREATE OR REPLACE
FUNCTION arg_text(meta_args, bool) RETURNS text AS $$
  SELECT
    CASE ($1).mode_
      WHEN 'meta_argmodes_out_' THEN 'OUT '
      WHEN 'meta_argmodes_inout_' THEN 'INOUT '
      ELSE ''
    END ||
    CASE
      WHEN NOT ($2 AND ($1).name_ IS NOT NULL) THEN ''
      ELSE ($1).name_::text || ' '
    END ||
    ($1).type_::text		-- must not be null!!
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION meta_args_name_set(meta_args[]) RETURNS SETOF arg_names AS $$
  SELECT (c).name_::arg_names FROM array_to_list($1) c
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION meta_args_name_array(meta_args[]) RETURNS arg_name_arrays AS $$
  SELECT ARRAY(SELECT meta_args_name_set($1)::text)::arg_name_arrays
$$ LANGUAGE sql STRICT;

-- ** function languages

CREATE OR REPLACE
FUNCTION meta_func_lang_text(meta_func_langs) RETURNS text AS $$
  SELECT quote_literal(name) FROM meta_func_langs_names WHERE lang = $1
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION meta_func_lang_named_args(meta_func_langs) RETURNS bool AS $$
  SELECT named_args FROM meta_func_langs_names WHERE lang = $1
$$ LANGUAGE sql STRICT IMMUTABLE;
	
-- ** function headers

-- policy on newlines could become more flexible (and tidy)
-- might require more arguments - is it worth it???
CREATE OR REPLACE
FUNCTION meta_func_head_text(text, meta_args[], bool) RETURNS text AS $$
  SELECT $1 || '('
  || CASE WHEN $3 AND length(arg_string) > 60 THEN E'\n' ELSE '' END
  || arg_string
  || CASE WHEN $3 AND length(arg_string) > 60 THEN E'\n' ELSE '' END
  || ')'
  FROM array_to_string( ARRAY(
       SELECT arg_text(meta_arg, $3) FROM array_to_list($2) meta_arg
  ), ', ' ) arg_string
$$ LANGUAGE sql;
COMMENT ON FUNCTION meta_func_head_text(text, meta_args[], bool) IS
'(name, args, show arg names) -> name([arg name] arg_type, ...)';

CREATE OR REPLACE
FUNCTION func_head_comment_text(regproc, meta_args[]) RETURNS text AS $$
  SELECT $1::text || '(' || arg_string || ')'
  FROM array_to_string( ARRAY(
       SELECT (meta_arg).name_::text FROM array_to_list($2) meta_arg
  ), ', ' ) arg_string
$$ LANGUAGE sql;
COMMENT ON FUNCTION meta_func_head_text(text, meta_args[], bool) IS
'(name, args) -> name(arg name, ...)';

-- ** more function features

CREATE OR REPLACE
FUNCTION meta_func_create_text(boolean) RETURNS text AS $$
  SELECT 'CREATE '
    || CASE WHEN $1 THEN ' OR REPLACE' ELSE '' END
    || E'\nFUNCTION '
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION meta_func_returns_text(regtype, bool) RETURNS text AS $$
  SELECT 'RETURNS '
  || CASE WHEN $2 THEN 'SETOF ' ELSE '' END
  || COALESCE($1::text, 'void')
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION meta_func_strictness_text(bool) RETURNS text AS $$
  SELECT CASE WHEN $1 IS NOT NULL AND $1 THEN ' STRICT' ELSE '' END
$$ LANGUAGE sql STRICT IMMUTABLE;


CREATE OR REPLACE
FUNCTION meta_func_stability_text(meta_func_stabilities) RETURNS text AS $$
  SELECT CASE $1
    WHEN 'meta_func_volatile_' THEN '' -- VOLATILE is the default
    WHEN 'meta_func_stable_' THEN ' STABLE'
    WHEN 'meta_func_immutable_' THEN ' IMMUTABLE'
  END
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION meta_func_security_text(meta_func_securities) RETURNS text AS $$
  SELECT CASE $1
    WHEN 'meta_func_invoker_' THEN '' -- SECURITY INVOKER is the default
    WHEN 'meta_func_definer_' THEN ' SECURITY DEFINER'
    WHEN 'meta_func_ext_invoker_' THEN ' SECURITY EXTERNAL INVOKER'
    WHEN 'meta_func_ext_definer_' THEN ' SECURITY EXTERNAL DEFINER'
  END
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION maybe_func_cost_text(integer) RETURNS text AS $$
  SELECT maybe_text(E'\nCOST ', $1::text, E'\n', '')
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE
FUNCTION meta_func_rows_text(integer, bool) RETURNS text AS $$
  SELECT E'\nROWS '|| $1::text || E'\n'
  WHERE $2			--  WHERE assert($2)
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION maybe_func_rows_text(integer, bool) RETURNS text AS $$
  SELECT maybe_text(E'\nROWS ', meta_func_rows_text($1, $2), E'\n', '')
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE
FUNCTION maybe_func_set_vars_text(meta_func_set_vars[]) RETURNS text AS $$
  SELECT maybe_text(
    '',				-- prefix
    ARRAY(
      SELECT '  SET ' || (vv).var_name
      || CASE WHEN (vv).var_val IS NULL THEN ''
              WHEN (vv).var_val = 'FROM LOCAL'
	      THEN ' FROM LOCAL'
	      ELSE ' TO' || quote_literal( (vv).var_val )
         END
      FROM array_to_list($1) vv
    ),
    E'\n',			-- inbetween elements
    '',				-- suffix
    ''				-- alternative if none
  )
$$ LANGUAGE sql;		-- IMMUTABLE

-- What does plpgsql do if extra semicolons wind up following
-- words like DECLARE, BEGIN, EXCEPTION which were treated as
-- statements?
CREATE OR REPLACE
FUNCTION meta_func_body_text(meta_func_bodies) RETURNS text AS $$
  SELECT quote_literal(array_to_string($1, E';\n'))
$$ LANGUAGE sql STRICT;		-- IMMUTABLE
COMMENT ON FUNCTION meta_func_body_text(meta_func_bodies) IS
'converts an array of statements into a legal function body;
it would be nice to do this for a (molecular) parse tree';

CREATE OR REPLACE
FUNCTION meta_func_linkage_text(text, text) RETURNS text AS $$
  SELECT quote_literal( $1 )	-- $1 must not be null
       || CASE WHEN $2 IS NULL THEN ''
          ELSE quote_literal( ', ' || $2 )
          END
$$ LANGUAGE sql;		-- IMMUTABLE
COMMENT ON FUNCTION meta_func_linkage_text(text, text) IS
'AS object_file, link_symbol where link_symbol is optional';

-- meta_func_text(meta_funcs)
CREATE OR REPLACE
FUNCTION meta_func_text(meta_funcs) RETURNS text AS $$
  SELECT meta_func_create_text( ($1).replace_ )
  || meta_func_head_text(($1).name_, ($1).args, meta_func_lang_named_args(($1).lang))
  || E'\n' || meta_func_returns_text(($1).returns_, ($1).returns_set) 
  || ' LANGUAGE ' || meta_func_lang_text( ($1).lang )
  || meta_func_stability_text( ($1).stability )
  || meta_func_strictness_text( ($1).strict_ )
  || meta_func_security_text( ($1).security_ )
  || maybe_func_cost_text( ($1).cost )
  || maybe_func_rows_text( ($1).rows_, ($1).returns_set )
  || maybe_func_set_vars_text( ($1).set_vars )
  || E' AS\n'
  || CASE WHEN ($1).body IS NOT NULL
     THEN meta_func_body_text( ($1).body )
     ELSE meta_func_linkage_text( ($1).obj_file, ($1).link_symbol )
     END
  || E';\n'
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION meta_func_text(meta_funcs) IS
'turns a description of a function into text which would define that function';

CREATE OR REPLACE
FUNCTION meta_func(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool, meta_func_securities,
  integer, integer, meta_func_set_vars[],
  meta_func_bodies
) RETURNS meta_funcs AS $$
  SELECT ROW($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NULL,NULL)::meta_funcs
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION meta_func(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool, meta_func_securities,
  integer, integer, meta_func_set_vars[],
  meta_func_bodies
) IS '(replace?, name, args, return type, returns_set?, lang,
stability, strict?, security, cost, rows, set config vars, BODY) ->
meta_funcs row';

CREATE OR REPLACE
FUNCTION meta_func(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool, meta_func_bodies
) RETURNS meta_funcs AS $$
  SELECT ROW($1,$2,$3,$4,$5,$6,$7,$8,'meta_func_invoker_',NULL,NULL,NULL,$9,NULL,NULL)::meta_funcs
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION meta_func(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool, meta_func_bodies
) IS '(replace?, name, args, return type, returns_set?, lang,
stability, strict?, BODY) -> meta_funcs row';


CREATE OR REPLACE
FUNCTION meta_func(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool, meta_func_securities,
  integer, integer, meta_func_set_vars[],
  text, text
) RETURNS meta_funcs AS $$
  SELECT ROW($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,NULL,$13,$14)::meta_funcs
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION meta_func(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool, meta_func_securities,
  integer, integer, meta_func_set_vars[],
  text, text
) IS '(replace?, name, args, return type, returns_set?, lang,
stability, strict?, security, cost, rows, set config vars,
OBJECT FILE NAME, LINK SYMBOL) -> meta_funcs row';

-- meta_func(
--   replace_, name_,  args,
--   returns_, returns_set, lang,
--   stability, strict_, obj_file
-- )
CREATE OR REPLACE
FUNCTION meta_func(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool, text
) RETURNS meta_funcs AS $$
  SELECT ROW($1,$2,$3,$4,$5,$6,$7,$8,NULL,NULL,NULL,NULL,NULL,$9,NULL)::meta_funcs
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION meta_func(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool, text
) IS '(replace?, name, args, return type, returns_set?, lang,
stability, strict?, OBJECT FILE) -> meta_funcs row';

CREATE OR REPLACE
FUNCTION func_comment_text(regprocedure, meta_args[], text) RETURNS text AS $$
  SELECT comment_text('meta_function_', $1::text,
    func_head_comment_text($1, $2)
    || CASE WHEN $3 IS NOT NULL AND $3 != '' THEN ': ' || $3 ELSE '' END
  )
$$ LANGUAGE sql;
COMMENT ON FUNCTION func_comment_text(regprocedure, meta_args[], text) IS
'returns text for creating a comment starting with the function and argument names';

CREATE OR REPLACE
FUNCTION create_func_comment(
  func regprocedure,
  args meta_args[],
  comment_ text
) RETURNS regprocedure AS $$
BEGIN
  EXECUTE func_comment_text($1, $2, $3);
  RETURN $1;
END
$$ LANGUAGE plpgsql;

SELECT create_func_comment(
  'create_func_comment(regprocedure, meta_args[], text)',
  ARRAY[
     meta_arg('func', 'regprocedure'),
     meta_arg('args', 'meta_args[]'),
     meta_arg('comment', 'text')
   ],
'creating a comment starting with the function and argument names'
);

CREATE OR REPLACE
FUNCTION create_func(meta_funcs, comment_ text) RETURNS regprocedure AS $$
DECLARE
  the_funcoid regprocedure;
BEGIN
-- should check if the func already exists
-- can do a drop cascade if desired!
  EXECUTE meta_func_text($1);
  EXECUTE 'SELECT '
    || quote_literal(meta_func_head_text(($1).name_, ($1).args, false))
    || '::regprocedure'
  INTO the_funcoid;
  EXECUTE func_comment_text(the_funcoid, ($1).args, $2);
  RETURN the_funcoid;
END
$$ LANGUAGE plpgsql STRICT;
COMMENT ON FUNCTION create_func(meta_funcs, comment_ text) IS
'create the described function and a comment on it; return its oid';

CREATE OR REPLACE
FUNCTION create_func(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool,
  meta_func_bodies, text) RETURNS regprocedure AS $$
  SELECT create_func(
    meta_func($1, $2, $3, $4, $5, $6, $7, $8, $9),
    $10
  )
$$ LANGUAGE sql;
COMMENT ON FUNCTION create_func(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool,
  meta_func_bodies, text
) IS '(replace_, name_, args, returns_, returns_set, lang, stability,
 strict_, security_, cost, rows_, set_vars, body, comment) -> CREATE &
 COMMENT ON FUNCTION name';

CREATE OR REPLACE
FUNCTION create_func_linkage(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool, text,
  text
) RETURNS regprocedure AS $$
  SELECT create_func( meta_func($1, $2, $3, $4, $5, $6, $7, $8, $9), $10 )
$$ LANGUAGE sql;
COMMENT ON FUNCTION create_func_linkage(
  boolean, text, meta_args[],
  regtype, bool, meta_func_langs,
  meta_func_stabilities, bool, text,
  text
) IS '(replace_, name_, args, returns_, returns_set, lang, stability,
strict_, security_, cost, rows_, set_vars, obj_file, comment) ->
CREATE & COMMENT ON linkage to external function';

-- * composite types and tables

CREATE OR REPLACE
FUNCTION column_name_array_text(column_name_arrays) RETURNS text AS $$
  SELECT maybe_text( '(' , $1 , ', ' , ')' , '' )
$$ LANGUAGE sql;

-- ** constraints

CREATE OR REPLACE
FUNCTION is_table_constraint(abstract_constraints) RETURNS boolean AS $$
  SELECT ($1).cnst_name IS NOT NULL OR array_length(($1).cols) != 1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION is_column_constraint(column_names, abstract_constraints)
RETURNS boolean AS $$
  SELECT ($2).cols IS NOT NULL AND NOT is_table_constraint($2)
  AND array_length( ($2).cols ) = 1
  AND ($2).cols[1]::column_names = $1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION constraint_name_text(text) RETURNS text AS $$
  SELECT maybe_text( 'CONSTRAINT ', $1, '', '' )
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION constraint_name_text(abstract_constraints) RETURNS text AS $$
  SELECT constraint_name_text( ($1).cnst_name )
$$ LANGUAGE sql;


-- ** check constraints

CREATE OR REPLACE
FUNCTION check_constraint(
  text, column_name_arrays, constraint_deferrings, maybe_sql_exprs
) RETURNS check_constraints AS $$
  SELECT ROW(
    $1,				-- cnst_name
    CASE WHEN array_is_empty($2) THEN NULL::column_name_arrays
    ELSE $2 END,		-- cols
    CASE WHEN $3 IS NOT NULL THEN $3
    ELSE 'constraint_not_deferrable_' END, -- defer_
    $4					   -- check_
  )::check_constraints
$$ LANGUAGE sql;
COMMENT ON FUNCTION check_constraint(
  text, column_name_arrays, constraint_deferrings, maybe_sql_exprs
) IS
'We require the names of the columns referenced by the check constraint
in order to determine where to put the constraint in the code.';

CREATE OR REPLACE
FUNCTION check_constraint_text(check_constraints) RETURNS text AS $$
  SELECT constraint_name_text( ($1).cnst_name )
  || ' CHECK(' || ($1).check_ || ')'
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION table_check_constraint_texts(check_constraints[]) RETURNS text[] AS $$
  SELECT ARRAY(
    SELECT constraint_name_text(c) FROM array_to_list($1) c
    WHERE is_table_constraint(c)
  )
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION maybe_column_checks_text(column_names, check_constraints[])
RETURNS text AS $$
  SELECT maybe_text(
    'CHECK (',
    ARRAY(
      SELECT (cc).check_::text FROM array_to_list($2) cc
      WHERE is_column_constraint($1, cc)
    ),
    ') CHECK(',
    ')',
    ''
  )
$$ LANGUAGE sql;
COMMENT ON FUNCTION maybe_column_checks_text(column_names, check_constraints[]) IS
'text of any check constraints involving only the specified column';

-- ** index constraints

CREATE OR REPLACE
FUNCTION index_constraint(
  text, column_name_arrays, constraint_deferrings,
  storage_vars_vals[], maybe_table_spaces
) RETURNS index_constraints AS $$
  SELECT ROW(
    $1,				-- cnst_name
    CASE WHEN array_is_empty($2) THEN NULL::column_name_arrays
    ELSE $2 END,		-- cols
    CASE WHEN $3 IS NOT NULL THEN $3
    ELSE 'constraint_not_deferrable_' END, -- defer_
    CASE WHEN array_is_empty($4) THEN NULL::storage_vars_vals[]
    ELSE $4 END,		-- withs
    $5				-- space_
  )::index_constraints
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION index_constraint(
  text, column_name_arrays, constraint_deferrings
) RETURNS index_constraints AS $$
  SELECT ROW(
    $1,				-- cnst_name
    CASE WHEN array_is_empty($2) THEN NULL::column_name_arrays
    ELSE $2 END,		-- cols
    CASE WHEN $3 IS NOT NULL THEN $3
    ELSE 'constraint_not_deferrable_' END, -- defer_
    NULL::storage_vars_vals[],
    NULL::maybe_table_spaces
  )::index_constraints
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION index_withs_text(storage_vars_vals[]) RETURNS text AS $$
  SELECT maybe_text(
    ' WITH',				-- prefix
    ARRAY(
      SELECT ' ' || (vv).var_name || maybe_text('=', (vv).var_val, '', '')
      FROM array_to_list($1) vv
    ),
    E'\n\t',			-- inbetween elements
    '',				-- suffix
    ''				-- alternative if none
  )
$$ LANGUAGE sql;		-- IMMUTABLE

CREATE OR REPLACE
FUNCTION index_constraint_text(text, index_constraints) RETURNS text AS $$
  SELECT
  constraint_name_text($2)
  || ' ' || $1
  || column_name_array_text( ($2).cols )
  || index_withs_text( ($2).withs )
  || maybe_text( 'USING INDEX TABLESPACE ', ($2).space_::text, '', '' )
$$ LANGUAGE sql STRICT IMMUTABLE;
COMMENT ON FUNCTION index_constraint_text(text, index_constraints) IS
$$('UNIQUE'|'PRIMARY KEY', constraint) --> constraint definition$$;

-- *** primary key index constraints

-- CREATE OR REPLACE
-- FUNCTION table_primary_key_texts(index_constraints) RETURNS text[] AS $$
--   SELECT ARRAY(
--     SELECT index_constraint_text('PRIMARY KEY', $1)
--     WHERE is_table_constraint($1)
--   )
-- $$ LANGUAGE sql;
-- generates interesting bug; returns {NULL} rather than {}
-- which gives right result in an SQL context and 'PRIMARY KEY'
-- in a plpgsql context!!

CREATE OR REPLACE
FUNCTION table_primary_key_texts(index_constraints) RETURNS text[] AS $$
  SELECT CASE WHEN $1 IS NULL THEN '{}'::text[]
       WHEN NOT is_table_constraint($1) THEN '{}'::text[]
       ELSE ARRAY[index_constraint_text('PRIMARY KEY', $1)]
  END
$$ LANGUAGE sql;
COMMENT ON FUNCTION table_primary_key_texts(index_constraints) IS
'(constraint) --> empty array or singleton of multi-column primary key';

CREATE OR REPLACE
FUNCTION maybe_column_primary_text(column_names, index_constraints)
RETURNS text AS $$
  SELECT CASE WHEN is_column_constraint($1, $2)
    THEN ' PRIMARY KEY'
    ELSE ''
  END
$$ LANGUAGE sql;
COMMENT ON FUNCTION maybe_column_primary_text(column_names, index_constraints) IS
'''PRIMARY KEY'' if specified column is the indicated primary key';

-- *** unique index constraints

CREATE OR REPLACE
FUNCTION table_unique_constraint_texts(index_constraints[])
RETURNS text[] AS $$
  SELECT ARRAY(
    SELECT index_constraint_text('UNIQUE', c)
    FROM array_to_list($1) c
    WHERE is_table_constraint(c)
  )
$$ LANGUAGE sql;
COMMENT ON FUNCTION table_unique_constraint_texts(index_constraints[]) IS
'(constraint) --> empty array or singleton of multi-column primary key';

CREATE OR REPLACE
FUNCTION meta_column_unique_text(column_names, index_constraints[])
RETURNS text AS $$
  SELECT CASE
    WHEN true = SOME(
      SELECT is_column_constraint($1, c)
      FROM array_to_list($2) c
    )
    THEN ' UNIQUE'
    ELSE ''
  END
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION maybe_column_unique_text(column_names, index_constraints[])
RETURNS text AS $$
  SELECT COALESCE(meta_column_unique_text($1, $2), '')
$$ LANGUAGE sql;
COMMENT ON FUNCTION maybe_column_unique_text(column_names, index_constraints[]) IS
'''UNIQUE'' if specified column is in one of the specified constraints';

-- ** foreign key constraints

CREATE OR REPLACE
FUNCTION meta_foreign_key(
  text, column_name_arrays, constraint_deferrings,
  regclass, column_name_arrays, foreign_key_matchings,
  foreign_key_actions, foreign_key_actions
) RETURNS meta_foreign_keys AS $$
  SELECT ROW(
    $1, 			-- cnst_name
    CASE WHEN array_is_empty($2) THEN NULL::column_name_arrays
    ELSE $2 END,		-- cols
    CASE WHEN $3 IS NOT NULL THEN $3
    ELSE 'constraint_not_deferrable_' END, -- defer_
    $4,					   -- forn_table
    CASE WHEN array_is_empty($5) THEN NULL::column_name_arrays
    ELSE $5 END,		-- forn_cols
    CASE WHEN $6 IS NOT NULL THEN $6
    ELSE foreign_key_matching() END, -- matching
    CASE WHEN $7 IS NOT NULL THEN $7
    ELSE foreign_key_action() END, -- deleting
    CASE WHEN $8 IS NOT NULL THEN $8
    ELSE foreign_key_action() END -- updating
  )::meta_foreign_keys
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION foreign_key_matching_text(foreign_key_matchings)
RETURNS text AS $$
  SELECT CASE WHEN $1 IS NULL THEN ''
  ELSE CASE $1
    WHEN 'foreign_key_match_simple_' THEN ''
    WHEN 'foreign_key_match_full_' THEN ' MATCH FULL'
    WHEN 'foreign_key_match_partial_' THEN ' MATCH PARTIAL'
  END END
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION foreign_key_action_text(foreign_key_actions) RETURNS text AS $$
  SELECT CASE WHEN $1 IS NULL THEN NULL
  ELSE CASE $1
    WHEN 'foreign_key_error_' THEN NULL
    WHEN 'foreign_key_restrict_' THEN 'RESTRICT'
    WHEN 'foreign_key_cascade_' THEN 'CASCADE'
    WHEN 'foreign_key_set_null_' THEN 'SET NULL'
    WHEN 'foreign_key_set_default_' THEN 'SET DEFAULT'
  END END
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION foreign_key_action_text(text, foreign_key_actions) RETURNS text AS $$
  SELECT maybe_text($1 || ' ', foreign_key_action_text($2), '', '')
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION constraint_deferring_text(constraint_deferrings) RETURNS text AS $$
  SELECT CASE WHEN $1 IS NULL THEN ''
  ELSE CASE $1
    WHEN 'constraint_not_deferrable_' THEN ''
    WHEN 'constraint_immediate_' THEN ' DEFERRABLE'
    WHEN 'constraint_deferred_' THEN ' DEFERRABLE INITIALLY DEFERRED'
  END END
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION foreign_key_text(meta_foreign_keys) RETURNS text AS $$
  SELECT constraint_name_text( ($1).cnst_name )
  || ' FOREIGN KEY'
  || column_name_array_text( ($1).cols )
  || ' REFERENCES '
  || ($1).forn_table::text
  || column_name_array_text( ($1).forn_cols )
  || foreign_key_matching_text( ($1).matching )
  || foreign_key_action_text( 'ON DELETE', ($1).deleting )
  || foreign_key_action_text( 'ON UPDATE', ($1).updating )
  || constraint_deferring_text( ($1).defer_ )
$$ LANGUAGE sql STRICT IMMUTABLE;

-- ** TYPE meta_columns

CREATE OR REPLACE
FUNCTION meta_column(
  column_names, regtype, maybe_sql_exprs, boolean, text
) RETURNS meta_columns AS $$
  SELECT ROW(
    $1,						 -- name
    $2,						 -- type
    $3,						 -- maybe default
    CASE WHEN $4 IS NULL THEN false ELSE $4 END, -- not_null
    CASE WHEN $5 = '' THEN NULL ELSE $5 END -- comment_
  )::meta_columns
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION meta_column(column_names, regtype, text) RETURNS meta_columns AS $$
  SELECT meta_column(
    $1,				-- name_
    $2,				-- type_
    NULL,			-- default
    false,			-- not_null
    $3				-- comment_
  )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION meta_column(column_names, regtype) RETURNS meta_columns AS $$
  SELECT meta_column(
    $1,				-- name_
    $2,				-- type_
    NULL,			-- default_
    false,			-- not_null
    NULL			-- comment_
  )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION meta_cols_name_set(meta_columns[]) RETURNS SETOF column_names AS $$
  SELECT (c).name_::column_names FROM array_to_list($1) c
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION meta_cols_name_array(meta_columns[]) RETURNS column_name_arrays AS $$
  SELECT ARRAY(SELECT meta_cols_name_set($1)::text)::column_name_arrays
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION meta_cols_type_set(meta_columns[]) RETURNS SETOF regtype AS $$
  SELECT (c).type_ FROM array_to_list($1) c
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION meta_cols_type_array(meta_columns[]) RETURNS regtype[] AS $$
  SELECT ARRAY(SELECT meta_cols_type_set($1))
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION meta_cols_meta_arg_set(meta_columns[]) RETURNS SETOF meta_args AS $$
  SELECT meta_arg( (c).name_, (c).type_ ) FROM array_to_list($1) c
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION meta_cols_meta_arg_array(meta_columns[]) RETURNS meta_args[] AS $$
  SELECT ARRAY(SELECT meta_cols_meta_arg_set($1))
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION primary_meta_column_array(regclass) RETURNS meta_columns[] AS $$
  SELECT ARRAY(
    SELECT meta_column(attname::column_names, atttypid::regtype)
    FROM pg_attribute, pg_constraint
    WHERE attnum = SOME(conkey) AND attrelid = conrelid
      AND contype='p' AND  attrelid = $1
  )
$$ LANGUAGE 'sql' STRICT;

CREATE OR REPLACE
FUNCTION meta_cols_primary_key(meta_columns[]) RETURNS index_constraints AS $$
  SELECT index_constraint(NULL::text, meta_cols_name_array($1), constraint_deferring())
$$ LANGUAGE 'sql' STRICT;

CREATE OR REPLACE
FUNCTION meta_cols_forn_key(column_name_arrays, regclass, column_name_arrays)
RETURNS meta_foreign_keys AS $$
  SELECT meta_foreign_key(
    NULL::text,
    $1,				-- our columns
    constraint_deferring(),
    $2,				-- the foreign table
    $3,				-- the foreign columns
    foreign_key_matching(),
    foreign_key_action(),
    foreign_key_action()
  )
$$ LANGUAGE 'sql' STRICT;

CREATE OR REPLACE
FUNCTION get_primary_forn_keys(regclass) RETURNS meta_foreign_keys AS $$
  SELECT meta_cols_forn_key(colms, $1, colms)
  FROM meta_cols_name_array(primary_meta_column_array($1)) colms
$$ LANGUAGE 'sql' STRICT;

CREATE OR REPLACE
FUNCTION meta_column_text(meta_columns) RETURNS text AS $$
  SELECT ($1).name_::text || ' ' || ($1).type_::text
  || CASE WHEN ($1).not_null IS NULL OR NOT ($1).not_null THEN ''
     ELSE ' NOT NULL'
     END
  || maybe_text(' DEFAULT ', quote_literal(($1).default_), '', '')
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION meta_column_text(meta_columns) IS
'returns a textual description of one column of a table';

CREATE OR REPLACE
FUNCTION column_name_array(column_names) RETURNS column_name_arrays AS $$
  SELECT ARRAY[$1::text]::column_name_arrays
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION column_forn_key_text(meta_foreign_keys)
RETURNS text AS $$
  SELECT 'REFERENCES ' || ($1).forn_table::text
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION column_forn_key_text(meta_foreign_keys) IS
'a column references to the indicated foreign key';

CREATE OR REPLACE
FUNCTION maybe_column_forn_key_text(column_names, meta_foreign_keys[])
RETURNS text AS $$
  SELECT maybe_text(
    ' ', ARRAY(
      SELECT column_forn_key_text(ref) FROM array_to_list($2) ref
      WHERE (ref).cols = column_name_array($1)
    ), ' ', '', ''
  )
$$ LANGUAGE sql;
COMMENT ON FUNCTION maybe_column_forn_key_text(column_names, meta_foreign_keys[])
IS 'all foreign key references which only link to this column';

CREATE OR REPLACE
FUNCTION meta_column_texts(meta_columns[], meta_tables) RETURNS text[] AS $$
  SELECT ARRAY(
    SELECT meta_column_text(c)
    || maybe_column_checks_text( (c).name_, ($2).checks )
    || maybe_column_primary_text( (c).name_, ($2).primary_key )
    || maybe_column_unique_text( (c).name_, ($2).uniques )
    || maybe_column_forn_key_text( (c).name_, ($2).forn_keys )
    FROM array_to_list($1) c
  )
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION meta_column_texts(meta_columns[], meta_tables) IS
'returns a text array of descriptions of the columns of a table';

CREATE OR REPLACE
FUNCTION table_forn_key_texts(meta_foreign_keys[])
RETURNS text[] AS $$
  SELECT ARRAY(
    SELECT foreign_key_text(fk) FROM array_to_list($1) fk
    WHERE (fk).cnst_name IS NOT NULL OR array_length( (fk).cols ) > 1
  )
$$ LANGUAGE sql;
COMMENT ON FUNCTION table_forn_key_texts(meta_foreign_keys[]) IS
'returns text array declaring all multi-column foreign_keys';

-- ** meta_composite_type

CREATE OR REPLACE
FUNCTION meta_composite_type(
  text,				-- name_
  meta_columns[],		-- cols
  text				-- comment
) RETURNS meta_composite_types AS $$
  SELECT ROW($1,$2,$3)::meta_composite_types
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION meta_composite_type(text, meta_columns[], text)
IS '(name_, cols, comment_) -> meta_tables row';

CREATE OR REPLACE
FUNCTION meta_composite_type_text(meta_tables) RETURNS text AS $$
 SELECT 'CREATE TYPE '
 || ($1).name_
 || E'AS (\n  '
 || array_to_string(
      meta_column_texts( ($1).cols, $1 )
      || table_check_constraint_texts( ($1).checks )
      || table_primary_key_texts( ($1).primary_key )
      || table_unique_constraint_texts( ($1).uniques )
      || table_forn_key_texts( ($1).forn_keys )
    , E',\n  '
    )
 || E');\n'
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION create_composite_type(meta_composite_types) RETURNS regclass AS $$
DECLARE
 the_typeoid regtype;
BEGIN
-- should check if the type already exists
-- can do a drop cascade if desired!
 EXECUTE meta_composite_type_text($1);
 EXECUTE 'SELECT ' || quote_literal( ($1).name_ ) || '::regtype'
 INTO the_typeoid;
 IF ($1).comment_ IS NOT NULL THEN
   PERFORM comment_type(the_typeoid, ($1).comment_);
 END IF;
 RETURN the_typeoid;
END
$$ LANGUAGE plpgsql STRICT;

-- ** meta_table

CREATE OR REPLACE
FUNCTION meta_table(
  text,				-- name_
  meta_columns[],		-- cols
  check_constraints[],		-- checks
  index_constraints,		-- primary_key
  index_constraints[],		-- uniques
  meta_foreign_keys[],		-- forn_keys
  regclass[],			-- inherits_
  boolean,			-- with_oids
  meta_temp_tables,		-- temp_
  maybe_table_spaces,		-- space_
  storage_vars_vals[],		-- withs
  text				-- comment
) RETURNS meta_tables AS $$
  SELECT ROW($1,$2,$12,$3,$4,$5,$6,$7,$8,$9,$10,$11)::meta_tables
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION meta_table(
  text, meta_columns[], check_constraints[], index_constraints,
  index_constraints[], meta_foreign_keys[], regclass[], boolean,
  meta_temp_tables, maybe_table_spaces, storage_vars_vals[], text
) IS '(
  name_, cols, checks, primary_key, uniques, forn_keys,
  inherits_, with_oids, temp_, space_, withs, comment_
) -> meta_tables row';


CREATE OR REPLACE
FUNCTION meta_table(
  text,				-- name_
  meta_columns[],		-- cols
  check_constraints[],		-- checks
  index_constraints,		-- primary_key
  index_constraints[],		-- uniques
  meta_foreign_keys[],		-- forn_keys
  regclass[],			-- inherits_
  boolean,			-- with_oids
  text				-- comment
) RETURNS meta_tables AS $$
  SELECT ROW(
    $1, $2, $9, $3, $4, $5, $6, $7, $8,
    'temp_table_false_', NULL, NULL
  )::meta_tables
$$ LANGUAGE sql;
COMMENT ON FUNCTION meta_table(
  text, meta_columns[], check_constraints[], index_constraints,
  index_constraints[], meta_foreign_keys[], regclass[], boolean,
  text
) IS '(
  name_, cols, checks, primary_key, uniques, forn_keys,
  inherits_, with_oids, comment_
) -> meta_tables row';

-- ** create_table

CREATE OR REPLACE
FUNCTION maybe_inherits_text(regclass[]) RETURNS text AS $$
  SELECT maybe_text(
    'INHERITS (',
    ARRAY( SELECT x::text FROM array_to_list($1) x ),
    ', ',
    ')',
    ''
  )
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION maybe_on_commit_text(meta_temp_tables) RETURNS text AS $$
  SELECT COALESCE(
    ' ON COMMIT ' || CASE $1
      WHEN 'temp_table_false_' THEN NULL
      WHEN 'temp_table_preserve_' THEN 'PRESERVE ROWS'
      WHEN 'temp_table_delete_' THEN 'DELETE ROWS'
      WHEN 'temp_table_drop_' THEN 'DROP'
    END,
    ''
  )
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION meta_table_text(meta_tables) RETURNS text AS $$
 SELECT 'CREATE'
 || CASE WHEN ($1).temp_ = 'temp_table_false_' THEN '' ELSE ' TEMP' END
 || ' TABLE '
 || ($1).name_
 || E' (\n  '
 || array_to_string(
      meta_column_texts( ($1).cols, $1 )
      || table_check_constraint_texts( ($1).checks )
      || table_primary_key_texts( ($1).primary_key )
      || table_unique_constraint_texts( ($1).uniques )
      || table_forn_key_texts( ($1).forn_keys )
    , E',\n  '
    )
 || E'\n)'
 || maybe_inherits_text( ($1).inherits_ )
 || CASE WHEN ($1).with_oids THEN ' WITH OIDS' ELSE '' END
 || maybe_on_commit_text( ($1).temp_ )
 || E';\n'
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION comment_meta_column(regclass, meta_columns) RETURNS text AS $$
  SELECT CASE WHEN ($2).comment_ IS NOT NULL
    THEN comment_column($1, ($2).name_::text, ($2).comment_)
    ELSE $1::text || '.' || ($2).name_::text
  END
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION create_table(meta_tables) RETURNS regclass AS $$
DECLARE
 the_tableoid regclass;
BEGIN
-- should check if the table already exists
-- can do a drop cascade if desired!
 EXECUTE meta_table_text($1);
 EXECUTE 'SELECT ' || quote_literal( ($1).name_ ) || '::regclass'
 INTO the_tableoid;
 IF ($1).comment_ IS NOT NULL THEN
   PERFORM comment_table(the_tableoid, ($1).comment_);
 END IF;
 FOR i IN 1..array_length( ($1).cols ) LOOP
      PERFORM comment_meta_column(the_tableoid, ($1).cols[i]);
  END LOOP;
 RETURN the_tableoid;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION create_table(
  text,				-- name_
  meta_columns[],		-- cols
  check_constraints[],		-- checks
  index_constraints,		-- primary_key
  index_constraints[],		-- uniques
  meta_foreign_keys[],		-- forn_keys
  regclass[],			-- inherits_
  boolean,			-- with_oids
  text				-- comment
) RETURNS regclass AS $$
  SELECT create_table( meta_table($1, $2, $3, $4, $5, $6, $7, $8, $9) )
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION create_table(
  text, meta_columns[], check_constraints[], index_constraints,
  index_constraints[], meta_foreign_keys[], regclass[], boolean,
  text
) IS '(
  name_, cols, checks, primary_key, uniques, forn_keys,
  inherits_, with_oids, comment_
) -> create the table, return the new regclass (table oid)';


-- * Handy functions for portions of function bodies

CREATE OR REPLACE
FUNCTION list_args_with_array(ANYARRAY, integer) RETURNS text AS $$
  SELECT array_to_string( ARRAY(
    SELECT '$' || (i+$2)::text
    FROM array_to_set($1) AS (i integer, n text)
  ), ', ' )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION list_args_with_array(meta_columns[]) RETURNS text AS $$
  SELECT list_args_with_array( meta_cols_name_array( $1 ), 0 )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION list_args_with_array(meta_args[]) RETURNS text AS $$
  SELECT list_args_with_array( meta_args_name_array( $1 ), 0 )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION equate_args_with_array(column_name_arrays, integer) RETURNS text AS $$
  SELECT array_to_string( ARRAY(
    SELECT n || '=' || '$' || (i+$2)::text
    FROM array_to_set($1) AS (i integer, n text)
  ), ' AND ' )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION equate_args_with_array(meta_columns[]) RETURNS text AS $$
  SELECT equate_args_with_array( meta_cols_name_array( $1 ), 0 )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION class_field_text(regclass, meta_columns) RETURNS text AS $$
  SELECT $1::text || '.' || quote_ident(($2).name_)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION equate_class_fields(regclass, regclass, meta_columns[]) RETURNS text AS $$
  SELECT array_to_string(
    ARRAY(
      SELECT class_field_text($1, c) || '=' || class_field_text($2, c)
      FROM array_to_list($3) c
    ),
    ' AND '
  )
$$ LANGUAGE SQL STRICT;
