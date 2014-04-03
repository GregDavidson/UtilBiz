-- * Header  -*-Mode: sql;-*-
-- SELECT module_file_id('utility_meta_test.sql', '$Id: util_meta_test.sql,v 1.1 2008/11/15 08:18:24 greg Exp greg $');

--	PostgreSQL Metaprogramming Utilities Code

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

-- SELECT module_requires('utilities_meta_schema');

-- * creating comments

SELECT test_func(
  'comment_text(meta_entities, text, text)',
  comment_text(
    'meta_table_',
    'dining_room',
    'a good place to eat'
  ), $$
COMMENT ON TABLE dining_room IS
'a good place to eat';
$$ );

SELECT test_func(
  'comment_text(meta_entities, text, text)',
  comment_text(
    'meta_table_',
    'meta_entities_traits',
    'a few properties of some PostgreSQL entities'
  ), $$
COMMENT ON TABLE meta_entities_traits IS
'a few properties of some PostgreSQL entities';
$$ );

-- * creating functions

SELECT test_func(
  'arg_text(meta_args, bool)',
  arg_text( meta_arg('name', 'text'), true ),
  'name text'
);

SELECT test_func(
  'arg_text(meta_args, bool)',
  arg_text( meta_arg('name', 'text'), false ),
  'text'
);

SELECT test_func(
  'arg_text(meta_args, bool)',
  arg_text( meta_arg('code', 'integer', 'meta_argmodes_out_'), true ),
  'OUT code integer'  
 );

SELECT test_func(
  'arg_text(meta_args, bool)',
  arg_text( meta_arg('code', 'integer', 'meta_argmodes_out_'), false ),
  'OUT integer'
);

SELECT test_func(
  'meta_func_head_text(text, meta_args[], bool)',
  meta_func_head_text(
  'meta_func_head_text',
   ARRAY[
     meta_arg('name', 'text'),
     meta_arg('args', 'meta_args[]'),
     meta_arg('show arg names', 'bool')
   ], 
   true
  ),
  'meta_func_head_text(name text, args meta_args[], show arg names boolean)'
);

SELECT test_func(
  'meta_func_head_text(text, meta_args[], bool)',
  meta_func_head_text(
  'meta_func_head_text',
   ARRAY[
     meta_arg('name', 'text'),
     meta_arg('args', 'meta_args[]'),
     meta_arg('show arg names', 'bool')
   ], 
   false
  ),
  'meta_func_head_text(text, meta_args[], boolean)'
);


SELECT test_func(
  'func_head_comment_text(regproc, meta_args[])',
  func_head_comment_text(
    'func_head_comment_text', 
     ARRAY[
       meta_arg('name', 'regproc'), meta_arg('args', 'meta_args[]')
     ]
 ),
 'func_head_comment_text(name, args)'
);

SELECT test_func(
  'func_head_comment_text(regproc, meta_args[])',
  func_head_comment_text(
    'func_head_comment_text',
     ARRAY[
       meta_arg('func name', 'text'),
       meta_arg('arg descriptions', 'meta_args[]'),
       meta_arg('show arg names', 'bool')
     ]
  ),
  'func_head_comment_text(func name, arg descriptions, show arg names)'
);

SELECT meta_func(
  true,
  'test_func',
  ARRAY[
    meta_arg('name', 'text'),
    meta_arg('return type', 'regtype'),
    meta_arg('args', 'meta_args[]'),
    meta_arg('comment', 'text'),
    meta_arg('lang', 'meta_func_langs'),
    meta_arg('body', 'text')
  ],
  'void',
  false,
  'meta_func_sql_',
  'meta_func_stable_',
  true,
  ARRAY[ $$ SELECT 'hello world!' $$ ]
);

SELECT test_func(
  'meta_func_text(meta_funcs)',
  meta_func_text(
    meta_func(
      true,
      'test_func',
      ARRAY[
	meta_arg('name', 'text'),
	meta_arg('return type', 'regtype'),
	meta_arg('args', 'meta_args[]'),
	meta_arg('comment', 'text'),
	meta_arg('lang', 'meta_func_langs'),
	meta_arg('body', 'text')
      ],
      'void',
      false,
      'meta_func_sql_',
      'meta_func_stable_',
      true,
      ARRAY[ $$ SELECT 'hello world!' $$ ]
    )
  ),
  $$CREATE  OR REPLACE
FUNCTION test_func(text, regtype, meta_args[], text, meta_func_langs, text)
RETURNS void LANGUAGE 'sql' STABLE STRICT AS
' SELECT ''hello world!'' ';
$$
);

SELECT
  meta_func_text(
    meta_func(
      true,
      'test_func',
      ARRAY[
	meta_arg('name', 'text'),
	meta_arg('return type', 'regtype'),
	meta_arg('args', 'meta_args[]'),
	meta_arg('comment', 'text'),
	meta_arg('lang', 'meta_func_langs'),
	meta_arg('body', 'text')
      ],
      'void',
      false,
      'meta_func_sql_',
      meta_func_stability(),
      true,
      ARRAY[ $$ SELECT 'hello world!' $$ ]
    )
  );

SELECT test_func(
  'meta_func_text(meta_funcs)',
  meta_func_text(
    meta_func(
      true,
      'test_func',
      ARRAY[
	meta_arg('name', 'text'),
	meta_arg('return type', 'regtype'),
	meta_arg('args', 'meta_args[]'),
	meta_arg('comment', 'text'),
	meta_arg('lang', 'meta_func_langs'),
	meta_arg('body', 'text')
      ],
      'void',
      false,
      'meta_func_sql_',
      meta_func_stability(),
      true,
      ARRAY[ $$ SELECT 'hello world!' $$ ]
    )
  ),
$$CREATE  OR REPLACE
FUNCTION test_func(text, regtype, meta_args[], text, meta_func_langs, text)
RETURNS void LANGUAGE 'sql' STRICT AS
' SELECT ''hello world!'' ';
$$
);

SELECT func_comment_text(
  'func_comment_text(regprocedure, meta_args[], text)',
  ARRAY[
     meta_arg('func', 'regprocedure'),
     meta_arg('args', 'meta_args[]'),
     meta_arg('comment', 'text')
   ],
 'generate a nice comment for a function'
);

CREATE OR REPLACE
FUNCTION greet(name text) RETURNS TEXT AS $$
  SELECT 'Hello ' || $1 || ', how do you do?'
$$ LANGUAGE 'sql' STRICT;

DROP FUNCTION greet(name text);

SELECT test_func(
  'meta_func_text(meta_funcs)',
  meta_func_text(
    meta_func(
      true,
      'greet',
      ARRAY[meta_arg('name', 'text')],
      'text',
      false,
      'meta_func_sql_',
      meta_func_stability(),
      true,
      ARRAY[ $$ SELECT 'Hello ' || $1 || ', how do you do?' $$ ]
    )
  ),
  $$CREATE  OR REPLACE
FUNCTION greet(text)
RETURNS text LANGUAGE 'sql' STRICT AS
' SELECT ''Hello '' || $1 || '', how do you do?'' ';
$$
);

SELECT create_func(
  true,
  'greet',
  ARRAY[meta_arg('name', 'text')],
  'text',
  false,
  'meta_func_sql_',
  meta_func_stability(),
  true,
  ARRAY[ $$ SELECT 'Hello ' || $1 || ', how do you do?' $$ ],
  'greet someone nicely'
);

SELECT greet('Lynn');

-- * creating tables

SELECT test_func(
  'column_name_array_text(column_name_arrays)',
  column_name_array_text(ARRAY['foo', 'bar']::column_name_arrays),
  '(foo, bar)'
);

SELECT test_func(
  'is_table_constraint(abstract_constraints)',
  is_table_constraint(
    ROW(
      'constraint_name',
      ARRAY['foo', 'bar']::column_name_arrays,
      constraint_deferring()
    )::abstract_constraints
  ),
  true
);

SELECT test_func(
  'is_column_constraint(column_names, abstract_constraints)',
  is_column_constraint(
    'foo',
    ROW(
      'constraint_name',
      ARRAY['foo', 'bar']::column_name_arrays,
      constraint_deferring()
    )::abstract_constraints
  ),
  false
);

SELECT test_func(
  'is_column_constraint(column_names, abstract_constraints)',
  is_column_constraint(
    'foo',
    ROW(
      'constraint_name',
      ARRAY['foo']::column_name_arrays,
      constraint_deferring()
    )::abstract_constraints
  ),
  false
);

SELECT test_func(
  'is_column_constraint(column_names, abstract_constraints)',
  is_column_constraint(
    'foo',
    ROW(
      NULL::text,
      ARRAY['foo']::column_name_arrays,
      constraint_deferring()
    )::abstract_constraints
  ),
  true
);

SELECT test_func(
  'check_constraint(
    text, column_name_arrays, constraint_deferrings, maybe_sql_exprs
  )',
  check_constraint_text(
    check_constraint(
      'constraint_name',
      ARRAY['foo', 'bar']::column_name_arrays,
      constraint_deferring(),
      'foo > bar'
  )  ),
  'CONSTRAINT constraint_name CHECK(foo > bar)'
);


SELECT
  table_check_constraint_texts(ARRAY[
    check_constraint(
      'foo_bar_cnst',
      ARRAY['foo', 'bar']::column_name_arrays,
      constraint_deferring(),
      'foo > bar'
    ),
    check_constraint(
      'foobar_cnst',
      ARRAY['foobar']::column_name_arrays,
      constraint_deferring(),
      'foobar > 0'
    ),
    check_constraint(
      NULL::text,
      ARRAY['fubar']::column_name_arrays,
      constraint_deferring(),
      'foobar > 0'
    )
] );

-- looks like a bug in the PostgreSQL parser!
-- SELECT test_func(
--   'table_check_constraint_texts(check_constraints[])',
--   table_check_constraint_texts(ARRAY[
--     check_constraint(
--       'constraint_name',
--       ARRAY['foo', 'bar']::column_name_arrays,
--       constraint_deferring(),
--       'foo > bar'
--     ),
--     check_constraint(
--       'constraint_name',
--       ARRAY['foobar']::column_name_arrays,
--       constraint_deferring(),
--       'foobar > 0'
--     )
--   ] ),
--   'x'
-- );

SELECT
  maybe_column_checks_text(
    'foobar',
    ARRAY[
      check_constraint(
	'foo_bar_cnst',
	ARRAY['foo', 'bar']::column_name_arrays,
	constraint_deferring(),
	'foo > bar'
      ),
      check_constraint(
	NULL::text,
	ARRAY['foobar']::column_name_arrays,
	constraint_deferring(),
	'foobar > 0'
      ),
      check_constraint(
	'fubar_cnst',
	ARRAY['fubar']::column_name_arrays,
	constraint_deferring(),
	'fubar > 0'
      )
  ]
);


SELECT test_func(
  'index_constraint_text(text, index_constraints)',
  index_constraint_text(
    'PRIMARY KEY',
    index_constraint(
      'foo_bar_cnst',
      ARRAY['foo', 'bar']::column_name_arrays,
      constraint_deferring()
    )
  ),
  'CONSTRAINT foo_bar_cnst PRIMARY KEY(foo, bar)'
);

SELECT test_func(
  'index_constraint_text(text, index_constraints)',
  index_constraint_text(
    'PRIMARY KEY',
    index_constraint(
      NULL::text,
      ARRAY['foo', 'bar']::column_name_arrays,
      constraint_deferring()
    )
  ),
  ' PRIMARY KEY(foo, bar)'
);

SELECT test_func(
  'index_constraint_text(text, index_constraints)',
  index_constraint_text(
    'PRIMARY KEY',
    index_constraint(
      NULL::text,
      ARRAY['foobar']::column_name_arrays,
      constraint_deferring()
    )
  ),
  ' PRIMARY KEY(foobar)'
);

SELECT test_func(
  'maybe_column_primary_text(column_names, index_constraints)',
  maybe_column_primary_text(
    'foobar',
    index_constraint(
      NULL::text,
      ARRAY['foobar']::column_name_arrays,
      constraint_deferring()
    )
  ),
  ' PRIMARY KEY'
);

SELECT test_func(
  'maybe_column_unique_text(column_names, index_constraints[])',
  maybe_column_unique_text(
    'foobar',
    ARRAY[ index_constraint(
      NULL::text,
      ARRAY['foobar']::column_name_arrays,
      constraint_deferring()
    ) ]
  ),
  ' UNIQUE'
);

SELECT
 test_func(
  'foreign_key_text(meta_foreign_keys)',
  foreign_key_text(
    meta_foreign_key(
      'foobar_entity_traits_ref',
      ARRAY['entity']::column_name_arrays,
      constraint_deferring(),
      'meta_entity_traits',
      ARRAY['entity']::column_name_arrays,
      foreign_key_matching(),
      foreign_key_action(),
      foreign_key_action()
    )
  ),
  'CONSTRAINT foobar_entity_traits_ref FOREIGN KEY(entity) REFERENCES meta_entity_traits(entity)'
);

SELECT meta_column('id', 'integer', '0', true, 'Not the Freudian one!');

SELECT test_func(
  'meta_column_text(meta_columns)',
  meta_column_text(
    meta_column('name', 'text', 'it''s not the thing!')
  ),
  'name text'
);

SELECT primary_meta_column_array('meta_entity_traits');

SELECT test_func(
  'comment_meta_column(regclass, meta_columns)',
  comment_meta_column(
    'meta_func_langs_names',
    meta_column('name', 'text', 'it''s not the thing!')
  ),
  E'COLUMN meta_func_langs_names.name\n\tit''s not the thing!'
);

SELECT
--  meta_column_texts(colms, tbl)
  ARRAY(
    SELECT meta_column_text(c)
    || maybe_column_checks_text( (c).name_, (t).checks )
    || maybe_column_primary_text( (c).name_, (t).primary_key )
    || maybe_column_unique_text( (c).name_, (t).uniques )
    || maybe_column_forn_key_text( (c).name_, (t).forn_keys )
    FROM array_to_list(
      ARRAY[
	meta_column(
	  'name',
	  'text',
	  NULL,
	  false,
	   'a PostgreSQL entity text name'
	)
      ]
    ) c
  )
FROM meta_table(
  'meta_entity_traits',
  ARRAY[
    meta_column(
      'name',
      'text',
      NULL,
      false,
       'a PostgreSQL entity text name'
    )
  ],
  NULL::check_constraints[],
  NULL::index_constraints,
  NULL::index_constraints[],
  NULL::meta_foreign_keys[],
  NULL::regclass[],
  true,
  'associates key properties with meta_entities'
) t;

-- meta_table(
--  text, meta_columns[], check_constraints[], index_constraints,
--  index_constraints[], meta_foreign_keys[], regclass[], boolean,
--  text
-- )
-- see TABLE meta_entity_traits in utility_meta_schema.sql
SELECT array_to_string(
  meta_column_texts(
      ARRAY[
	meta_column(
	  'entity',
	  'meta_entities',
	  NULL,
	  false,
	  'a PostgreSQL entity enum'
	),
	meta_column(
	  'name',
	  'text',
	  NULL,
	  false,
	   'a PostgreSQL entity text name'
	),
	meta_column(
	  'commentable',
	  'boolean',
	  'true',
	  true,
	  'is this entity supported by PostgreSQL COMMENT ON'
	)
      ],
    meta_table(
      'meta_entity_traits',
      ARRAY[
	meta_column(
	  'entity',
	  'meta_entities',
	  NULL,
	  false,
	  'a PostgreSQL entity enum'
	),
	meta_column(
	  'name',
	  'text',
	  NULL,
	  false,
	   'a PostgreSQL entity text name'
	),
	meta_column(
	  'commentable',
	  'boolean',
	  'true',
	  true,
	  'is this entity supported by PostgreSQL COMMENT ON'
	)
      ],
      NULL::check_constraints[],
      index_constraint(
	  NULL::text,
	  ARRAY['entity']::column_name_arrays,
	  constraint_deferring()
	),
      ARRAY[ index_constraint(
	  NULL::text,
	  ARRAY['name']::column_name_arrays,
	  constraint_deferring()
      ) ],
      NULL::meta_foreign_keys[],
      NULL::regclass[],
      true,
      'associates key properties with meta_entities'
    )
  ),
  E',\n'
);


SELECT test_func(
  'meta_table_text(meta_tables)',
  meta_table_text(
    meta_table(
      'id_name_pairs',
      ARRAY[
	meta_column('id', 'integer', 'next_pair_id()', false, 'Not Freudian!'),
	meta_column('name', 'text', NULL::text, true, 'it''s not the thing!')
      ],
      NULL::check_constraints[],
      index_constraint(
	  NULL::text,
	  ARRAY['id']::column_name_arrays,
	  constraint_deferring()
	),
      ARRAY[ index_constraint(
	  NULL::text,
	  ARRAY['name']::column_name_arrays,
	  constraint_deferring()
      ) ],
      NULL::meta_foreign_keys[],
      NULL::regclass[],
      true,
      'associates key properties with meta_entities'
    )
  ),
$$CREATE TABLE id_name_pairs (
  id integer DEFAULT 'next_pair_id()' PRIMARY KEY,
  name text NOT NULL UNIQUE
) WITH OIDS;
$$
);

SELECT test_func(
  'primary_meta_column_array(regclass)',
  array_length( primary_meta_column_array('meta_entity_traits')),
  1
);

SELECT test_func(
  'get_primary_forn_keys(regclass)',
  foreign_key_text(get_primary_forn_keys('meta_entity_traits')),
  ' FOREIGN KEY(entity) REFERENCES meta_entity_traits(entity)'
);
