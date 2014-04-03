-- * Header  -*-Mode: sql;-*-
-- SELECT module_file_id('Util-SQL/util-modules-schema.sql', '$Id: util-modules-schema.sql,v 1.2 2007/07/24 04:27:47 greg Exp greg $');
-- N.B.: Module Declarations are in last section below

-- Utility for managing modules

-- ** Copyright

--	Copyright (c) 2005 - 2007, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- Eventually I would like to have more attributes associated with these
-- various entities: modules, functions, classes.

-- * Definitions (and an include)

-- \i ../Util-SQL/util-psql.sql

-- Ideally I'd use module_id wherever OIDs are being
-- used now, but current PostgreSQL seems to not allow
-- this for the actual oid.
CREATE DOMAIN module_ids AS INTEGER NOT NULL;
CREATE DOMAIN maybe_module_ids AS INTEGER;

CREATE TABLE modules (
	PRIMARY KEY(oid),
	parent maybe_module_ids REFERENCES modules,
	filename TEXT UNIQUE NOT NULL,
	rcsid TEXT NOT NULL
) WITH OIDS;
COMMENT ON TABLE modules IS
'represents a logical or physical module of SQL code';
COMMENT ON COLUMN modules.parent IS
'the name of a higher level module containing this one, if any';
COMMENT ON COLUMN modules.filename IS
'either a higher level module name or a file name';
COMMENT ON COLUMN modules.rcsid IS
'version information about the current module in a form
compatible with Walter Tichy''s Revision Control System';

CREATE TABLE current_module (
  id module_ids references modules
--  CHECK( count(*) = 1 )
);

CREATE FUNCTION this_module() RETURNS module_ids AS $$
  SELECT id FROM current_module
$$ LANGUAGE sql;

-- * module variables

-- ** TABLE modules_types_names_ids(module, type_, name_, id_)
CREATE TABLE modules_types_names_ids (
  module_ module_ids,
  type_ regtype NOT NULL,
  name_ text NOT NULL,
  UNIQUE (module_, type_, name_),
  id_ INTEGER
);
COMMENT ON TABLE modules_types_names_ids IS
'This table provides module-scoped typed variables for values of some
integer subtype; this facility is primarily provided for bootstrapping
and testing purposes, and maybe for very-limited system-introspection:
it is not yet ready for general use!  This could be developed into a
nice objects-in-hierarchical-packages system with imports and exports.
Yes, that would be cool!';

-- * module dependencies

CREATE TABLE required_modules (
  requiring module_ids REFERENCES modules,
  required module_ids REFERENCES modules,
  PRIMARY KEY(requiring, required),
  CONSTRAINT required_modules_non_reflexive CHECK(requiring != required)
);

CREATE TABLE module_entities (
  provider module_ids REFERENCES modules,
  entity oid PRIMARY KEY
);

CREATE TABLE module_entities_required (
  requiring_module module_ids REFERENCES modules,
  required_entity module_ids,
  PRIMARY KEY(requiring_module, required_entity)
);

-- Constraints to add:
-- entities are never required by the module which provides them
-- entities are never provided by the module which requires them

-- Moving from module to entity requirements
-- Ideally all module requirements would be inferred

-- Moving to hierarchical packages
-- Modules would require packages
-- Packages would consist of modules
-- Within a package, module-module dependencies are used.
-- Outside a package, only current-module to other-package
-- could be used.
-- Can simulate this by having a module in each package
-- which has a simple name and is simply a file with
-- dependencies on all of the other modules within that
-- package!

-- Possibly adding entity-to-entity requirements
-- Can't check ahead of time, so not as useful
-- module_provides could set current_entity to make it
-- easier to follow a definition with the required entities.

CREATE TABLE required_entities (
  requiring module_ids REFERENCES module_entities,
  required module_ids REFERENCES module_entities,
  PRIMARY KEY(requiring, required),
  CONSTRAINT required_modules_non_reflexive CHECK(requiring != required)
);

-- CREATE TABLE module_functions (
--   function_ regprocedure PRIMARY KEY REFERENCES module_entities
-- );

-- CREATE TABLE module_classes (
--   provider OID NOT NULL REFERENCES modules,
--   class_ regclass PRIMARY KEY
-- );

-- CREATE TABLE module_types (
--   provider OID NOT NULL REFERENCES modules,
--   type_ regtype PRIMARY KEY
-- );

-- ** TYPE name_id_pairs

CREATE TYPE name_id_pairs AS ( name text, id oid );	-- for use in views

CREATE FUNCTION name_of(name_id_pairs) RETURNS text AS $$
  SELECT $1."name"
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE FUNCTION id_of(name_id_pairs) RETURNS oid AS $$
  SELECT $1.id
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE FUNCTION name_id_pairs_cmp(name_id_pairs, name_id_pairs)
RETURNS int4 AS $$
  SELECT CASE
    WHEN ($1).id < ($2).id THEN -1
    WHEN ($1).id > ($2).id THEN 1
    ELSE CASE
      WHEN ($1)."name" < ($2)."name" THEN -1
      WHEN ($1)."name" > ($2)."name" THEN 1
      ELSE 0
    END
  END
$$ LANGUAGE sql IMMUTABLE STRICT;

CREATE FUNCTION name_id_pairs_lt(name_id_pairs, name_id_pairs) RETURNS bool
AS $$
  SELECT name_id_pairs_cmp($1, $2) < 0
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE FUNCTION name_id_pairs_le(name_id_pairs, name_id_pairs) RETURNS bool
AS $$
  SELECT name_id_pairs_cmp($1, $2) <= 0
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE FUNCTION name_id_pairs_eq(name_id_pairs, name_id_pairs) RETURNS bool
AS $$
  SELECT name_id_pairs_cmp($1, $2) = 0
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE FUNCTION name_id_pairs_neq(name_id_pairs, name_id_pairs) RETURNS bool
AS $$
  SELECT name_id_pairs_cmp($1, $2) <> 0
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE FUNCTION name_id_pairs_ge(name_id_pairs, name_id_pairs) RETURNS bool
AS $$
  SELECT name_id_pairs_cmp($1, $2) >= 0
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE FUNCTION name_id_pairs_gt(name_id_pairs, name_id_pairs) RETURNS bool
AS $$
  SELECT name_id_pairs_cmp($1, $2) > 0
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OPERATOR < (
   leftarg = name_id_pairs, rightarg = name_id_pairs,
   procedure = name_id_pairs_lt,
   commutator = > , negator = >= ,
   restrict = scalarltsel, join = scalarltjoinsel
);

CREATE OPERATOR <= (
   leftarg = name_id_pairs, rightarg = name_id_pairs,
   procedure = name_id_pairs_le,
   commutator = >= , negator = > ,
   restrict = scalarltsel, join = scalarltjoinsel
);

CREATE OPERATOR = (
   leftarg = name_id_pairs, rightarg = name_id_pairs,
   procedure = name_id_pairs_eq,
   commutator = = ,
   negator = <> ,
   restrict = eqsel, join = eqjoinsel
);

CREATE OPERATOR <> (
   leftarg = name_id_pairs, rightarg = name_id_pairs,
   procedure = name_id_pairs_neq,
   commutator = <> ,
   negator = = ,
   restrict = neqsel, join = neqjoinsel
);

CREATE OPERATOR >= (
   leftarg = name_id_pairs, rightarg = name_id_pairs,
   procedure = name_id_pairs_ge,
   commutator = <= , negator = < ,
   restrict = scalargtsel, join = scalargtjoinsel
);

CREATE OPERATOR > (
   leftarg = name_id_pairs, rightarg = name_id_pairs,
   procedure = name_id_pairs_gt,
   commutator = < , negator = <= ,
   restrict = scalargtsel, join = scalargtjoinsel
);

-- now we can make the operator class
CREATE OPERATOR CLASS name_id_pairs_ops
    DEFAULT FOR TYPE name_id_pairs USING btree AS
        OPERATOR        1       < ,
        OPERATOR        2       <= ,
        OPERATOR        3       = ,
        OPERATOR        4       >= ,
        OPERATOR        5       > ,
        FUNCTION        1       name_id_pairs_cmp(name_id_pairs, name_id_pairs);

-- * Module Declarations

INSERT INTO modules(filename, rcsid) VALUES('Util-SQL/util-modules-schema.sql', '$Id: util-modules-schema.sql,v 1.2 2007/07/24 04:27:47 greg Exp greg $');

INSERT INTO current_module SELECT oid FROM modules;

INSERT INTO module_entities (provider, entity)
SELECT * FROM
  (SELECT oid  FROM modules WHERE filename = 'Util-SQL/util-modules-schema.sql') x
  CROSS JOIN  (
	SELECT 'name_id_pairs'::regtype::oid		UNION
	SELECT 'modules'::regclass::oid		UNION
	SELECT 'current_module'::regclass::oid		UNION
	SELECT 'required_modules'::regclass::oid	UNION
	SELECT 'required_entities'::regclass::oid	UNION
	SELECT 'module_entities'::regclass::oid
  ) y;
