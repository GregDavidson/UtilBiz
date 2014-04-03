-- * Header  -*-Mode: sql;-*-
SELECT module_file_id('Util-SQL/util-singular-plurals.sql', '$Id$');

--	PostgreSQL Singular Plurals Utility Code

-- ** Copyright

--	Copyright (c) 2005 - 2006, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Depends

SELECT module_requires('util-modules-schema-code');

-- System Context: We need a convenient way to automatically derive
-- singular terms for constructor functions, etc. from plural terms for types.

-- The full rules for English are pretty fancy.  Here's how we make it easier:
-- (1) We don't use terms which are the same singular or plural, e.g. data.
-- (2) We only support deriving singular from plural, not vice versa.
-- (3) We support the most common rules algorithmically:
-- (4) All other pairs are simply placed in a table as needed.

CREATE TABLE irregular_plurals_singulars (
	plural text,
	singular text,
	PRIMARY KEY (plural, singular),
	CHECK(plural != singular)
);
COMMENT ON TABLE irregular_plurals_singulars IS
'Pairs of irregular plural/singular words, excuding words which
are the same when singular or plural';

CREATE OR REPLACE
FUNCTION irregular_plural_singular(text, text) RETURNS void AS $$
BEGIN
	INSERT INTO irregular_plurals_singulars(plural, singular) VALUES ($1, $2);
	EXCEPTION WHEN unique_violation THEN NULL;
END
$$ LANGUAGE plpgsql STRICT;
COMMENT ON FUNCTION irregular_plural_singular(text, text) IS
'Constructor for TABLE irregular_plurals_singulars';
	
CREATE OR REPLACE
FUNCTION str_trim_right(text, integer) RETURNS text AS $$
	SELECT substring($1 FOR length($1) - $2)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION plural_singular(text) RETURNS text AS $$
	SELECT COALESCE(
		(SELECT singular FROM irregular_plurals_singulars WHERE plural = $1),
		CASE
			WHEN $1 ILIKE '%sses' THEN string_trim_right($1, 2)
			WHEN $1 ILIKE '%en' THEN string_trim_right($1, 2) -- Deutch
			WHEN $1 ILIKE '%s' THEN string_trim_right($1, 1)
		END
	)
$$ LANGUAGE SQL STRICT;
COMMENT ON FUNCTION plural_singular(text) IS 'Return a singular term given its plural.';

-- * Provides

SELECT module_provides('irregular_plural_singular(text, text)'::regprocedure);
SELECT module_provides('plural_singular(text)'::regprocedure);
