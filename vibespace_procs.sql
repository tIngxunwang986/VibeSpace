-- ============================================================
-- VibeSpace | File 3: Stored Procedures, Functions,
--                     Triggers, Events
-- Bro Run AFTER vibespace_data.sql
-- ============================================================

USE vibespace;

DELIMITER $$

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

CREATE PROCEDURE RegisterUser(
    IN p_username     VARCHAR(50),
    IN p_email        VARCHAR(100),
    IN p_password_raw VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Registration failed: username or email already exists.';
    END;
    IF p_username IS NULL OR TRIM(p_username) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username cannot be empty.';
    END IF;
    IF p_email IS NULL OR TRIM(p_email) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email cannot be empty.';
    END IF;
    IF p_password_raw IS NULL OR LENGTH(p_password_raw) < 6 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Password must be at least 6 characters.';
    END IF;
    START TRANSACTION;
        INSERT INTO Users (username, email, password_hash)
        VALUES (TRIM(p_username), TRIM(p_email), SHA2(p_password_raw, 256));
    COMMIT;
    SELECT LAST_INSERT_ID() AS user_id, 'Registration successful.' AS result;
END$$

CREATE PROCEDURE LoginUser(
    IN p_username     VARCHAR(50),
    IN p_password_raw VARCHAR(255)
)
BEGIN
    DECLARE v_user_id     INT;
    DECLARE v_stored_hash VARCHAR(255);
    DECLARE v_email       VARCHAR(100);
    DECLARE v_join_date   DATE;
    SELECT user_id, password_hash, email, join_date
    INTO   v_user_id, v_stored_hash, v_email, v_join_date
    FROM   Users
    WHERE  username = TRIM(p_username)
    LIMIT 1;
    IF v_user_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Login failed: username not found.';
    END IF;
    IF v_stored_hash <> SHA2(p_password_raw, 256) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Login failed: incorrect password.';
    END IF;
    SELECT v_user_id AS user_id, p_username AS username,
           v_email AS email, v_join_date AS join_date,
           'Login successful.' AS result;
END$$

CREATE PROCEDURE BrowseGames(
    IN p_keyword      VARCHAR(100),
    IN p_genre_id     INT,
    IN p_platform_id  INT,
    IN p_max_price    DECIMAL(6,2)
)
BEGIN
    SELECT DISTINCT
        g.game_id, g.title, g.price, g.release_date, g.description,
        d.name AS developer, p.name AS publisher,
        GetAverageRating(g.game_id) AS avg_rating
    FROM Games g
    JOIN Developers  d  ON g.developer_id  = d.developer_id
    JOIN Publishers  p  ON g.publisher_id  = p.publisher_id
    LEFT JOIN Game_Genres    gg ON g.game_id = gg.game_id
    LEFT JOIN Game_Platforms gp ON g.game_id = gp.game_id
    WHERE
        (p_keyword     IS NULL OR g.title LIKE CONCAT('%', p_keyword, '%'))
    AND (p_genre_id    IS NULL OR gg.genre_id    = p_genre_id)
    AND (p_platform_id IS NULL OR gp.platform_id = p_platform_id)
    AND (p_max_price   IS NULL OR g.price        <= p_max_price)
    ORDER BY g.release_date DESC;
END$$

DROP PROCEDURE IF EXISTS PurchaseGame;

CREATE PROCEDURE PurchaseGame(
    IN p_user_id     INT,
    IN p_game_id     INT,
    IN p_platform_id INT
)
BEGIN
    DECLARE v_price       DECIMAL(6,2);
    DECLARE v_on_platform INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PurchaseGame failed: transaction rolled back.';
    END;
    SELECT COUNT(*) INTO v_on_platform
    FROM Game_Platforms
    WHERE game_id = p_game_id AND platform_id = p_platform_id;
    IF v_on_platform = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Game is not available on the specified platform.';
    END IF;
    SELECT price INTO v_price FROM Games WHERE game_id = p_game_id;
    START TRANSACTION;
        INSERT INTO Purchase_History (user_id, game_id, platform_id, price_paid)
        VALUES (p_user_id, p_game_id, p_platform_id, v_price);
        -- User_Library entry is created automatically by after_purchase_insert trigger
    COMMIT;
    SELECT 'Purchase successful. Game added to library.' AS result;
END$$

CREATE PROCEDURE AddToWishlist(
    IN p_user_id INT,
    IN p_game_id INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AddToWishlist failed.';
    END;
    INSERT IGNORE INTO Wishlists (user_id, game_id) VALUES (p_user_id, p_game_id);
    SELECT 'Game added to wishlist (or already exists).' AS result;
END$$

CREATE PROCEDURE RemoveFromWishlist(
    IN p_user_id INT,
    IN p_game_id INT
)
BEGIN
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(*) INTO v_count
    FROM Wishlists WHERE user_id = p_user_id AND game_id = p_game_id;
    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Wishlist entry not found for this user and game.';
    END IF;
    DELETE FROM Wishlists WHERE user_id = p_user_id AND game_id = p_game_id;
    SELECT 'Game removed from wishlist successfully.' AS result;
END$$

CREATE PROCEDURE GetUserLibrary(IN p_user_id INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found.';
    END IF;
    SELECT g.title, g.price, ul.hours_played,
           ul.install_status, ul.completion_status, ul.added_date
    FROM User_Library ul
    JOIN Games g ON ul.game_id = g.game_id
    WHERE ul.user_id = p_user_id
    ORDER BY ul.added_date DESC;
END$$

CREATE PROCEDURE UpdateLibraryProgress(
    IN p_user_id INT,
    IN p_game_id INT,
    IN p_hours   DECIMAL(8,2),
    IN p_status  VARCHAR(20)
)
BEGIN
    DECLARE v_count INT DEFAULT 0;
    IF p_hours < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hours played cannot be negative.';
    END IF;
    IF p_status NOT IN ('not_started','in_progress','completed') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid completion status.';
    END IF;
    SELECT COUNT(*) INTO v_count FROM User_Library
    WHERE user_id = p_user_id AND game_id = p_game_id;
    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Library entry not found for this user and game.';
    END IF;
    UPDATE User_Library
    SET hours_played = p_hours, completion_status = p_status
    WHERE user_id = p_user_id AND game_id = p_game_id;
    SELECT 'Library entry updated successfully.' AS result;
END$$

CREATE PROCEDURE AddReview(
    IN p_user_id INT,
    IN p_game_id INT,
    IN p_rating  TINYINT,
    IN p_text    TEXT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AddReview failed.';
    END;
    IF p_rating NOT BETWEEN 1 AND 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rating must be between 1 and 5.';
    END IF;
    INSERT INTO Reviews (user_id, game_id, rating, review_text)
    VALUES (p_user_id, p_game_id, p_rating, p_text)
    ON DUPLICATE KEY UPDATE
        rating      = p_rating,
        review_text = p_text,
        review_date = CURRENT_DATE;
    SELECT 'Review submitted successfully.' AS result;
END$$

CREATE PROCEDURE DeleteReview(
    IN p_user_id INT,
    IN p_game_id INT
)
BEGIN
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(*) INTO v_count FROM Reviews
    WHERE user_id = p_user_id AND game_id = p_game_id;
    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Review not found for this user and game.';
    END IF;
    DELETE FROM Reviews WHERE user_id = p_user_id AND game_id = p_game_id;
    SELECT 'Review deleted successfully.' AS result;
END$$

CREATE PROCEDURE ManageCollection(
    IN p_action        VARCHAR(10),
    IN p_user_id       INT,
    IN p_collection_id INT,
    IN p_name          VARCHAR(100),
    IN p_description   TEXT,
    IN p_is_public     BOOLEAN
)
BEGIN
    DECLARE v_owner_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ManageCollection failed.';
    END;
    IF p_action = 'create' THEN
        IF p_name IS NULL OR TRIM(p_name) = '' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Collection name cannot be empty.';
        END IF;
        INSERT INTO Collections (user_id, name, description, is_public)
        VALUES (p_user_id, TRIM(p_name), p_description, COALESCE(p_is_public, FALSE));
        SELECT LAST_INSERT_ID() AS collection_id, 'Collection created successfully.' AS result;
    ELSEIF p_action = 'delete' THEN
        SELECT user_id INTO v_owner_id FROM Collections WHERE collection_id = p_collection_id;
        IF v_owner_id IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Collection not found.';
        END IF;
        IF v_owner_id <> p_user_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You do not own this collection.';
        END IF;
        DELETE FROM Collections WHERE collection_id = p_collection_id;
        SELECT p_collection_id AS collection_id, 'Collection deleted successfully.' AS result;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid action. Use create or delete.';
    END IF;
END$$

CREATE PROCEDURE ManageCollectionGames(
    IN p_action        VARCHAR(10),
    IN p_user_id       INT,
    IN p_collection_id INT,
    IN p_game_id       INT
)
BEGIN
    DECLARE v_owner_id INT;
    DECLARE v_count    INT DEFAULT 0;
    SELECT user_id INTO v_owner_id FROM Collections WHERE collection_id = p_collection_id;
    IF v_owner_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Collection not found.';
    END IF;
    IF v_owner_id <> p_user_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You do not own this collection.';
    END IF;
    IF p_action = 'add' THEN
        INSERT IGNORE INTO Collection_Games (collection_id, game_id) VALUES (p_collection_id, p_game_id);
        SELECT 'Game added to collection (or already exists).' AS result;
    ELSEIF p_action = 'remove' THEN
        SELECT COUNT(*) INTO v_count FROM Collection_Games
        WHERE collection_id = p_collection_id AND game_id = p_game_id;
        IF v_count = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Game not found in this collection.';
        END IF;
        DELETE FROM Collection_Games WHERE collection_id = p_collection_id AND game_id = p_game_id;
        SELECT 'Game removed from collection successfully.' AS result;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid action. Use add or remove.';
    END IF;
END$$

-- ============================================================
-- USER-DEFINED FUNCTIONS
-- ============================================================

CREATE FUNCTION GetAverageRating(p_game_id INT)
RETURNS DECIMAL(3,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_avg DECIMAL(3,2);
    SELECT AVG(rating) INTO v_avg FROM Reviews WHERE game_id = p_game_id;
    RETURN v_avg;
END$$

CREATE FUNCTION IsGameOwned(p_user_id INT, p_game_id INT)
RETURNS TINYINT(1)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(*) INTO v_count FROM User_Library
    WHERE user_id = p_user_id AND game_id = p_game_id;
    RETURN IF(v_count > 0, 1, 0);
END$$

CREATE FUNCTION GetTotalSpent(p_user_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_total DECIMAL(10,2) DEFAULT 0.00;
    SELECT COALESCE(SUM(price_paid), 0.00) INTO v_total
    FROM Purchase_History WHERE user_id = p_user_id;
    RETURN v_total;
END$$

-- ============================================================
-- TRIGGERS
-- ============================================================

CREATE TRIGGER after_purchase_insert
AFTER INSERT ON Purchase_History
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM User_Library
        WHERE user_id = NEW.user_id AND game_id = NEW.game_id
    ) THEN
        INSERT INTO User_Library (user_id, game_id) VALUES (NEW.user_id, NEW.game_id);
    END IF;
END$$

CREATE TRIGGER before_review_insert
BEFORE INSERT ON Reviews
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM User_Library
        WHERE user_id = NEW.user_id AND game_id = NEW.game_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'User must own the game before submitting a review.';
    END IF;
END$$

CREATE TRIGGER after_library_completion
AFTER UPDATE ON User_Library
FOR EACH ROW
BEGIN
    IF NEW.completion_status = 'completed'
       AND OLD.completion_status <> 'completed' THEN
        INSERT INTO Completion_Log (user_id, game_id) VALUES (NEW.user_id, NEW.game_id);
    END IF;
END$$

-- ============================================================
-- EVENTS
-- ============================================================

SET GLOBAL event_scheduler = ON$$

CREATE EVENT IF NOT EXISTS daily_wishlist_cleanup
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURRENT_DATE, '00:00:00')
DO
BEGIN
    DELETE FROM Wishlists
    WHERE (user_id, game_id) IN (SELECT user_id, game_id FROM Purchase_History);
END$$

CREATE EVENT IF NOT EXISTS monthly_free_game_report
ON SCHEDULE EVERY 1 MONTH
STARTS TIMESTAMP(CURRENT_DATE, '00:00:00')
DO
BEGIN
    INSERT INTO Free_Game_Report (report_month, free_count)
    SELECT DATE_FORMAT(NOW(), '%Y-%m-01'), COUNT(*)
    FROM Purchase_History
    WHERE price_paid = 0.00
      AND MONTH(purchase_date) = MONTH(NOW())
      AND YEAR(purchase_date)  = YEAR(NOW());
END$$

DELIMITER ;