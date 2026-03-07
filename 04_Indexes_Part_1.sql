/**************************************************************
 * MySQL 8.0 Indexes Tutorial
 * Description: This script demonstrates common index patterns
 *              in MySQL, including single-column, composite,
 *              unique, and prefix indexes, along with EXPLAIN
 *              output for index-aware query tuning.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS books;

CREATE TABLE books
(
    book_id INT PRIMARY KEY AUTO_INCREMENT,
    isbn CHAR(13) NOT NULL,
    title VARCHAR(200) NOT NULL,
    author VARCHAR(150) NOT NULL,
    genre VARCHAR(80) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    publish_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

INSERT INTO books (isbn, title, author, genre, price, publish_date)
VALUES
    ('9780000000001', 'XML Developer Guide', 'Matthew Gambardella', 'Computer', 44.95, '2000-10-01'),
    ('9780000000002', 'Midnight Rain', 'Kim Ralls', 'Fantasy', 5.95, '2000-12-16'),
    ('9780000000003', 'Maeve Ascendant', 'Eva Corets', 'Fantasy', 5.95, '2000-11-17'),
    ('9780000000004', 'The Last Algorithm', 'Alice Lee', 'Computer', 39.95, '2002-07-21'),
    ('9780000000005', 'The Silent Forest', 'Soo-jin Kim', 'Horror', 5.95, '2004-10-31');

-------------------------------------------------
-- Region: 1. Creating Indexes
-------------------------------------------------
/*
  1.1 Unique index for ISBN lookups.
*/
CREATE UNIQUE INDEX ix_books_isbn
ON books (isbn);

/*
  1.2 Single-column index for genre filtering.
*/
CREATE INDEX ix_books_genre
ON books (genre);

/*
  1.3 Composite index for common author and date searches.
*/
CREATE INDEX ix_books_author_publish_date
ON books (author, publish_date);

/*
  1.4 Prefix index for long text comparisons.
*/
CREATE INDEX ix_books_title_prefix
ON books (title(20));

-------------------------------------------------
-- Region: 2. Query Plans
-------------------------------------------------
/*
  2.1 Point lookup using the unique ISBN index.
*/
EXPLAIN
SELECT *
FROM books
WHERE isbn = '9780000000004';

/*
  2.2 Filter on the left-most column of a composite index.
*/
EXPLAIN
SELECT title, publish_date
FROM books
WHERE author = 'Eva Corets'
ORDER BY publish_date;

/*
  2.3 Prefix search that can still benefit from an index.
*/
EXPLAIN
SELECT *
FROM books
WHERE title LIKE 'The%';

/*
  2.4 Leading wildcard pattern is generally not index-friendly.
*/
EXPLAIN
SELECT *
FROM books
WHERE title LIKE '%Forest';

-------------------------------------------------
-- Region: 3. Metadata Review
-------------------------------------------------
/*
  3.1 Review index definitions.
*/
SHOW INDEX FROM books;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------