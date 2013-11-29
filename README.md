mossy
=====

MS SQL Server object script generator, for 2005 and above.

Aims to replicate the abilities of the SMO assemblies distributed by Microsoft. Not there yet.

Object scripts can be generated with use (db context) statements, if exists drop, and permissions.

Objects supported: Tables, views, triggers, procedures, functions (scalar, table, inline).

Tables are the only objects that require manual work. The rest are stored in `sys.sql_modules`
