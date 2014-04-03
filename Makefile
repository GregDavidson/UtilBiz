# CreditLink Project Makefile
# J. Greg Davidson, 16 July 2008
# DB ?= creditlink_test
DB ?= creditlink
PSQL := /usr/local/pgsql/bin/psql -1 # -1 requires PostgreSQL >= 8.2
MK_DEPS := Bin/make-depends

%.sql-out : %.sql
	set -o pipefail ; $(PSQL) $(DB) -f $< 2>&1 | tee $@-err && mv $@-err $@
%.m4-sql : %.sql-m4
	m4 -P $< >$@
%.m4-sql-out : %.m4-sql
	set -o pipefail ; $(PSQL) $(DB) -f $< 2>&1 | tee $@-err && mv $@-err $@
.PHONY: rcs ci ci-new ci-changed
rcs:
	@ for f in $$(awk '{print $$1}' SOURCE-FILES); do [ -f "RCS/$$f,v" ] || echo -e "new\t$$f"; done
	@ for f in $$(awk '{print $$1}' SOURCE-FILES); do [ -f "RCS/$$f,v" -a "$$f" -nt "RCS/$$f,v" ] && echo -e "changed\t$$f"; done
ci:	ci-new ci-changed
ci-new:
	@ for f in $$(awk '{print $$1}' SOURCE-FILES); do [ -f "RCS/$$f,v" ] || ci -l "$$f"; done
ci-changed:
	@ for f in $$(awk '{print $$1}' SOURCE-FILES); do [ -f "RCS/$$f,v" -a "$$f" -nt "RCS/$$f,v" ] && ci -l "$$f"; done
.PHONY: clean clean.out clean.err clean.db clean.sql clean.tags
clean: clean.out clean.err clean.db clean.sql clean.tags
clean.out:
	rm -f *.sql-out
clean.err:
	rm -f *.sql-out-err
clean.db:
	dropdb $(DB) && createdb $(DB)
clean.sql:
	$(MK_DEPS) SOURCE-FILES >depends.make
clean.tags:
	etags $$(./list-filenames SOURCE-FILES)

include depends.make
