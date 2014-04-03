-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * Concept Slots and Substitution

CREATE OR REPLACE
FUNCTION html_no_subs() RETURNS text[] AS $$
  SELECT '{}'::text[]
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION slot_subs(text, text[], slot_index_pairs[])
RETURNS text AS $$
  SELECT CASE WHEN head IS NULL THEN $1
  ELSE slot_subs(
    replace( $1, (head).slot, ($2)[(head).index] ),
    $2,
    array_tail($3)
  ) END FROM array_head($3) head
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION slot_subs(text, text[], slot_index_pairs[]) IS
'slot_subs(text, substitutions, found-slots): returns text after all
found-slots have been replaced by the indicated replacement in the
substitutions-array';

CREATE OR REPLACE
FUNCTION slot_subs(text, text[])
RETURNS text AS $$
  SELECT slot_subs( $1, $2,
    ARRAY(
      SELECT ROW(x[1], x[2]::integer)::slot_index_pairs
      FROM regexp_matches($1, '(<([1-9][0-9]*)>)', 'g') x
    )
  );
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION slot_subs(text, text[]) IS
'slot_subs(text, substitutions-array): returns text after all slots in
text have been replaced by the indicated replacement in the
substitutions-array';

-- * Concept HTML Attributes

-- ** to text

CREATE OR REPLACE
FUNCTION html_attr_name_text(html_attr_names) RETURNS text AS $$
  SELECT translate( substring($1::text FROM 11), '_', '-' )
$$ LANGUAGE sql STRICT IMMUTABLE;


CREATE OR REPLACE
FUNCTION html_attr_val_text(html_attr_vals) RETURNS text AS $$
-- introduce character attributes for illegal characters!!
  SELECT $1::text
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION html_attr_text(html_attributes) RETURNS text AS $$
  SELECT ' ' || html_attr_name_text(($1).attr)
    || '="' || html_attr_val_text(($1).val) || '"'
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_attr_text(html_attributes, text[])
RETURNS text AS $$
  SELECT ' '
  || html_attr_name_text(($1).attr)
  || '="'
  || html_attr_val_text(slot_subs(($1).val::text, $2)::html_attr_vals)
  || '"'
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION html_attr_text(html_attributes, text[]) IS
'html_attr_text(html_attributes, substitutions-array): returns
html attributes text after replacing any slots in the attribute
value with the indicated replacement in the substitutions-array';

-- ** html_attributes constructors

CREATE OR REPLACE
FUNCTION html_attr(html_attr_names, maybe_html_attr_vals)
RETURNS html_attributes AS $$
  SELECT ROW($1, $2::html_attr_vals)::html_attributes
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION maybe_attr_array(html_attr_names, maybe_html_attr_vals)
RETURNS html_attributes[] AS $$
  SELECT CASE WHEN $2 IS NULL THEN '{}'::html_attributes[]
         ELSE ARRAY[html_attr($1, $2)]
  END
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION maybe_attr_array(html_attr_names, html_attr_vals,bool)
RETURNS html_attributes[] AS $$
  SELECT CASE WHEN NOT $3  THEN '{}'::html_attributes[]
         ELSE ARRAY[html_attr($1, $2)]
  END
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_no_attrs() RETURNS html_attributes[] AS $$
  SELECT '{}'::html_attributes[]
$$ LANGUAGE sql STRICT;

-- * Concept cdata

CREATE OR REPLACE
FUNCTION html_cdata_text(html_cdata_vals) RETURNS text AS $$
-- introduce character attributes for illegal characters!!
  SELECT $1::text
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_cdata_text(html_cdata_vals, text[]) RETURNS text AS $$
  SELECT html_cdata_text(slot_subs($1::text, $2)::html_cdata_vals)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION html_cdata_text(html_cdata_vals, text[]) IS
'html_cdata_text(cdata text, substitutions-array): returns cdata text
after replacing any slots with the indicated replacement in the
substitutions-array';

-- * Concept HTML -- ** html_tags

CREATE OR REPLACE
FUNCTION html_tag_text(html_tags) RETURNS text AS $$
  SELECT substring($1::text FROM 10)
$$ LANGUAGE sql STRICT;

-- ** html_elements

-- ** finding html_elems

-- *** opening and closing html_elements

-- ??? test for empty array might not be needed even though
-- Lynn got an error once.
CREATE OR REPLACE
FUNCTION html_elem_open(html_elements) RETURNS text AS $$
  SELECT '<' || html_tag_text(($1).tag) ||
      CASE array_is_empty(($1).attrs) 
      WHEN true THEN ''
      ELSE array_to_string( ARRAY(
	      		    SELECT html_attr_text(x) 
			    FROM array_to_list(($1).attrs) x
    	   		    ),''
           )
      END
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_open(html_elements, subs text[]) RETURNS text AS $$
  SELECT '<' || html_tag_text(($1).tag) ||
    array_to_string(
      ARRAY(
	SELECT html_attr_text(x, $2) FROM array_to_list(($1).attrs) x
	       WHERE NOT array_is_empty(($1).attrs)
    ),
    ''
  )
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_close(html_tags) RETURNS text AS $$
  SELECT '</' || html_tag_text($1) || '>'
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_close(html_elements) RETURNS text AS $$
  SELECT html_elem_close(($1).tag)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_close() RETURNS text AS $$
  SELECT ' />'::text
$$ LANGUAGE sql STRICT IMMUTABLE;

-- *** html element constructors

CREATE OR REPLACE
FUNCTION html_element(html_tags, html_attributes[])
RETURNS html_elements AS $$
  SELECT ROW($1, $2)::html_elements
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_element(html_tags, html_attributes)
RETURNS html_elements AS $$
  SELECT html_element($1, ARRAY[$2])
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_element(html_tags)
RETURNS html_elements AS $$
  SELECT html_element($1, '{}'::html_attributes[])
$$ LANGUAGE sql STRICT;

-- *** html element text

CREATE OR REPLACE
FUNCTION html_elem_text(html_elements) RETURNS text AS $$
  SELECT html_elem_open($1) || html_elem_close()
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION html_elem_text(html_elements) IS
'return text of leaf element';

CREATE OR REPLACE
FUNCTION html_elem_text(html_elements, text[]) RETURNS text AS $$
  SELECT html_elem_open($1, $2) || html_elem_close()
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION html_elem_text(html_elements, text[]) IS
'return text of leaf element after appropriate substitutions';

CREATE OR REPLACE
FUNCTION html_elem_text(html_elements, text[], text) RETURNS text AS $$
  SELECT html_elem_open($1, $2) || '>' || $3 || html_elem_close($1)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION html_elem_text(html_elements, text[], text) IS
'return text of one-line element after appropriate substitutions';

CREATE OR REPLACE
FUNCTION maybe_html_elem_texts(html_elements, text[], text) RETURNS text[] AS $$
  SELECT CASE WHEN $3 IS NULL THEN '{}'::text[] 
  	 ELSE
	 ARRAY[html_elem_open($1, $2) || '>' || $3 || html_elem_close($1)]
	 END
$$ LANGUAGE sql;
COMMENT ON FUNCTION maybe_html_elem_texts(html_elements, text[], text) IS
'return text of one-line element after appropriate substitutions
 IF empty $3, then return empty array';

CREATE OR REPLACE
FUNCTION html_elem_texts(html_elements, subs text[], contents text[])
RETURNS text[] AS $$
  SELECT ARRAY[ html_elem_open($1, $2) || '>' ]
    || ARRAY( SELECT ' ' || line FROM array_to_list($3) line )
    || html_elem_close($1)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION html_elem_texts(html_elements, text[], text[]) IS
'html_elem_texts(element, substitutions, html content lines) returns
array of element lines after appropriate substitutions on element;
element encloses its contents; substitutions have already been carried
out on content; contents will get extra indentations each time they
are enclosed in a new element!';

CREATE OR REPLACE
FUNCTION html_elem_texts(html_elements, subs text[], contents text)
RETURNS text[] AS $$
  SELECT html_elem_texts($1,$2,	ARRAY[$3]);
$$ LANGUAGE sql STRICT;

-- * html_elem_text + html_element convenience functions

CREATE OR REPLACE
FUNCTION html_elem_text(html_tags, html_attributes[], text[])
RETURNS text AS $$
  SELECT html_elem_text(html_element($1, $2), $3)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_text(html_tags, html_attributes, text[])
RETURNS text AS $$
  SELECT html_elem_text(html_element($1, ARRAY[$2]), $3)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_text(html_tags, html_attributes[], text[], text)
RETURNS text AS $$
  SELECT html_elem_text(html_element($1, $2), $3, $4)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_text(html_tags, html_attributes, text[], text)
RETURNS text AS $$
  SELECT html_elem_text(html_element($1, $2), $3, $4)
$$ LANGUAGE sql STRICT;

-- function fails with html_tags typed parameter
CREATE OR REPLACE
FUNCTION html_elem_text(text)
RETURNS text AS $$
  SELECT html_elem_text(html_element($1::html_tags), html_no_subs())
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_text(html_tags, text)
RETURNS text AS $$
  SELECT html_elem_text(html_element($1), html_no_subs(), $2)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_texts(html_tags, html_attributes[], text[], text[])
RETURNS text[] AS $$
  SELECT html_elem_texts(html_element($1, $2), $3, $4)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_texts(html_tags, html_attributes, text[], text[])
RETURNS text[] AS $$
  SELECT html_elem_texts(html_element($1, $2), $3, $4)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_texts(html_tags, html_attributes[], text[], text)
RETURNS text[] AS $$
  SELECT html_elem_texts(html_element($1, $2), $3, $4)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_texts(html_tags, html_attributes, text[], text)
RETURNS text[] AS $$
  SELECT html_elem_texts(html_element($1, $2), $3, $4)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_texts(html_tags, text[])
RETURNS text[] AS $$
  SELECT html_elem_texts(html_element($1), html_no_subs(), $2)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION html_elem_texts(html_tags, text)
RETURNS text[] AS $$
  SELECT html_elem_texts(html_element($1), html_no_subs(), $2)
$$ LANGUAGE sql STRICT;

-- * html element functions 11

CREATE OR REPLACE
FUNCTION php_literal(text) RETURNS text AS $$
  SELECT quote_literal('<?php ' || $1 || '?>')
$$ LANGUAGE sql STRICT;

-- * textarea tags

CREATE OR REPLACE
FUNCTION html_textarea(text,text,text,text,text) RETURNS text AS $$
  SELECT html_elem_text('html_tag_textarea',
	     html_no_attrs()
             || maybe_attr_array('html_attr_name',$1)
             || maybe_attr_array('html_attr_class',$2)
             || maybe_attr_array('html_attr_id',$3)
             || maybe_attr_array('html_attr_readonly',$4),
	    html_no_subs(),
	    COALESCE($5,'')
  )
$$ LANGUAGE sql;

-- * input tags
CREATE OR REPLACE
FUNCTION html_input(text,text,text,text,html_attributes[])
RETURNS text AS $$
  SELECT html_elem_text('html_tag_input',
	      html_no_attrs()
	        || maybe_attr_array('html_attr_type', $1)
	  	|| maybe_attr_array('html_attr_name', $2)
	  	|| maybe_attr_array('html_attr_class', $3)
	  	|| maybe_attr_array('html_attr_id', $4) 
   	      	 || $5,
   html_no_subs()
  )
$$ LANGUAGE sql;

COMMENT ON FUNCTION html_input(text,text,text,text,html_attributes[]) IS $$
<input type="$1" name="$2" class="$3" id="$4" 
$5 is an array of extra  attribute such as onfocus
$$;

CREATE OR REPLACE
FUNCTION html_input(text,text,text,text)
RETURNS text AS $$
  SELECT html_input($1,$2,$3,$4,'{}'::html_attributes[])
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_input(text,text,text,text,text)
RETURNS text AS $$
  SELECT html_input($1,$2,$3,$4,ARRAY[html_attr('html_attr_value',$5)])
$$ LANGUAGE sql;

-- * radio button with label
-- html_radio (name, class, id/value, extra attrs for radio label class, label)
CREATE OR REPLACE
FUNCTION html_radio(text,text,text,html_attributes[],text,text) RETURNS text[] AS $$
  SELECT ARRAY[
  	 html_input('radio',$1,$2,$3, ARRAY[
  	     html_attr('html_attr_value',$3)]
	     || $4 )
	 ] || ARRAY[
         html_elem_text('html_tag_label', ARRAY[
	     html_attr('html_attr_for',$3),
	     html_attr('html_attr_class',$5)],
	     html_no_subs(),
	     $6)
       ]
$$ LANGUAGE sql;

-- * checkbox with label
-- html_checkbox (name, class, id/value, label class, label)
CREATE OR REPLACE
FUNCTION html_checkbox(text,text,text,html_attributes[],text,text) RETURNS text[] AS $$
  SELECT ARRAY[
  	 html_input('checkbox',$1,$2,$3, ARRAY[
  	     html_attr('html_attr_value',$3)]
	     || $4)
	 ] || ARRAY[
         html_elem_text('html_tag_label', ARRAY[
	     html_attr('html_attr_for',$3),
	     html_attr('html_attr_class',$5)],
	     html_no_subs(),
	     $6)
       ]
$$ LANGUAGE sql;

-- * select and option tags

CREATE OR REPLACE
FUNCTION html_select_option(bool,bool,html_attr_vals,html_cdata_vals, 
	                    maybe_html_attr_vals, maybe_html_attr_vals) 
RETURNS html_select_options AS $$
  SELECT ROW($1, $2, $3, $4, $5, $6)::html_select_options
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_select_option(html_attr_vals,html_cdata_vals) 
RETURNS html_select_options AS $$
  SELECT html_select_option(false, false, $1, $2, null,null)
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION html_option(html_select_options) RETURNS text AS $$
  SELECT html_elem_text('html_tag_option',
  	 html_no_attrs()
  	 || maybe_attr_array('html_attr_value',($1).val)
	 || maybe_attr_array('html_attr_selected','selected', ($1).selected)
	 || maybe_attr_array('html_attr_disabled','disabled', ($1).disabled)
	 || maybe_attr_array('html_attr_id',($1).id)
	 || maybe_attr_array('html_attr_onclick',($1).js),
	 html_no_subs(),
	 ($1).cdata
)
$$ LANGUAGE sql strict;

CREATE OR REPLACE
FUNCTION html_select(text,text,text,text,html_attributes[],html_select_options[])
RETURNS text[] AS $$
  SELECT html_elem_texts(
  	   'html_tag_select',
	     html_no_attrs()
	     || maybe_attr_array('html_attr_size', $1)
	     || maybe_attr_array('html_attr_name', $2)
	     || maybe_attr_array('html_attr_class', $3)
	     || maybe_attr_array('html_attr_id', $4) 
   	     || $5,
   	    html_no_subs(),
	    ARRAY(SELECT html_option(x) FROM array_to_list($6) x)
  )
$$ LANGUAGE sql;

-- * html element functions

CREATE OR REPLACE
FUNCTION php_literal(text) RETURNS text AS $$
  SELECT quote_literal('<?php ' || $1 || '?>')
$$ LANGUAGE sql STRICT;

-- * input tags
CREATE OR REPLACE
FUNCTION html_input(text,text,text,text,html_attributes[])
RETURNS text AS $$
  SELECT html_elem_text(
	'html_tag_input',
	html_no_attrs()
	|| maybe_attr_array('html_attr_type', $1)
	|| maybe_attr_array('html_attr_name', $2)
	|| maybe_attr_array('html_attr_class', $3)
	|| maybe_attr_array('html_attr_id', $4) 
    	|| $5,
   html_no_subs()
  )
$$ LANGUAGE sql;

COMMENT ON FUNCTION html_input(text,text,text,text,html_attributes[]) IS $$
<input type="$1" name="$2" class="$3" id="$4" 
$5 is an array of extra  attribute such as onfocus
$$;

CREATE OR REPLACE
FUNCTION html_input(text,text,text,text)
RETURNS text AS $$
  SELECT html_input($1,$2,$3,$4,'{}'::html_attributes[])
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_input(text,text,text,text,text)
RETURNS text AS $$
  SELECT html_input($1,$2,$3,$4,ARRAY[html_attr('html_attr_value',$5)])
$$ LANGUAGE sql;

-- helper function for various divs
CREATE OR REPLACE
FUNCTION html_div(text,text,text,text[]) RETURNS text[] AS $$
   SELECT html_elem_texts(
	'html_tag_div',
	  html_no_attrs()
	  ||maybe_attr_array('html_attr_class', $1)
	  ||maybe_attr_array('html_attr_id', $2)
	  ||maybe_attr_array('html_attr_name', $3) 
   	,
   	html_no_subs(),
	$4
  )
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_class_div(text,text[]) RETURNS text[] AS $$
  select html_div($1,null,null,$2)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_id_div(text,text[]) RETURNS text[] AS $$
  select html_div(null,$1,null,$2)
$$ LANGUAGE sql;

-- helper function for various spans
CREATE OR REPLACE
FUNCTION html_span_text(text,text,text,text) RETURNS text AS $$
   SELECT html_elem_text(
   	     html_element(
	       'html_tag_span',
	        maybe_attr_array('html_attr_class', $1)
	        ||maybe_attr_array('html_attr_id', $2)
	        ||maybe_attr_array('html_attr_name', $3)
	     ), 
	   html_no_subs(),
	   $4
  )
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_span(text,text,text,text[]) RETURNS text[] AS $$
   SELECT html_elem_texts(
	'html_tag_span',
	  maybe_attr_array('html_attr_class', $1)
	  ||maybe_attr_array('html_attr_id', $2)
	  ||maybe_attr_array('html_attr_name', $3) 
   	,
   	html_no_subs(),
	$4
  )
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_span(text) RETURNS text[] AS $$
  select html_span(null,null,null,array[$1])
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_class_span(text,text) RETURNS text[] AS $$
  select html_span($1,null,null,array[$2])
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_class_span(text,text[]) RETURNS text[] AS $$
  select html_span($1,null,null,$2)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_id_span(text,text[]) RETURNS text[] AS $$
  select html_span(null,$1,null,$2)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_br() RETURNS text AS $$
  SELECT html_elem_text(html_element('html_tag_br'))
$$ LANGUAGE sql STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION html_hr() RETURNS text AS $$
  SELECT html_elem_text(html_element('html_tag_hr'))
$$ LANGUAGE sql STRICT IMMUTABLE;

-- returns <a class="$1">$2<span>$3</span></a>
-- uses CSS to ccreate a tooltip out of $3
CREATE OR REPLACE
FUNCTION tooltip(text,text,text) RETURNS text[] AS $$
 SELECT html_elem_texts(
 	'html_tag_a', ARRAY[html_attr('html_attr_class',$1)],
	html_no_subs(),
	$2
	|| html_span($3))
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION html_xsl() RETURNS xml AS $$
  SELECT XMLPARSE(DOCUMENT
      E'<!DOCTYPE xsl:stylesheet [<!ENTITY nbsp "&#160;">]>\n'
   || E'<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">\n'
   || E'<xsl:output method="html" version="4.011" indent="yes" encoding="US-ASCII"/>\n'
   || E'<xsl:output doctype-system="http://www.w3.org/TR/html4/strict.dtd"/>\n'
   || E'<xsl:output doctype-public="-//W3C//DTD HTML 4.01//EN"/>\n'
   || E'<xsl:template match="foo">\n'
   || E'</xsl:template>\n'
   || E'<xsl:template match="bar">\n'
   || E'<xsl:apply-templates select="@*|node()"/>\n'
   || E'</xsl:template>\n'
   || E'<xsl:template match="@*|node()">\n'
   || E'<xsl:copy>\n'
   || E'<xsl:apply-templates select="@*|node()"/>\n'
   || E'</xsl:copy>\n'
   || E'</xsl:template>\n'
   || E'</xsl:stylesheet>'
)
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE
FUNCTION xml_html(text) RETURNS text AS $$
  SELECT xslt_process($1, html_xsl()::text)
$$ LANGUAGE sql IMMUTABLE;

