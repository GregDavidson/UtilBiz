-- * Header  -*-Mode: sql;-*-
-- $Id: utility_xml.sql,v 1.2 2008/05/03 00:11:47 lynn Exp $

--	PostgreSQL XML Utilities Code

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

SELECT module_requires('util-modules-schema-code');

-- ** xml related

CREATE OR REPLACE
FUNCTION xml_text(XML) RETURNS text AS $$
  SELECT str_trim_deep(array_to_string(xpath('//text()', $1)::text[], ' '))
$$ LANGUAGE sql STRICT;

-- xml_attr('a', '<g a="Bob,Rob">Robert</g>'::xml) -->
-- xpath('//attribute::a/text()', '<g a="Bob,Rob">Robert</g>'::xml) -->
-- "Bob,Rob"
CREATE OR REPLACE
FUNCTION xml_attr(text, xml) RETURNS text[] AS $$
  SELECT xpath('//attribute::' || $1, $2)::text[]
$$ LANGUAGE sql STRICT;

-- xml_subtext('g', '<g a="Bob,Rob">Robert</g>'::xml) -->
-- xpath('//g/text()', '<g a="Bob,Rob">Robert</g>'::xml) -->
-- "Robert"
CREATE OR REPLACE
FUNCTION xml_subtext(text, xml) RETURNS text[] AS $$
  SELECT xpath('//' || $1 || '/text()', $2)::text[]
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION xml_subtext_str(text, xml) RETURNS text AS $$
  SELECT array_to_string(xpath('//' || $1 || '/text()', $2),' ')
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION txt2xml(text,text) RETURNS xml AS $$
  SELECT xmlparse(CONTENT '<'||$1||'>'||$2||'</'||$1||'>')
$$ LANGUAGE sql STRICT;
