# MySQL 8.0 Course

This folder is a MySQL-oriented companion to the SQL Server course in the repository root.
It keeps the same tutorial tone and lesson sequencing where possible, but replaces SQL Server-only features with practical MySQL 8.0 equivalents.

## Scope

- Target engine: MySQL 8.0+
- Style: runnable, tutorial-first scripts with short instructional comments
- Goal: keep the learning path familiar while using native MySQL patterns

## Agenda

See [AGENDA.md](AGENDA.md) for the lesson mapping and the conversion plan.

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
16. [16_Rank_Functions.sql](16_Rank_Functions.sql) - Use ranking functions with partitions and top-N patterns.
17. [17_Time_Series.sql](17_Time_Series.sql) - Analyze time-series data with window functions, interval bucketing, and manual history tracking.
18. [18_Row_Filtering_Alternatives.sql](18_Row_Filtering_Alternatives.sql) - Emulate row-level access patterns with views, user mapping, and privilege boundaries.
19. [19_Approximation_Alternatives.sql](19_Approximation_Alternatives.sql) - Replace approximate percentile features with MySQL distribution-analysis patterns.
20. [20_Prediction_Alternatives.sql](20_Prediction_Alternatives.sql) - Replace PREDICT with SQL-based forecasting and scoring patterns.

## Data

The [data](data) folder contains sample CSV, JSON, and XML files reused by the semi-structured data lessons.

## Notes

- Several scripts use `DELIMITER //` because MySQL routines and triggers contain internal semicolons.
- Lessons 09, 12, and 13 are intentional rewrites rather than literal ports because MySQL does not implement `hierarchyid`, graph node/edge tables, or the SQL Server `MATCH` clause.
- Lessons 18, 19, and 20 are also intentional rewrites because MySQL does not provide native row-level security policies, `APPROX_PERCENTILE_*`, or the SQL Server `PREDICT` clause.