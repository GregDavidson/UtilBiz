-- * Header  -*-Mode: sql;-*-
SELECT module_file_id('Util-SQL/util-str.sql', '$Id: util-str.sql,v 1.1 2007/07/24 04:27:47 greg Exp greg $');

--	PostgreSQL String Utilities Code

-- ** Copyright

--	Copyright (c) 2005 - 2007, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

SELECT module_requires('util-modules-schema-code');

-- * misc

CREATE OR REPLACE
FUNCTION str_comma(text, text) RETURNS text AS $$
  SELECT CASE
    WHEN $1 = '' THEN $2
    WHEN $2 = '' THEN $1
    ELSE $1 || ',' || $2
  END
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION str_comma(text, text) IS
'cats args, with comma when both non-empty';

-- * string trimming

CREATE OR REPLACE
FUNCTION str_trim_left(text) RETURNS TEXT AS $$
  SELECT regexp_replace($1,'^[[:space:]]+','')
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION str_trim_right(text) RETURNS TEXT AS $$
  SELECT regexp_replace($1,'[[:space:]]+$','')
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION str_trim(text) RETURNS TEXT AS $$
  SELECT str_trim_left(str_trim_right($1))
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION str_trim_deep(text) RETURNS TEXT AS $$
  SELECT regexp_replace(str_trim($1),'[[:space:]]+',' ', 'g')
$$ LANGUAGE sql STRICT IMMUTABLE;

-- * strings and patterns

-- still used in VXML/vxml-attr.sql - rewrite when get the chance!
-- ++ substring_pair(text, pat1 regexp, pat2 regexp) -> (pat1 text, pat2 text)
CREATE OR REPLACE
FUNCTION substring_pair(text, text, text, OUT text, OUT text) AS $$
  SELECT substring($1, $2), substring($1, $3)
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION substring_pair(text, text, text, OUT text, OUT text) IS
'deprecated - use regexp_matches instead!';

-- ** string_to_array_regexp(string text, pattern text) -> text[]
CREATE OR REPLACE
FUNCTION string_to_array_regexp(original_string text, pattern text)
RETURNS text[] AS $$
  DECLARE
    str TEXT := original_string; -- we will split this up, left to right
    str_from_pattern TEXT;	--substring from first occurrance of pattern to the end
    split TEXT[] := '{ }';
    pattern_to_end CONSTANT TEXT := '(' || pattern || '.*)$';
    pattern_at_front CONSTANT TEXT := '^(' || pattern || ')';
  BEGIN
    LOOP
      -- invariant: array_to_string(split, --separators--) || str = original_string
      str_from_pattern := substring(str FROM pattern_to_end);
      IF str_from_pattern IS NULL THEN
      -- invariant: array_to_string(split, --separators--) || str = original_string
        RETURN split || str;
      END IF;
      DECLARE
        str_len INTEGER := char_length(str);
        str_from_pattern_len INTEGER := char_length(str_from_pattern);
        str_before_pattern TEXT := substring(str FROM 1 FOR str_len - str_from_pattern_len);
        pat_str TEXT := substring(str_from_pattern FROM pattern_at_front);
      BEGIN
        -- invariant: str_before_pattern || str_from_pattern = str
        IF pat_str = '' THEN
          RETURN split || str_from_pattern;  -- prevent infinite loop!
        END IF;
        split := split || str_before_pattern;
        -- str_before_pattern || pat_str || new str = current str
        str := substring(str FROM str_len - str_from_pattern_len + char_length(pat_str) + 1);
      END;
    END LOOP;
    RETURN split;
  END;
$$ LANGUAGE plpgsql;

-- ** split_string_by_pattern(string text, pattern text) -> text[]
CREATE OR REPLACE
FUNCTION split_string_by_pattern(original_string text, pattern text)
RETURNS text[] AS $$
  DECLARE
    str TEXT := original_string; -- we will split this up, left to right
    str_from_pattern TEXT;	--substring from first occurrance of pattern to the end
    split TEXT[] := '{ }';
    pattern_to_end CONSTANT TEXT := '(' || pattern || '.*)$';
    pattern_at_front CONSTANT TEXT := '^(' || pattern || ')';
  BEGIN
    LOOP
      -- invariant: array_to_string(split, '') || str = original_string
      str_from_pattern := substring(str FROM pattern_to_end);
      IF str_from_pattern IS NULL THEN
      -- invariant: array_to_string(split, '') || str = original_string
        RETURN split || str;
      END IF;
      DECLARE
        str_len INTEGER := char_length(str);
        str_from_pattern_len INTEGER := char_length(str_from_pattern);
        str_before_pattern TEXT := substring(str FROM 1 FOR str_len - str_from_pattern_len);
        pat_str TEXT := substring(str_from_pattern FROM pattern_at_front);
      BEGIN
        -- invariant: str_before_pattern || str_from_pattern = str
        IF pat_str = '' THEN
          RETURN split || str_from_pattern;  -- prevent infinite loop!
        END IF;
        split := split || str_before_pattern || pat_str;
        -- str_before_pattern || pat_str || new str = current str
        str := substring(str FROM str_len - str_from_pattern_len + char_length(pat_str) + 1);
      END;
    END LOOP;
    RETURN split;
  END;
$$ LANGUAGE plpgsql;
