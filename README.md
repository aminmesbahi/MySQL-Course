# MySQL 8.0 Course

## Scope

- Target engine: MySQL 8.0+
- Style: runnable, tutorial-first scripts with short instructional comments
- Goal: keep the learning path familiar while using native MySQL patterns

## Index

### Database Basics
1. [01_Creating_Database.sql](01_Creating_Database.sql) - Create databases, set defaults, and inspect schema metadata.
2. [02_Backup_Database.sql](02_Backup_Database.sql) - Logical backup and restore workflow with MySQL tooling.

### Administration & Maintenance
3. [03_Event_Scheduler.sql](03_Event_Scheduler.sql) - Automate recurring tasks with the MySQL Event Scheduler.

### Schema & Objects
4. [04_Indexes_Part_1.sql](04_Indexes_Part_1.sql) - Build and test common index patterns in InnoDB.
5. [05_Stored_Procedures.sql](05_Stored_Procedures.sql) - Create procedures, handlers, output parameters, and transactional routines.
6. [06_Functions.sql](06_Functions.sql) - Create scalar stored functions and model set-returning logic with MySQL-friendly alternatives.
7. [07_Triggers.sql](07_Triggers.sql) - Use BEFORE and AFTER triggers with NEW and OLD row references.
8. [08_Views.sql](08_Views.sql) - Create simple, join, aggregate, and JSON-producing views.

### Data Modeling & Semi-Structured Data
9. [09_Hierarchy_Data.sql](09_Hierarchy_Data.sql) - Model hierarchies with adjacency lists and recursive CTEs.
10. [10_XML.sql](10_XML.sql) - Work with XML stored as text using XPath helper functions.
11. [11_JSON.sql](11_JSON.sql) - Work with MySQL JSON columns, paths, generated columns, and JSON_TABLE.
12. [12_Relationship_Graph_Alternatives.sql](12_Relationship_Graph_Alternatives.sql) - Model graph-like data with relational tables and joins.

### Querying & Analytics
13. [13_Match_Alternatives.sql](13_Match_Alternatives.sql) - Replace graph MATCH patterns with join-based and recursive queries.
14. [14_Statements.sql](14_Statements.sql) - Review statement patterns, operator behavior, and index-friendly predicates.
15. [15_Windowing_Functions.sql](15_Windowing_Functions.sql) - Use window functions for ranking, navigation, and running aggregates.

## Data

The [data](data) folder contains sample CSV, JSON, and XML files reused by the semi-structured data lessons.
