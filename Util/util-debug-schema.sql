-- * Header

SELECT module_file_id('Util-SQL/util-debug-schema.sql', '$Id: util-debug-schema.sql,v 1.2 2006/11/02 02:04:31 greg Exp greg $');

--	PostgreSQL Utilities
--	Debugging Schema

-- ** Copyright

--	Copyright (c) 2005 - 2006, J. Greg Davidson.
--	Although it is my intention to make this code available
--	under a Free Software license when it is ready, this code
--	is currently not to be copied nor shown to anyone without
--	my permission in writing.

-- ** Provides

-- * Debugging Facilities

-- ** TABLE debug_on_oids
CREATE TABLE debug_on_oids (
  id Oid PRIMARY KEY
);
