#USE misspellings;
SELECT MAX(LENGTH(misspelled_word)) INTO @maxLength
  FROM word;
  
DROP PROCEDURE IF EXISTS popsubStringIndexer;
DELIMITER //
CREATE PROCEDURE popsubStringIndexer()
BEGIN
	SET @i := 1;
    DROP TABLE IF EXISTS subStringIndexer;
	CREATE TABLE subStringIndexer (
		subIndex INT NOT NULL
	);
    iterator: LOOP
		IF @i > @maxLength THEN
			LEAVE iterator;
		END IF;
        INSERT INTO subStringIndexer VALUES (@i);
        SET @i := @i + 1;
        ITERATE iterator;
	END LOOP;
END//
DELIMITER ;

CALL popsubStringIndexer();
  
DROP TABLE IF EXISTS sub_gram_holder;
CREATE TABLE sub_gram_holder (
id INT NOT NULL,
indexPos INT NOT NULL,
subgram VARCHAR(100) NOT NULL
);
DROP FUNCTION IF EXISTS levenshtein;
DELIMITER $$
CREATE FUNCTION levenshtein( s1 VARCHAR(255), s2 VARCHAR(255) )
    RETURNS INT
    DETERMINISTIC
    BEGIN
        DECLARE s1_len, s2_len, i, j, c, c_temp, cost INT;
        DECLARE s1_char CHAR;
        -- max strlen=255
        DECLARE cv0, cv1 VARBINARY(256);

        SET s1_len = CHAR_LENGTH(s1), s2_len = CHAR_LENGTH(s2), cv1 = 0x00, j = 1, i = 1, c = 0;

        IF s1 = s2 THEN
            RETURN 0;
        ELSEIF s1_len = 0 THEN
            RETURN s2_len;
        ELSEIF s2_len = 0 THEN
            RETURN s1_len;
        ELSE
            WHILE j <= s2_len DO
                SET cv1 = CONCAT(cv1, UNHEX(HEX(j))), j = j + 1;
            END WHILE;
            WHILE i <= s1_len DO
                SET s1_char = SUBSTRING(s1, i, 1), c = i, cv0 = UNHEX(HEX(i)), j = 1;
                WHILE j <= s2_len DO
                    SET c = c + 1;
                    IF s1_char = SUBSTRING(s2, j, 1) THEN
                        SET cost = 0; ELSE SET cost = 1;
                    END IF;
                    SET c_temp = CONV(HEX(SUBSTRING(cv1, j, 1)), 16, 10) + cost;
                    IF c > c_temp THEN SET c = c_temp; END IF;
                    SET c_temp = CONV(HEX(SUBSTRING(cv1, j+1, 1)), 16, 10) + 1;
                    IF c > c_temp THEN
                        SET c = c_temp;
                    END IF;
                    SET cv0 = CONCAT(cv0, UNHEX(HEX(c))), j = j + 1;
                END WHILE;
                SET cv1 = cv0, i = i + 1;
            END WHILE;
        END IF;
        RETURN c;
    END$$
DELIMITER ;

SET @q = 3;
INSERT INTO sub_gram_holder
	 SELECT w.id, 
		    i.subIndex,
		    SUBSTR(CONCAT(SUBSTR('###',1,@q-1), LOWER(misspelled_word), SUBSTR('%%%',1,@q-1)), i.subIndex, @q) as 'sub-grams'
	   FROM word w, subStringIndexer i
	  WHERE i.subIndex <= LENGTH(misspelled_word) + @q -1;
 
 SET @editDist = 2;
 #'immediately','absense','assassin'
 SET @word = 'immediately';
SELECT id,misspelled_word
 FROM `word` 
 WHERE SOUNDEX(`misspelled_word`) = SOUNDEX(@word)
 #AND LENGTH(misspelled_word) BETWEEN LENGTH(@word) -2 AND LENGTH(@word) + 2
 UNION
 SELECT id,misspelled_word
       FROM(
			SELECT w1.id as 'notincluded',
				   w1.misspelled_word as 'notIncludedWord',
				   w2.id,
				   w2.misspelled_word
			  FROM word w1, word w2, sub_gram_holder q1, sub_gram_holder q2
			 WHERE w1.id = q1.id
			   AND w2.id = q2.id
			   AND q1.subgram = q2.subgram
			   AND q1.indexPos <= q2.indexPos + @editDist
			   AND q1.indexPos >= q2.indexPos - @editDist
			   AND LENGTH(w1.misspelled_word) <= LENGTH(w2.misspelled_word) + @editDist
			   AND LENGTH(w1.misspelled_word) >= LENGTH(w2.misspelled_word) - @editDist
			   AND w1.misspelled_word = @word
			GROUP BY w1.id,
					 w1.misspelled_word,
					 w2.id,
					 w2.misspelled_word
			 HAVING COUNT(*) >= LENGTH(w1.misspelled_word) -1 - (@editDist - 1)*@q
				AND COUNT(*) >= LENGTH(w2.misspelled_word)  -1 - (@editDist - 1)*@q
			)X WHERE LEFT(misspelled_word,1)=LEFT(@word,1) AND levenshtein(@word, misspelled_word) BETWEEN 0 AND 4
            UNION 
            SELECT id, misspelled_word
            FROM word WHERE RIGHT(@word, LENGTH(@word)-1) = RIGHT(misspelled_word, LENGTH(@word)-1)
            AND  LEFT(misspelled_word,1)<>LEFT(@word,1);
   
   
 SELECT id,misspelled_word
 FROM `word` 
 WHERE SOUNDEX(`misspelled_word`) = SOUNDEX(@word);
 SELECT * FROM word WHERE levenshtein(@word, misspelled_word) BETWEEN 0 AND 3;

SELECT SOUNDEX(@word);