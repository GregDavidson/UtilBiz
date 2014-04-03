-- * Header  -*-Mode: sql;-*-
-- SELECT module_file_id('Util/util_notes_schema.sql', '$Id: util_notes.sql,v 1.2 2008/04/16 02:58:04 lynn Exp $');

--	PostgreSQL Attributed Notes Schema

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

-- SELECT module_requires('util-modules-schema-code');

-- * Note Authors and Notes

-- ** Note Authors

CREATE DOMAIN note_author_ids AS integer NOT NULL;

CREATE SEQUENCE note_author_id_seq START -1 INCREMENT -1;

CREATE OR REPLACE
FUNCTION next_note_author_id() RETURNS note_author_ids AS $$
  SELECT nextval('note_author_id_seq')::note_author_ids
$$ LANGUAGE sql;

CREATE TABLE note_authors (
  id note_author_ids PRIMARY KEY DEFAULT next_note_author_id()
);
COMMENT ON TABLE note_authors IS
'just id values - client code might associate these with a higher level identity system';

ALTER SEQUENCE note_author_id_seq OWNED BY note_authors.id;

SELECT  handles_for('note_authors');

CREATE OR REPLACE
FUNCTION make_note_author(handles, note_author_ids)
RETURNS note_authors_row_handles AS $$
  INSERT INTO note_authors VALUES($2);
  SELECT set_note_authors_row($1, $2)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION make_note_author(handles)
RETURNS note_authors_row_handles AS $$
  SELECT make_note_author($1, next_note_author_id())
$$ LANGUAGE SQL STRICT;

-- ** Attributed notes and their service functions

CREATE DOMAIN note_feature_ids AS integer;

CREATE DOMAIN note_feature_sets AS bitsets;

CREATE TABLE note_features (
  id note_feature_ids PRIMARY KEY,
  name text
);
COMMENT ON TABLE note_features IS
'num rows must equal num bits of note_feature_sets';

CREATE DOMAIN attributed_note_ids AS integer NOT NULL;
CREATE DOMAIN maybe_attributed_note_ids AS integer;
CREATE DOMAIN attributed_note_id_arrays AS integer[] NOT NULL;

CREATE SEQUENCE attributed_note_id_seq;

CREATE OR REPLACE
FUNCTION next_attributed_note_id() RETURNS attributed_note_ids AS $$
  SELECT nextval('attributed_note_id_seq')::attributed_note_ids
$$ LANGUAGE sql;

CREATE TABLE attributed_notes (
  id attributed_note_ids PRIMARY KEY DEFAULT next_attributed_note_id(),
  time_ event_times,
  author_id note_author_ids REFERENCES note_authors,
  note xml,
  features note_feature_sets DEFAULT empty_bitset()
);

ALTER SEQUENCE attributed_note_id_seq OWNED BY attributed_notes.id;

SELECT handles_for('attributed_notes');

-- * Provides

-- SELECT module_provides('notes_on(regclass, integer)'::regprocedure);
-- SELECT module_provides('note_on(regclass, integer, note_author_ids, text)'::regprocedure);
-- SELECT module_provides('note_on(regclass, integer, text, text)'::regprocedure);
