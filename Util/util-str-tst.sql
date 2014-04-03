-- * Header  -*-Mode: sql;-*-
-- $Id: utility_str_test.sql,v 1.1 2008/04/16 02:57:50 lynn Exp $

--	PostgreSQL String Utilities Test Code

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

SELECT '''' || str_trim_deep(E'  \t  \n blah     blah \t blah  ') || '''';

