#!/usr/bin/awk -f
debug {print "#input: " $0}
/^#/ || /^\t/ || $1 ~ /:$/{
  print
  next
}
/^[[:space:]*]/ {
  print ""		# normalize blank lines
  next
}
$1 ~ /\.sql$/ {
  target = $1 "-out"
}
$1 ~ /\.c$/ {
  target = gensub(/\.c$/, ".o", 1, $1)
}
target == ""{
  print "#no-target: " $0
  next
}
debug {print "#target: " target}
NF==1 {
  print target ": " $1 last_target
}
NF >1{
  if ($2 == "%")
    $2 = last_target
  print target ": " $0
}
$1 !~ /-test/{
  last_target = " " target
  if (debug) print "#last_target = " last_target
}
{target=""}
