-- cl-web-schema.sql
-- $Id$
-- support for dynamic html as text
-- Lynn Dobbs and Greg Davidson
-- Tuesday 25 November 2008

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

CREATE DOMAIN html AS text NOT NULL;
CREATE DOMAIN maybe_html AS text;
CREATE DOMAIN html_arrays AS text[];

-- * Concept: Slots

-- are these still in use ???
CREATE TYPE slot_index_pairs AS (
  slot text,
  index integer
);

-- * Concept: Attribute

-- ENUM html_attr_names

CREATE DOMAIN html_attr_vals AS text NOT NULL;
CREATE DOMAIN maybe_html_attr_vals AS text;
CREATE DOMAIN html_attr_val_arrays AS text[];

CREATE TABLE html_attributes (
  attr html_attr_names NOT NULL,
  val html_attr_vals
);

CREATE DOMAIN html_cdata_vals AS text NOT NULL;
CREATE DOMAIN maybe_html_cdata_vals AS text;
CREATE DOMAIN html_cdata_val_arrays AS text[];

CREATE TABLE html_elements (
  tag html_tags,
  attrs html_attributes[]
);

CREATE TABLE html_content_elements (
  content text[]
) INHERITS(html_elements);
COMMENT ON TABLE html_content_elements IS
'represents an element with contents';
COMMENT ON COLUMN html_content_elements.content IS
'join with newlines, indent if desired';


CREATE TYPE html_select_options AS (
       selected bool,
       disabled bool,
       val html_attr_vals,
       cdata html_cdata_vals,
       id maybe_html_attr_vals,
       js maybe_html_attr_vals
);
