-- * Header  -*-Mode: sql;-*-
SELECT module_file_id('Util-SQL/util-bitset-test.sql', '$Id: util-bitset-test.sql,v 1.1 2007/07/24 04:27:47 greg Exp greg $');

--	PostgreSQL Bitset Utilities Test Code

-- ** Copyright

--	Copyright (c) 2005 - 2008, J. Greg Davidson.
--	Although it is my intention to make this code available
--	under a Free Software license when it is ready, this code
--	is currently not to be copied nor shown to anyone without
--	my permission in writing.

-- ** Depends

SELECT module_requires('util-bitset-code');

SELECT test_func(
  'empty_bitset_chunk()',
  empty_bitset_chunk(), 0::bitset_chunks_
);

SELECT test_func(
  'to_bitset_chunk(integer)',
  to_bitset_chunk(0), 1::bitset_chunks_
);


SELECT test_func(
  'to_bitset(integer)',
  to_bitset(0), bitset_box_(to_bitset_chunk(0))
);

SELECT test_func(
  'to_bitset(integer)',
  to_bitset(1), bitset_box_(to_bitset_chunk(1))
);

SELECT test_func(
  'to_bitset(integer)',
  to_bitset(bitset_chunksize_()), bitset_box_(0) || bitset_box_(to_bitset_chunk(0))
);

SELECT test_func(
  'in_bitset(integer, bitsets)',
  in_bitset(0, to_bitset(0))
);

SELECT test_func(
  'in_bitset(integer, bitsets)',
  in_bitset(bitset_chunksize_(), to_bitset(bitset_chunksize_()))
);

SELECT test_func(
  'ni_bitset(integer, bitsets)',
  ni_bitset(0, to_bitset(bitset_chunksize_()))
);

SELECT test_func(
  'bitset_chunk_text(bitset_chunks_)',
  bitset_chunk_text(empty_bitset_chunk()),
  repeat('0', bitset_chunksize_())
);

SELECT test_func(
  'bitset_chunk_text(bitset_chunks_)',
  bitset_chunk_text(to_bitset_chunk(0)),
  repeat('0', bitset_chunksize_()-1) || '1'
);

SELECT test_func(
  'bitset_chunk_text_trimmed(bitset_chunks_)',
  bitset_chunk_text_trimmed(to_bitset_chunk(0)),
  '1'
);

SELECT test_func(
  'bitset_text(bitsets)',
  bitset_text(empty_bitset()),
  '0'
);

SELECT test_func(
  'bitset_text(bitsets)',
  bitset_text(to_bitset(0)),
  '1'
);

SELECT test_func(
  'bitset_text(bitsets)',
  bitset_text(to_bitset(0)),
  '1'
);

SELECT test_func(
  'bitset_text(bitsets)',
  bitset_text(to_bitset(bitset_chunksize_())),
  '1' || repeat('0', bitset_chunksize_())
);

SELECT test_func(
  'to_bitset(integer[])',
  to_bitset(ARRAY[0, 1, bitset_chunksize_()]), bitset_box_(3) || bitset_box_(1)
);

SELECT test_func(
  'in_bitset(integer, bitsets)',
  in_bitset(1, to_bitset(ARRAY[0, 1, bitset_chunksize_()]))
);
