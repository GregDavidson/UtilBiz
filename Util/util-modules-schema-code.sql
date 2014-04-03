-- * Header  -*-Mode: sql;-*-
-- SELECT module_file_id('Util-SQL/util-modules-schema-code.sql', '$Id: util-modules-schema-code.sql,v 1.2 2007/07/24 04:27:47 greg Exp greg $');
INSERT INTO modules(filename, rcsid)
VALUES('Util-SQL/util-modules-schema-code.sql', '$Id: util-modules-schema-code.sql,v 1.2 2007/07/24 04:27:47 greg Exp greg $');

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- N.B.: Module Declarations are in last section below

-- Utility for managing modules

-- Create an insertion rule which fills in missing pieces using naming defaults.

-- another side effect of the rule could be to manage a marker for which module
-- is current so that

-- documentation functions can associate module with entities defined in that
-- module


-- * module_file_id and module_requires functions

-- ~~~ module_oid(name TEXT) -> module OID
-- better check that name has no metacharacters in it!
CREATE OR REPLACE
FUNCTION module_oid(TEXT) RETURNS oid AS $$
  SELECT oid FROM modules WHERE filename ~ ('.*/' || $1 || '.sql$');
$$ LANGUAGE sql STRICT;

-- ~~~ module_name(oid) -> TEXT
CREATE OR REPLACE
FUNCTION module_name(oid) RETURNS text AS $$
  SELECT regexp_replace(filename, '.*/([^.]*).*', E'\\1') FROM modules WHERE oid = $1
$$ LANGUAGE sql STRICT;

-- ~~~ module_text(oid) -> TEXT
CREATE OR REPLACE
FUNCTION module_text(oid) RETURNS text AS $$
  SELECT CASE
    WHEN rcsid = ('$Id' || '$') THEN module_name(oid)
    ELSE regexp_replace(rcsid, E'\\$Id: (.*),v ([^[:space:]]*).*', E'\\1 \\2')
  END
  FROM modules
  WHERE oid = $1
$$ LANGUAGE sql STRICT;

-- ~~~ module_pair(oid) -> name_id_pairs
CREATE OR REPLACE
FUNCTION module_pair(oid) RETURNS name_id_pairs AS $$
  SELECT ( module_text($1), $1 )::name_id_pairs
$$ LANGUAGE sql STRICT;

-- +++ this_module(module text) -> void
CREATE OR REPLACE
FUNCTION this_module(text) RETURNS void AS $$
  DECLARE
    mod_id OID := module_oid($1);
    rcs TEXT;
    pair name_id_pairs;
  BEGIN
    IF mod_id IS NULL THEN
      RAISE EXCEPTION 'this_module(%): No such module', $1;
    END IF;
    UPDATE current_module SET id = mod_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'this_module(%): Problem updating current_module', $1;
    END IF;
  END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION this_module(text) IS
'set the current module to the one specified';

-- +++ module_file_id(filename TEXT, rcsid TEXT) -> name_id_pairs
CREATE OR REPLACE
FUNCTION module_file_id(TEXT, TEXT) RETURNS name_id_pairs AS $$
  DECLARE
    mod_id OID;
    rcs TEXT;
    pair name_id_pairs;
  BEGIN
    LOOP
      SELECT INTO mod_id, rcs oid, filename
      FROM modules WHERE filename = $1
      FOR UPDATE;
      IF FOUND THEN
        UPDATE current_module SET id = mod_id;
        IF $2 IS NOT NULL AND rcs IS DISTINCT FROM $2 THEN
          UPDATE modules SET rcsid = $2 WHERE oid = mod_id;
        END IF;
        pair := module_pair(mod_id);
        RETURN pair;
      END IF;
      BEGIN
        INSERT INTO modules(filename, rcsid) VALUES($1, $2);
      EXCEPTION
        WHEN unique_violation THEN
          -- evidence of another thread
      END;
    END LOOP;
  END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION module_file_id(TEXT, TEXT) IS
'insert or update information for a file in relation modules';

CREATE OR REPLACE
VIEW the_modules(name_id) AS
SELECT	(module_name(oid),  oid)::name_id_pairs
FROM modules;


-- ** TABLE modules_types_names_ids(module_, type_ name_, id_)

-- These functions provide a primitive mechanism to associate
-- names with (1) a specific module, (2) some specific integer subtype,
-- e.g. an id-type created with CREATE DOMAIN and (3) a value.
-- I'm aware of no SQL mechanism to ensure that the values being
-- "held" by these variables are actually of the specified types.
-- Given all this, it is recommended that you
-- (1) use this system sparingly - it is primitive and fragile
-- (2a) wrap the functions you need in safer type-specific functions.
-- (2b) An example of this follows in the next section below.
-- See comments on TABLE modules_types_names_ids in module-schema.sql.

-- -- other_module_clear_ids(module) -> void
CREATE OR REPLACE
FUNCTION other_module_clear_ids(OID) RETURNS void AS $$
  DELETE FROM modules_types_names_ids WHERE module_=$1
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION other_module_clear_ids(OID) IS
'This function is not for general use;
see comment on modules_types_names_ids';

-- -- module_clear_ids() -> void
CREATE OR REPLACE
FUNCTION module_clear_ids() RETURNS void AS $$
  SELECT other_module_clear_ids(this_module())
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION module_clear_ids() IS
'This function is not for general use;
see comment on modules_types_names_ids';

-- -- other_module_type_name_id_get(module, regtype, text) -> integer
CREATE OR REPLACE
FUNCTION other_module_type_name_id_get(OID, regtype, text) RETURNS integer AS $$
DECLARE
  the_id integer;
BEGIN
  SELECT INTO the_id id_ FROM modules_types_names_ids
  WHERE module_=$1 AND type_ = $2 AND name_ = $3;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Module % type % name % id not found!', $1, $2, $3;
  END IF;
  RETURN the_id;
END
$$ LANGUAGE 'plpgsql' STRICT;
COMMENT ON FUNCTION other_module_type_name_id_get(OID, regtype, text) IS
'This function is not for general use;
see comment on modules_types_names_ids';

-- -- module_type_name_id_get(regtype, text) -> integer
CREATE OR REPLACE
FUNCTION module_type_name_id_get(regtype, text) RETURNS integer AS $$
  SELECT other_module_type_name_id_get(this_module(), $1, $2)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION module_type_name_id_get(regtype, text) IS
'This function is not for general use;
see comment on modules_types_names_ids';

-- -- other_module_type_id_names(module, regtype, id) -> SETOF text
CREATE OR REPLACE
FUNCTION other_module_type_id_names(OID, regtype, integer) RETURNS SETOF text AS $$
  SELECT name_ FROM modules_types_names_ids
  WHERE module_=$1 AND type_ = $2 AND id_ = $3
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION other_module_type_id_names(OID, regtype, integer) IS
'This function is not for general use;
see comment on modules_types_names_ids';

-- -- module_type_id_names(regtype, id) -> SETOF text
CREATE OR REPLACE
FUNCTION module_type_id_names(regtype, integer) RETURNS SETOF text AS $$
  SELECT other_module_type_id_names(this_module(), $1, $2)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION module_type_id_names(regtype, integer) IS
'This function is not for general use;
see comment on modules_types_names_ids';

-- -- other_module_type_name_id_set(module, regtype, text, id) -> integer
CREATE OR REPLACE
FUNCTION other_module_type_name_id_set(OID, regtype, text, integer) RETURNS integer AS $$
DECLARE
  old_id integer;
BEGIN
  SELECT INTO old_id id_ FROM modules_types_names_ids
  WHERE module_=$1 AND type_ = $2 AND name_ = $3
  FOR UPDATE;
  IF FOUND THEN
    RAISE NOTICE 'module_type_name_id(%, %, %): % -> %', $1, $2, $3, old_id, $4;
    UPDATE modules_types_names_ids SET id_ = $4
    WHERE module_ = $1 AND type_ = $2 AND name_ = $3;
  ELSE
    INSERT INTO modules_types_names_ids VALUES($1, $2, $3, $4);
  END IF;
  RETURN $4;
END;
$$ LANGUAGE 'plpgsql';
COMMENT ON FUNCTION other_module_type_name_id_set(OID, regtype, text, integer) IS
'This function is not for general use;
see comment on modules_types_names_ids';

-- -- module_type_name_id_set(regtype, text, id) -> integer
CREATE OR REPLACE
FUNCTION module_type_name_id_set(regtype, text, integer) RETURNS integer AS $$
  SELECT other_module_type_name_id_set(this_module(), $1, $2, $3)
$$ LANGUAGE sql;
COMMENT ON FUNCTION module_type_name_id_set(regtype, text, integer) IS
'This function is not for general use;
see comment on modules_types_names_ids';

-- -- module_type_name_id_import(module_name, regtype, text) -> integer
CREATE OR REPLACE
FUNCTION module_type_name_id_import(text, regtype, text) RETURNS integer AS $$
  SELECT module_type_name_id_set(
    $2, $3, other_module_type_name_id_get(module_oid($1), $2, $3)
  )
$$ LANGUAGE sql;
COMMENT ON FUNCTION module_type_name_id_import(text, regtype, text) IS
'This function is not for general use;
see comment on modules_types_names_ids';


-- ** TABLE modules_types_names_ids wrappers for module OIDs

-- Use these functions sparingly and with caution,
-- this mechanism is primitive and fragile!

-- -- hold_module_id(text) -> module_ids
CREATE OR REPLACE
FUNCTION hold_module_id(text) RETURNS OID AS $$
  SELECT module_type_name_id_get('module_ids'::regtype, $1)::OID
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION hold_module_id(text) IS
'Return the module id value held in this module under the given name.';

-- -- hold_module_id(module_ids) -> SETOF text
CREATE OR REPLACE
FUNCTION hold_module_id(OID) RETURNS SETOF text AS $$
  SELECT module_type_id_names('module_ids'::regtype, $1::integer)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION hold_module_id(OID) IS
'Return any names under whiich the given module id value is held in this module.';

-- -- hold_module_id(text, module_ids) -> module_ids
CREATE OR REPLACE
FUNCTION hold_module_id(text, OID) RETURNS OID AS $$
  SELECT module_type_name_id_set(
    'module_ids'::regtype, $1, $2::integer
  )::OID
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION hold_module_id(text, OID) IS
'Hold the given module id value under the given name, also return that value.';

-- -- import_module_id(text, text) -> module_ids
CREATE OR REPLACE
FUNCTION import_module_id(text, text) RETURNS OID AS $$
  SELECT module_type_name_id_import($1, 'module_ids'::regtype, $2)::OID
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION import_module_id(text, text) IS
'Copy the module id value held in the specified module,
holding it under the same name in the current module,
and return that value';

CREATE OR REPLACE
VIEW module_held_ids(module, id_type, id_name, id_value) AS
SELECT	module_name(module_),  type_, name_, id_
FROM modules_types_names_ids;

CREATE OR REPLACE
VIEW held_ids(id_type, id_name, id_value) AS
SELECT	type_, name_, id_
FROM modules_types_names_ids WHERE module_ = this_module();


-- ** required_modules

CREATE OR REPLACE
VIEW the_required_modules(requiring_name_id, required_name_id) AS
SELECT	(module_name(requiring),  requiring)::name_id_pairs,
	(module_name(required), required)::name_id_pairs
FROM required_modules;

-- ~~~ record_module_requires(requiring, required) -> rcsid of required
CREATE OR REPLACE
FUNCTION record_module_requires(oid, oid) RETURNS TEXT AS $$
  DECLARE
    id TEXT;
  BEGIN
    LOOP
      PERFORM * FROM required_modules WHERE requiring = $1 AND required = $2;
      IF FOUND THEN
          SELECT INTO id rcsid FROM modules WHERE oid = $2;
          RETURN COALESCE(id, '???');
      ELSE
        BEGIN
          INSERT INTO required_modules(requiring, required) VALUES($1, $2);
        EXCEPTION
          WHEN unique_violation THEN
            -- evidence of another thread
        END;
      END IF;
    END LOOP;
  END;
$$ LANGUAGE plpgsql STRICT;
COMMENT ON FUNCTION record_module_requires(oid, oid) IS
'insert or check a module requirement relationship';

CREATE OR REPLACE
VIEW the_current_module(name_id) AS
SELECT	(module_name(id),  id)::name_id_pairs
FROM current_module;

-- +++ module_requires(required module by name) -> rcsid of required module
-- need this to fail if either module not already registered
CREATE OR REPLACE
FUNCTION module_requires(TEXT) RETURNS TEXT AS $$
  SELECT record_module_requires( id, module_oid($1) ) FROM current_module;
  SELECT module_text(module_oid($1));
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION module_requires(TEXT) IS
'check and record inter-module dependency';

-- +++ requires(requiring entity, required entity) -> summary
-- need this to fail if either module not already registered
-- CREATE OR REPLACE
-- FUNCTION requires(oid, oid) RETURNS the_entities_required AS $$
-- $$ LANGUAGE sql STRICT;
-- COMMENT ON FUNCTION requires(oid, oid) IS
-- 'check and record inter-entity dependency';

-- ??? !!!
-- really want to return two columns: home module, entity_text
-- +++ module_requires(entity) -> ???
-- need this to fail if entity not already registered
-- CREATE OR REPLACE
-- FUNCTION module_requires(oid) RETURNS TEXT AS $$
--   SELECT record_module_requires_entity( id, $1 ) FROM current_module;
--   SELECT entity_text($1);
-- $$ LANGUAGE sql STRICT;
-- COMMENT ON FUNCTION module_requires(TEXT) IS
-- 'check and record inter-module dependency';

-- * PostgreSQL meta-code to get entity names and kinds

-- Some of this code is used by other parts of the system
-- to do things unrelated to modules, but it is easier to
-- centralize it here.

-- ** regtype_name(regtype) -> type name
CREATE OR REPLACE
FUNCTION regtype_name(regtype) RETURNS text AS $$
	SELECT $1::text
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** regtype_text(regtype) -> nice type description
CREATE OR REPLACE
FUNCTION regtype_text(regtype) RETURNS text AS $$
	SELECT 'TYPE ' || regtype_name($1)
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** regclass_name(regclass) -> name of "class" entity
CREATE OR REPLACE
FUNCTION regclass_name(regclass) RETURNS text AS $$
	SELECT $1::text
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** regclass_kind(regclass) -> kind of class entity
CREATE OR REPLACE
FUNCTION regclass_kind(regclass) RETURNS text AS $$
  SELECT CASE pg.relkind
	WHEN 'r' THEN 'TABLE'
	WHEN 'i' THEN 'INDEX'
	WHEN 'S' THEN 'SEQUENCE'
	WHEN 'v' THEN 'VIEW'
	WHEN 'c' THEN 'COMPOSITE'
	WHEN 't' THEN 'TOAST TABLE'
  END
  FROM pg_class pg WHERE pg.oid = $1;
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** entity_kind(oid) -> kind of entity
CREATE OR REPLACE
FUNCTION entity_kind(oid) RETURNS text AS $$
  SELECT COALESCE(
	regclass_kind($1),
	(SELECT 'FUNCTION'::text FROM pg_proc WHERE $1 = oid),
	(SELECT 'TYPE'::text FROM pg_type WHERE $1 = oid)
  )
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** regclass_attributes(regclass) -> non-system attributes of entity
CREATE OR REPLACE
FUNCTION regclass_attributes(regclass) RETURNS SETOF name_id_pairs AS $$
  SELECT (attname, atttypid)::name_id_pairs
  FROM pg_attribute
  WHERE attrelid = $1
  AND attnum > 0 ORDER BY attnum
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** name_type_text(name_id_pairs) -> as nice text
CREATE OR REPLACE
FUNCTION name_type_text(name_id_pairs) RETURNS TEXT AS $$
  SELECT COALESCE($1.name || ' ', '')  || regtype_name($1.id)
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** regclass_text(regclass) -> nice text summary of "class" entity
CREATE OR REPLACE
FUNCTION regclass_text(regclass) RETURNS text AS $$
	SELECT regclass_kind($1)
	|| ' '
	|| regclass_name($1)
	|| '( '
	|| array_to_string( ARRAY( SELECT name_type_text(x) FROM regclass_attributes($1) x ), ', ' )
	|| ' )'
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** regproc_name(regproc) -> procedure name
CREATE OR REPLACE
FUNCTION regproc_name(regproc) RETURNS text AS $$
	SELECT $1::text
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** regprocedure_name(regprocedure) -> procedure name
CREATE OR REPLACE
FUNCTION regprocedure_name(regprocedure) RETURNS text AS $$
	SELECT $1::regproc::text
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** entity_name(oid) -> entity name
CREATE OR REPLACE
FUNCTION entity_name(oid) RETURNS text AS $$
  SELECT COALESCE(
	regtype_name($1),
	regproc_name($1),
	regclass_name($1)
  )
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** regproc_arguments_inout(names, types) -> arguments of given procedure
CREATE OR REPLACE
FUNCTION regproc_arguments_inout(text[], oid[], int2) RETURNS SETOF name_id_pairs AS $$
    SELECT ( COALESCE( $1[i],  '$' || i::text ), $2[i] )::name_id_pairs
    FROM generate_series(1, $3) i
$$ LANGUAGE SQL;

-- ** regproc_arguments_in(names, types) -> arguments of given procedure
CREATE OR REPLACE
FUNCTION regproc_arguments_in(text[], oidvector, int2) RETURNS SETOF name_id_pairs AS $$
    SELECT ( $1[i], $2[i-1] )::name_id_pairs
    FROM generate_series(1, $3) i
$$ LANGUAGE SQL;

-- ** regprocedure_arguments(regprocedure) -> arguments of given procedure
CREATE OR REPLACE
FUNCTION regprocedure_arguments(regprocedure) RETURNS SETOF name_id_pairs AS $$
  SELECT CASE WHEN  proallargtypes IS NOT NULL THEN
	regproc_arguments_inout(proargnames, proallargtypes, pronargs)
  ELSE
	regproc_arguments_in(proargnames, proargtypes, pronargs)
  END
  FROM pg_proc WHERE oid = $1
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** regprocedure_return(regprocedure) -> postgresql representation of procedure return type
CREATE OR REPLACE
FUNCTION regprocedure_return(regprocedure) RETURNS text AS $$
  SELECT CASE WHEN proretset THEN 'SETOF ' ELSE '' END
	|| CASE WHEN prorettype = 'void'::regtype THEN NULL ELSE regtype_name(prorettype) END
  FROM pg_proc WHERE oid = $1
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** regprocedure_text(regprocedure) -> nice text summary of procedure entity
CREATE OR REPLACE
FUNCTION regprocedure_text(regprocedure) RETURNS text AS $$
  SELECT 'FUNCTION '
	||  regprocedure_name($1)
	|| '( '
	|| array_to_string( ARRAY( SELECT name_type_text(x) FROM regprocedure_arguments($1) x ), ', ' )
	|| ' )'
	|| ' RETURNS '
	|| COALESCE(regprocedure_return($1), 'void')
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** myproc_text(regprocedure) -> nice text summary of procedure entity
CREATE OR REPLACE
FUNCTION myproc_text(regprocedure) RETURNS text AS $$
  SELECT regprocedure_name($1)
	|| '( '
	|| array_to_string( ARRAY( SELECT name_type_text(x) FROM regprocedure_arguments($1) x ), ', ' )
	|| ' )'
	|| COALESCE(' -> ' || regprocedure_return($1), '')
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- ** entity_text(oid) -> nice text summary of entity
CREATE OR REPLACE
FUNCTION entity_text(oid) RETURNS text AS $$
  SELECT COALESCE(
	regtype_text($1),
	regclass_text($1),
	myproc_text($1)
  )
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- * Summary views

CREATE OR REPLACE
VIEW the_module_entities(module, entity) AS
  SELECT module_name(provider), entity_text(entity)
  FROM module_entities;

CREATE OR REPLACE
VIEW the_entities(module, entity) AS
  SELECT module_name(provider), entity_kind(entity) || ' ' || entity_name(entity)
  FROM module_entities;

CREATE OR REPLACE
VIEW the_entities_required(requiring_module, requiring_entity, required_module, required_entity) AS
  SELECT
	module_name(requiring.provider) AS "requiring_module",
	entity_kind(requiring.entity) || ' ' || entity_name(requiring.entity) AS "requiring_entity",
	module_name(required.provider) AS "required_module",
	entity_kind(required.entity) || ' ' || entity_name(required.entity) AS "required_entity"
	FROM module_entities requiring, module_entities required, required_entities ent
	WHERE requiring.entity = ent.requiring
	AND required.entity = ent.required;

-- * module_provides function family

-- ** module_functions

-- ~~~ record_module_entity(module, entity) -> void
CREATE OR REPLACE
FUNCTION record_module_entity(oid, oid) RETURNS void AS $$
  BEGIN
    BEGIN
      INSERT INTO module_entities(provider, entity) VALUES($1, $2);
    EXCEPTION
      WHEN unique_violation THEN
            -- evidence of another thread
    END;
  END;
$$ LANGUAGE plpgsql STRICT;

-- +++ module_provides(oid) -> a nice description of the entity
-- need this to fail if current module not registered
CREATE OR REPLACE
FUNCTION module_provides(oid) RETURNS TEXT AS $$
  SELECT record_module_entity( id, $1 ) FROM current_module;
  SELECT entity_text($1)
$$ LANGUAGE sql STRICT;

-- * Module Declarations

SELECT module_file_id('Util-SQL/util-modules-schema-code.sql', '$Id: util-modules-schema-code.sql,v 1.2 2007/07/24 04:27:47 greg Exp greg $');

SELECT module_requires('util-modules-schema');

SELECT module_provides('the_required_modules'::regclass);
SELECT module_provides('the_current_module'::regclass);
SELECT module_provides('the_module_entities'::regclass);
SELECT module_provides('module_file_id(TEXT, TEXT)'::regprocedure);
SELECT module_provides('module_requires(TEXT)'::regprocedure);
SELECT module_provides('module_provides(oid)'::regprocedure);
