-- ============================================================
-- VibeSpace | Schema (DDL)
-- ============================================================

DROP DATABASE IF EXISTS vibespace;
CREATE DATABASE vibespace CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE vibespace;

CREATE TABLE Publishers (
    publisher_id  INT            AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100)   NOT NULL,
    country       VARCHAR(60)    NOT NULL,
    website_url   VARCHAR(255)
);

CREATE TABLE Developers (
    developer_id  INT            AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100)   NOT NULL,
    founded_year  YEAR,
    website_url   VARCHAR(255)
);

CREATE TABLE Genres (
    genre_id      INT            AUTO_INCREMENT PRIMARY KEY,
    genre_name    VARCHAR(60)    NOT NULL UNIQUE
);

CREATE TABLE Tags (
    tag_id        INT            AUTO_INCREMENT PRIMARY KEY,
    tag_name      VARCHAR(60)    NOT NULL UNIQUE
);

CREATE TABLE Platforms (
    platform_id   INT            AUTO_INCREMENT PRIMARY KEY,
    platform_name VARCHAR(60)    NOT NULL,
    manufacturer  VARCHAR(100)   NOT NULL
);

CREATE TABLE Users (
    user_id       INT            AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(50)    NOT NULL UNIQUE,
    email         VARCHAR(100)   NOT NULL UNIQUE,
    password_hash VARCHAR(255)   NOT NULL,
    join_date     DATE           NOT NULL DEFAULT (CURRENT_DATE)
);

CREATE TABLE Games (
    game_id       INT            AUTO_INCREMENT PRIMARY KEY,
    title         VARCHAR(150)   NOT NULL,
    price         DECIMAL(6,2)   NOT NULL DEFAULT 0.00,
    release_date  DATE,
    description   TEXT,
    developer_id  INT            NOT NULL,
    publisher_id  INT            NOT NULL,
    CONSTRAINT chk_price       CHECK (price >= 0),
    CONSTRAINT fk_game_dev     FOREIGN KEY (developer_id)
        REFERENCES Developers(developer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_game_pub     FOREIGN KEY (publisher_id)
        REFERENCES Publishers(publisher_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Game_Genres (
    game_id   INT NOT NULL,
    genre_id  INT NOT NULL,
    PRIMARY KEY (game_id, genre_id),
    CONSTRAINT fk_gg_game  FOREIGN KEY (game_id)
        REFERENCES Games(game_id)   ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_gg_genre FOREIGN KEY (genre_id)
        REFERENCES Genres(genre_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Game_Tags (
    game_id  INT NOT NULL,
    tag_id   INT NOT NULL,
    PRIMARY KEY (game_id, tag_id),
    CONSTRAINT fk_gt_game FOREIGN KEY (game_id)
        REFERENCES Games(game_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_gt_tag  FOREIGN KEY (tag_id)
        REFERENCES Tags(tag_id)   ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Game_Platforms (
    game_id     INT NOT NULL,
    platform_id INT NOT NULL,
    PRIMARY KEY (game_id, platform_id),
    CONSTRAINT fk_gp_game     FOREIGN KEY (game_id)
        REFERENCES Games(game_id)         ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_gp_platform FOREIGN KEY (platform_id)
        REFERENCES Platforms(platform_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Reviews (
    review_id   INT         AUTO_INCREMENT PRIMARY KEY,
    user_id     INT         NOT NULL,
    game_id     INT         NOT NULL,
    rating      TINYINT     NOT NULL,
    review_text TEXT,
    review_date DATE        NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT uq_review   UNIQUE  (user_id, game_id),
    CONSTRAINT chk_rating  CHECK   (rating BETWEEN 1 AND 5),
    CONSTRAINT fk_rev_user FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rev_game FOREIGN KEY (game_id)
        REFERENCES Games(game_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Wishlists (
    wishlist_id INT  AUTO_INCREMENT PRIMARY KEY,
    user_id     INT  NOT NULL,
    game_id     INT  NOT NULL,
    added_date  DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT uq_wishlist UNIQUE  (user_id, game_id),
    CONSTRAINT fk_wl_user  FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_wl_game  FOREIGN KEY (game_id)
        REFERENCES Games(game_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Purchase_History (
    purchase_id   INT          AUTO_INCREMENT PRIMARY KEY,
    user_id       INT          NOT NULL,
    game_id       INT          NOT NULL,
    platform_id   INT          NOT NULL,
    price_paid    DECIMAL(6,2) NOT NULL DEFAULT 0.00,
    purchase_date DATE         NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT uq_purchase    UNIQUE (user_id, game_id),
    CONSTRAINT chk_price_paid CHECK  (price_paid >= 0),
    CONSTRAINT fk_ph_user     FOREIGN KEY (user_id)
        REFERENCES Users(user_id)         ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_ph_game     FOREIGN KEY (game_id)
        REFERENCES Games(game_id)         ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_ph_platform FOREIGN KEY (platform_id)
        REFERENCES Platforms(platform_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE User_Library (
    library_id        INT          AUTO_INCREMENT PRIMARY KEY,
    user_id           INT          NOT NULL,
    game_id           INT          NOT NULL,
    hours_played      DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    install_status    ENUM('installed','not_installed')              NOT NULL DEFAULT 'not_installed',
    completion_status ENUM('not_started','in_progress','completed')  NOT NULL DEFAULT 'not_started',
    added_date        DATE         NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT uq_library  UNIQUE (user_id, game_id),
    CONSTRAINT chk_hours   CHECK  (hours_played >= 0),
    CONSTRAINT fk_ul_user  FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ul_game  FOREIGN KEY (game_id)
        REFERENCES Games(game_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Collections (
    collection_id INT          AUTO_INCREMENT PRIMARY KEY,
    user_id       INT          NOT NULL,
    name          VARCHAR(100) NOT NULL,
    description   TEXT,
    is_public     BOOLEAN      NOT NULL DEFAULT FALSE,
    creation_date DATE         NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT fk_col_user FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Collection_Games (
    collection_id INT NOT NULL,
    game_id       INT NOT NULL,
    PRIMARY KEY (collection_id, game_id),
    CONSTRAINT fk_cg_col  FOREIGN KEY (collection_id)
        REFERENCES Collections(collection_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cg_game FOREIGN KEY (game_id)
        REFERENCES Games(game_id)             ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Completion_Log (
    log_id       INT      AUTO_INCREMENT PRIMARY KEY,
    user_id      INT      NOT NULL,
    game_id      INT      NOT NULL,
    completed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Free_Game_Report (
    report_id    INT      AUTO_INCREMENT PRIMARY KEY,
    report_month DATE     NOT NULL,
    free_count   INT      NOT NULL,
    created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
