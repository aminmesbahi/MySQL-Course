/**************************************************************
 * MySQL 8.0: Fuzzy String Matching
 * Description: MySQL does not provide a built-in edit-distance or
 *              fuzzy-search function, but several practical approaches
 *              are available:
 *               1. SOUNDEX()  – phonetic encoding for English names.
 *               2. SOUNDS LIKE operator.
 *               3. FULLTEXT search relevance for natural-language matching.
 *               4. Levenshtein distance – user-defined stored function.
 *               5. Similarity scoring and deduplication queries.
 *               6. Trigram / n-gram matching with LIKE patterns.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS customer_names;
DROP TABLE IF EXISTS product_search;

CREATE TABLE customer_names
(
    customer_id INT          PRIMARY KEY AUTO_INCREMENT,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(150) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE product_search
(
    product_id   INT          PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(200) NOT NULL,
    description  TEXT,
    FULLTEXT INDEX ft_product (product_name, description)         -- for region 3
) ENGINE = InnoDB;

INSERT INTO customer_names (full_name, email) VALUES
    ('Robert Smith',   'r.smith@example.com'),
    ('Rob Smith',      'rob.smith@example.com'),
    ('Bob Smyth',      'bob.smyth@example.com'),
    ('Barbara Smithe', 'b.smithe@example.com'),
    ('Alice Johnson',  'a.johnson@example.com'),
    ('Alicia Johnston','a.johnston@example.com'),
    ('Jon Williams',   'jon.w@example.com'),
    ('John Williams',  'john.w@example.com');

INSERT INTO product_search (product_name, description) VALUES
    ('Wireless Headphones', 'High-quality Bluetooth headphones with noise cancellation'),
    ('Wired Earbuds',       'Compact earbuds with wired 3.5mm connector'),
    ('Bluetooth Speaker',   'Portable speaker with 12-hour battery life'),
    ('Noise Cancelling Headset', 'Professional headset for calls and music');

-------------------------------------------------
-- Region: 1. SOUNDEX – Phonetic Encoding
-------------------------------------------------
/*
  1.1  SOUNDEX() encodes a string to a 4-character phonetic code.
       Names that sound similar in English map to the same code.
       All vowels after the first character are ignored; consonants
       are grouped into classes.
       Limitations: English-biased, insensitive to first vowel differences
       (e.g. 'Ann' and 'Ian' differ), only 4 characters long.
*/
SELECT full_name,
       SOUNDEX(full_name)            AS soundex_code
FROM   customer_names
ORDER  BY full_name;

-- Find names that sound like 'Robert Smith'
SELECT full_name, email,
       SOUNDEX(full_name)  AS code
FROM   customer_names
WHERE  SOUNDEX(full_name) = SOUNDEX('Robert Smith');

-- SOUNDEX of individual parts
SELECT full_name,
       SOUNDEX(SUBSTRING_INDEX(full_name, ' ', 1))  AS first_soundex,
       SOUNDEX(SUBSTRING_INDEX(full_name, ' ', -1)) AS last_soundex
FROM   customer_names;

-------------------------------------------------
-- Region: 2. SOUNDS LIKE Operator
-------------------------------------------------
/*
  2.1  SOUNDS LIKE is syntactic sugar for SOUNDEX(a) = SOUNDEX(b).
       It is convenient but subject to the same limitations as SOUNDEX.
*/
SELECT a.full_name AS name_a,
       b.full_name AS name_b
FROM   customer_names a
JOIN   customer_names b ON a.customer_id < b.customer_id
WHERE  a.full_name SOUNDS LIKE b.full_name;

-- Find all entries that sound like a given name
SELECT full_name
FROM   customer_names
WHERE  full_name SOUNDS LIKE 'Jon Williams';

-------------------------------------------------
-- Region: 3. FULLTEXT Relevance for Fuzzy Matching
-------------------------------------------------
/*
  3.1  FULLTEXT search is not strictly fuzzy, but the NATURAL LANGUAGE
       mode scores results by term frequency/inverse document frequency
       (TF/IDF), which effectively surfaces the most relevant matches
       even when the query is not an exact substring match.
       Boolean mode supports truncation (*) for prefix matching.
*/

-- Natural language relevance scoring
SELECT product_name,
       MATCH(product_name, description)
           AGAINST ('wireless headphone noise' IN NATURAL LANGUAGE MODE) AS relevance
FROM   product_search
WHERE  MATCH(product_name, description)
           AGAINST ('wireless headphone noise' IN NATURAL LANGUAGE MODE)
ORDER  BY relevance DESC;

-- Boolean mode: require 'headphone' OR 'headset', boost 'noise'
SELECT product_name,
       MATCH(product_name, description)
           AGAINST ('+head* noise*' IN BOOLEAN MODE) AS relevance
FROM   product_search
WHERE  MATCH(product_name, description)
           AGAINST ('+head* noise*' IN BOOLEAN MODE);

-------------------------------------------------
-- Region: 4. Levenshtein Distance – Stored Function
-------------------------------------------------
/*
  4.1  Levenshtein distance counts the minimum number of single-character
       edits (insertions, deletions, substitutions) needed to turn one
       string into another.  MySQL provides no built-in function; the
       algorithm is straightforward to implement as a stored function.
*/
DROP FUNCTION IF EXISTS levenshtein;

DELIMITER //

CREATE FUNCTION levenshtein
(
    s1 VARCHAR(255),
    s2 VARCHAR(255)
)
RETURNS INT
DETERMINISTIC
NO SQL
BEGIN
    DECLARE s1_len INT DEFAULT CHAR_LENGTH(s1);
    DECLARE s2_len INT DEFAULT CHAR_LENGTH(s2);
    DECLARE i      INT DEFAULT 1;
    DECLARE j      INT DEFAULT 1;
    DECLARE s1_ch  CHAR(1);
    DECLARE cost   INT;
    -- Using a JSON array as a dynamic array to avoid temporary tables
    DECLARE d      JSON DEFAULT JSON_ARRAY();

    IF s1_len = 0 THEN RETURN s2_len; END IF;
    IF s2_len = 0 THEN RETURN s1_len; END IF;

    -- Initialise first row [0, 1, 2, ..., s2_len]
    SET j = 0;
    WHILE j <= s2_len DO
        SET d = JSON_ARRAY_INSERT(d, CONCAT('$[', j, ']'), j);
        SET j = j + 1;
    END WHILE;

    -- Fill in the matrix row by row (space-optimised: single row)
    SET i = 1;
    WHILE i <= s1_len DO
        SET s1_ch   = SUBSTRING(s1, i, 1);
        SET d       = JSON_ARRAY_INSERT(d, '$[0]', i);       -- overwrite position 0
        -- trim extra element added by INSERT
        SET d       = JSON_REMOVE(d, CONCAT('$[', JSON_LENGTH(d) - 1, ']'));

        SET j = 1;
        WHILE j <= s2_len DO
            IF s1_ch = SUBSTRING(s2, j, 1) THEN
                SET cost = 0;
            ELSE
                SET cost = 1;
            END IF;

            SET d = JSON_REPLACE(d, CONCAT('$[', j, ']'),
                        LEAST(
                            JSON_EXTRACT(d, CONCAT('$[', j  , ']')) + 1,   -- deletion
                            JSON_EXTRACT(d, CONCAT('$[', j-1, ']')) + 1,   -- insertion
                            JSON_EXTRACT(d, CONCAT('$[', j-1, ']')) + cost -- originally prev row
                        )
                    );
            SET j = j + 1;
        END WHILE;
        SET i = i + 1;
    END WHILE;

    RETURN JSON_EXTRACT(d, CONCAT('$[', s2_len, ']'));
END //

DELIMITER ;

-- Test the function
SELECT levenshtein('kitten',  'sitting')  AS distance;   -- 3
SELECT levenshtein('Robert',  'Rob')      AS distance;   -- 3
SELECT levenshtein('Smith',   'Smyth')    AS distance;   -- 1

-------------------------------------------------
-- Region: 5. Similarity Scoring and Deduplication
-------------------------------------------------
/*
  5.1  Combine Levenshtein distance with string length to build a
       normalised similarity score in the range [0, 1].
       similarity = 1 - (distance / max_length)
*/
DROP FUNCTION IF EXISTS similarity;

DELIMITER //

CREATE FUNCTION similarity
(
    s1 VARCHAR(255),
    s2 VARCHAR(255)
)
RETURNS DECIMAL(5,4)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE max_len INT DEFAULT GREATEST(CHAR_LENGTH(s1), CHAR_LENGTH(s2));
    IF max_len = 0 THEN RETURN 1.0; END IF;
    RETURN 1.0 - (levenshtein(s1, s2) / max_len);
END //

DELIMITER ;

-- Score all customer pairs by name similarity
SELECT a.full_name AS name_a,
       b.full_name AS name_b,
       similarity(a.full_name, b.full_name) AS sim_score
FROM   customer_names a
JOIN   customer_names b ON a.customer_id < b.customer_id
WHERE  similarity(a.full_name, b.full_name) >= 0.60
ORDER  BY sim_score DESC;

-------------------------------------------------
-- Region: 6. Trigram (N-Gram) Matching
-------------------------------------------------
/*
  6.1  A trigram is a sequence of 3 consecutive characters.
       Splitting strings into trigrams and matching them via LIKE or a
       pre-built lookup table is a scalable fuzzy-search technique.

  6.2  MySQL 8.0 supports the ngram full-text parser, which automatically
       tokenises CJK and other scripts without whitespace.
*/

-- Trigram split of a single string (procedure approach)
DROP PROCEDURE IF EXISTS GenerateTrigrams;

DELIMITER //

CREATE PROCEDURE GenerateTrigrams(IN p_str VARCHAR(255))
BEGIN
    DECLARE i        INT DEFAULT 1;
    DECLARE trigrams TEXT DEFAULT '';
    DECLARE len      INT DEFAULT CHAR_LENGTH(p_str);
    WHILE i <= len - 2 DO
        SET trigrams = CONCAT(trigrams, IF(i > 1, ', ', ''), SUBSTRING(p_str, i, 3));
        SET i = i + 1;
    END WHILE;
    SELECT trigrams AS trigrams_of;
END //

DELIMITER ;

CALL GenerateTrigrams('Williams');

-- Trigram overlap approximation using LOCATE on bigrams/trigrams
SELECT a.full_name,
       b.full_name,
       -- Count of shared bigrams as a very lightweight similarity heuristic
       (LOCATE(SUBSTRING(a.full_name, 1, 2), b.full_name) > 0) +
       (LOCATE(SUBSTRING(a.full_name, 3, 2), b.full_name) > 0) +
       (LOCATE(SUBSTRING(a.full_name, 5, 2), b.full_name) > 0)  AS shared_bigrams
FROM   customer_names a
JOIN   customer_names b ON a.customer_id <> b.customer_id
ORDER  BY shared_bigrams DESC
LIMIT  10;

-- ngram full-text index (tokenises every CJK / short-word string by 2-gram default)
/*
  In my.cnf: ngram_token_size = 2
  CREATE TABLE t (txt TEXT, FULLTEXT INDEX ft (txt) WITH PARSER ngram);
  SELECT * FROM t WHERE MATCH(txt) AGAINST ('smi' IN BOOLEAN MODE);
*/

-------------------------------------------------
-- Region: Cleanup
-------------------------------------------------
DROP PROCEDURE IF EXISTS GenerateTrigrams;
DROP FUNCTION  IF EXISTS similarity;
DROP FUNCTION  IF EXISTS levenshtein;
DROP TABLE     IF EXISTS product_search;
DROP TABLE     IF EXISTS customer_names;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
