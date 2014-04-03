-- * Header  -*-Mode: sql;-*-
-- $Id: utility_xml_test.sql,v 1.1 2008/04/16 02:57:50 lynn Exp $

--	PostgreSQL XML Utilities Test Code

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

SELECT xml_text('<g>Jean Paul</g> <f>Gaultier</f> de Sade');

SELECT xml_attr('a', '<g a="Bob,Rob">Robert</g>'::xml);

SELECT xml_subtext('g', '<g a="Bob,Rob">Robert</g>'::xml);


