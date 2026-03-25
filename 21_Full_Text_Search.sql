/**************************************************************
 * MySQL 8.0 Full-Text Search Tutorial
 * This script demonstrates full-text search in MySQL
 * using FULLTEXT indexes and the MATCH...AGAINST syntax.
 * It covers:
 * - Creating tables with FULLTEXT indexes on InnoDB.
 * - Inserting a sample document dataset.
 * - Natural language mode searches with relevance ranking.
 * - Boolean mode searches with operators (+, -, *, ~, "").
 * - Query expansion mode for broader result sets.
 * - Stopwords, minimum word length, and parser settings.
 * - Adding FULLTEXT indexes to existing tables.
 * - Performance and maintenance notes.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
/*
  Use the course database.
*/
USE mysql_course;

DROP TABLE IF EXISTS documents;

-------------------------------------------------
-- Region: 1. Creating the Table with a FULLTEXT Index
-------------------------------------------------
/*
  1.1 Create a documents table with a FULLTEXT index on title and body.
       InnoDB supports FULLTEXT indexes from MySQL 5.6.
       The index covers both columns so a single MATCH expression can
       search across them.
*/
CREATE TABLE documents
(
    document_id   INT          PRIMARY KEY AUTO_INCREMENT,
    title         VARCHAR(255) NOT NULL,
    body          TEXT         NOT NULL,
    file_type     VARCHAR(10)  NOT NULL DEFAULT 'txt',
    security_level INT         NOT NULL DEFAULT 1,
    indexed_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FULLTEXT INDEX ft_documents (title, body)
) ENGINE = InnoDB;

-------------------------------------------------
-- Region: 2. Inserting Sample Data
-------------------------------------------------
/*
  2.1 Insert a small representative dataset.
       In production you would load thousands of rows; the patterns
       demonstrated here scale to large tables.
*/
INSERT INTO documents (title, body, file_type)
VALUES
    ('Introduction to MySQL',
     'MySQL is a popular open-source relational database management system. '
     'It supports full-text search on InnoDB and MyISAM storage engines.',
     'pdf'),
    ('MySQL Performance Tuning',
     'Performance tuning in MySQL involves index design, query optimization, '
     'InnoDB buffer pool sizing, and slow query log analysis.',
     'pdf'),
    ('Full-Text Search Capabilities',
     'MySQL full-text search supports natural language mode, boolean mode, '
     'and query expansion. The MATCH...AGAINST syntax drives all three modes.',
     'docx'),
    ('Database Management Best Practices',
     'Best practices for database management include regular backups, '
     'index maintenance, statistics updates, and capacity planning.',
     'pdf'),
    ('MySQL 8.0 New Features',
     'MySQL 8.0 introduces window functions, CTEs, invisible indexes, '
     'descending indexes, and improved JSON support.',
     'docx'),
    ('Data Analysis with SQL',
     'SQL enables powerful data analysis using aggregation, window functions, '
     'subqueries, and set operations across relational tables.',
     'txt'),
    ('MySQL Security Hardening',
     'Securing MySQL requires strong authentication, encrypted connections, '
     'role-based privileges, and regular audit log reviews.',
     'pdf'),
    ('Index Design Patterns',
     'Composite indexes, covering indexes, functional indexes, and prefix '
     'indexes are the main patterns for MySQL performance optimization.',
     'docx');

-------------------------------------------------
-- Region: 3. Natural Language Mode Search
-------------------------------------------------
/*
  3.1 Default MATCH...AGAINST uses IN NATURAL LANGUAGE MODE.
       MySQL scores each row by relevance; higher score = better match.
       Rows below the relevance threshold are filtered automatically.
*/
SELECT
    document_id,
    title,
    ROUND(MATCH(title, body) AGAINST ('MySQL database management'), 4) AS relevance_score
FROM documents
WHERE MATCH(title, body) AGAINST ('MySQL database management')
ORDER BY relevance_score DESC;

/*
  3.2 Show documents most relevant to full-text search topics.
*/
SELECT
    document_id,
    title,
    ROUND(MATCH(title, body) AGAINST ('full-text search capabilities'), 4) AS relevance_score
FROM documents
WHERE MATCH(title, body) AGAINST ('full-text search capabilities')
ORDER BY relevance_score DESC;

-------------------------------------------------
-- Region: 4. Boolean Mode Search
-------------------------------------------------
/*
  4.1 Boolean mode gives you explicit operators to control inclusion,
       exclusion, and weighting:
         +word   word must be present
         -word   word must not be present
         word*   prefix wildcard
         "phrase" exact phrase match
         ~word   lower relevance if word present
         >word   increase relevance weight
         <word   decrease relevance weight
*/

/*
  4.2 Require "MySQL" and exclude documents mentioning "security".
*/
SELECT
    document_id,
    title
FROM documents
WHERE MATCH(title, body) AGAINST ('+MySQL -security' IN BOOLEAN MODE);

/*
  4.3 Exact phrase search.
*/
SELECT
    document_id,
    title
FROM documents
WHERE MATCH(title, body) AGAINST ('"full-text search"' IN BOOLEAN MODE);

/*
  4.4 Prefix wildcard: match any word starting with "optim".
*/
SELECT
    document_id,
    title
FROM documents
WHERE MATCH(title, body) AGAINST ('optim*' IN BOOLEAN MODE);

/*
  4.5 Boost relevance of documents that mention "performance".
*/
SELECT
    document_id,
    title,
    ROUND(MATCH(title, body) AGAINST ('+MySQL >performance' IN BOOLEAN MODE), 4) AS score
FROM documents
WHERE MATCH(title, body) AGAINST ('+MySQL >performance' IN BOOLEAN MODE)
ORDER BY score DESC;

-------------------------------------------------
-- Region: 5. Query Expansion Mode
-------------------------------------------------
/*
  5.1 WITH QUERY EXPANSION performs a two-step search:
       first pass ranks results by the original query; second pass
       expands the query with the most relevant words found in those
       results and re-ranks. Useful when a search phrase is very short.
*/
SELECT
    document_id,
    title,
    ROUND(MATCH(title, body) AGAINST ('database' WITH QUERY EXPANSION), 4) AS relevance_score
FROM documents
WHERE MATCH(title, body) AGAINST ('database' WITH QUERY EXPANSION)
ORDER BY relevance_score DESC;

-------------------------------------------------
-- Region: 6. Adding a FULLTEXT Index to an Existing Table
-------------------------------------------------
/*
  6.1 Drop-and-recreate approach for demonstration.
       ALTER TABLE is the standard way to add a FULLTEXT index post hoc.
*/
DROP TABLE IF EXISTS articles;

CREATE TABLE articles
(
    article_id  INT          PRIMARY KEY AUTO_INCREMENT,
    headline    VARCHAR(255) NOT NULL,
    content     MEDIUMTEXT   NOT NULL,
    published   DATE         NOT NULL
) ENGINE = InnoDB;

INSERT INTO articles (headline, content, published)
VALUES
    ('MySQL 8.0 Released',
     'The MySQL team announced version 8.0 with major improvements to '
     'performance, security, and developer-facing features.',
     '2018-04-19'),
    ('InnoDB Full-Text Improvements',
     'InnoDB now supports full-text search with the ngram and MeCab parsers '
     'for CJK and Japanese languages respectively.',
     '2020-06-01');

/*
  6.2 Add FULLTEXT index after table creation.
       For large tables this operation runs online (no blocking DML in 8.0).
*/
ALTER TABLE articles ADD FULLTEXT INDEX ft_articles (headline, content);

/*
  6.3 Verify by running a search on the new index.
*/
SELECT article_id, headline
FROM articles
WHERE MATCH(headline, content) AGAINST ('InnoDB full-text' IN BOOLEAN MODE);

-------------------------------------------------
-- Region: 7. Inspecting and Maintaining FULLTEXT Indexes
-------------------------------------------------
/*
  7.1 List all FULLTEXT indexes in the current database.
*/
SELECT
    TABLE_NAME,
    INDEX_NAME,
    COLUMN_NAME,
    INDEX_TYPE
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND INDEX_TYPE = 'FULLTEXT'
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

/*
  7.2 Check FULLTEXT index configuration variables.
       ft_min_word_len (MyISAM) / innodb_ft_min_token_size (InnoDB)
       control the minimum token length (default 3).
       Words shorter than this threshold are ignored.
*/
SHOW VARIABLES LIKE 'innodb_ft_%';
SHOW VARIABLES LIKE 'ft_%';

/*
  7.3 After bulk inserts, you can manually sync the FULLTEXT index cache
       to the on-disk auxiliary tables.
*/
-- OPTIMIZE TABLE documents;   -- also defragments the table

/*
  7.4 Query InnoDB auxiliary FULLTEXT tables (requires super or
       innodb_ft_aux_table set to the target table).
*/
-- SET GLOBAL innodb_ft_aux_table = 'mysql_course/documents';
-- SELECT * FROM INFORMATION_SCHEMA.INNODB_FT_INDEX_CACHE LIMIT 20;
-- SELECT * FROM INFORMATION_SCHEMA.INNODB_FT_INDEX_TABLE  LIMIT 20;

-------------------------------------------------
-- Region: 8. Security-Filtered Search
-------------------------------------------------
/*
  8.1 Combine FULLTEXT relevance scoring with a conventional WHERE predicate
       to enforce access control at the application layer.
*/
SELECT
    document_id,
    title,
    ROUND(MATCH(title, body) AGAINST ('MySQL optimization'), 4) AS relevance_score
FROM documents
WHERE MATCH(title, body) AGAINST ('MySQL optimization')
  AND security_level <= 1         -- only show public documents
ORDER BY relevance_score DESC;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
