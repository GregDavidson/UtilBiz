# UtilBiz Framework

* Lynn Dobbs and Greg Davidson
* Last build January 2009

UtilBiz is an alpha-level PostgreSQL-based framework for automating
business information.  It is designed to provide a foundation underlying
the customized software of a particular business.  Rather than changing
the foundation, the cutomized code lives in a third schema, on top of
Biz which is on top of Util.  Appropriate permissions restrict the
entry points for staff and clients.

At least one successful online service company uses a descendant of this
code to run their whole business, neatly hidden behind the web-based
interfaces used by staff and customers.  With some further development
the UtilBiz Framework could meet the needs of many businesses.

Parts of the UtilBiz framework were derived from an early version of
the Wicci-Core Framework.  It would be great to have more recent work
on that framework merged into the util schema of UtilBiz.

| Schema	| Purpose
|---------------|--------
| util		| support utilities which have no explicit business content
| biz		| code supporting generic business practices
| *custom*	| your custom business code here!

In many cases code in the *custom* schema will have Classes (Tables) which
extend corresponding Classes in the biz schema.

Within a schema, files are grouped into packages or modules:

| Package	| Purpose
|---------------|--------
| accts		| managing money and transactions
| bills		| accounts receivable; interacting with clients about charges
| client	| managing contacts and clients
| deals		| pricing of goods and services


A file naming convention helps manage the code within a package:

| File Name Pattern	| Reloadable	| Purpose
|-----------------------|---------------|--------
| *-schema.sql 		| No	| data structures and their relationships
| *-code.sql		| Yes	| functions and views serving the data structures
| *-tst-data.sql	| No	| example data for testing
| *-tst.sql		| Yes	| unit test code for the package

The last time this code was built it was all in one directory.  I've just
partitioned the code into Util and Biz subdirectores.  The Makefile and
a few other meta files need to be updated to reflect this.

With your participation this framework will be glorious!

