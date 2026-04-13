-- ============================================================
-- VibeSpace | File 2: Sample Data (DML)
-- Run AFTER vibespace_schema.sql
-- ============================================================

USE vibespace;

INSERT INTO Publishers (name, country, website_url) VALUES
('Valve Corporation',   'USA',    'https://www.valvesoftware.com'),
('CD Projekt',          'Poland', 'https://www.cdprojekt.com'),
('Ubisoft',             'France', 'https://www.ubisoft.com'),
('Nintendo',            'Japan',  'https://www.nintendo.com'),
('Indie Spotlight LLC', 'USA',    NULL);

INSERT INTO Developers (name, founded_year, website_url) VALUES
('Valve Corporation',   2000, 'https://www.valvesoftware.com'),
('CD Projekt Red',      2002, 'https://www.cdprojektred.com'),
('Ubisoft Montreal',    1997, 'https://montreal.ubisoft.com'),
('Game Freak',          1989, 'https://www.gamefreak.co.jp'),
('Hollow Knight Studio',2014, NULL);

INSERT INTO Genres (genre_name) VALUES
('Action'), ('RPG'), ('Adventure'), ('Simulation'), ('Horror');

INSERT INTO Tags (tag_name) VALUES
('Cozy'), ('Pixel Art'), ('Story Rich'), ('Open World'), ('Multiplayer');

INSERT INTO Platforms (platform_name, manufacturer) VALUES
('PC',             'Various'),
('PlayStation 5',  'Sony'),
('Nintendo Switch','Nintendo'),
('Xbox Series X',  'Microsoft');

INSERT INTO Users (username, email, password_hash, join_date) VALUES
('ahmed_f',    'ahmed@example.com',   SHA2('pass1234', 256), '2024-01-10'),
('tingxun_w',  'tingxun@example.com', SHA2('secureXX', 256), '2024-01-12'),
('gamer_nova', 'nova@example.com',    SHA2('nova9999', 256), '2024-02-05'),
('pixel_rex',  'rex@example.com',     SHA2('rexpass0', 256), '2024-03-18'),
('luna_plays', 'luna@example.com',    SHA2('luna0101', 256), '2024-04-22');

INSERT INTO Games (title, price, release_date, description, developer_id, publisher_id) VALUES
('Half-Life 3',          49.99, '2024-03-01', 'The legendary sequel finally arrives.',  1, 1),
('Cyberpunk 2078',       59.99, '2024-06-15', 'Dark future open-world RPG.',            2, 2),
('Assassins Creed Jade', 49.99, '2024-09-20', 'Ancient China setting AC game.',         3, 3),
('Pokemon Legends Z',    59.99, '2024-11-01', 'Open-world Pokemon adventure.',          4, 4),
('Hollow Knight 2',       0.00, '2024-05-10', 'Free-to-play metroidvania sequel.',      5, 5);

INSERT INTO Game_Genres VALUES
(1,1),(1,3),(2,2),(2,1),(3,1),(3,3),(4,2),(4,3),(5,1),(5,3);

INSERT INTO Game_Tags VALUES
(1,3),(1,5),(2,3),(2,4),(3,3),(3,4),(4,1),(4,3),(5,1),(5,2);

INSERT INTO Game_Platforms VALUES
(1,1),(1,2),(2,1),(2,2),(3,1),(3,4),(4,3),(5,1),(5,3);

INSERT INTO Wishlists (user_id, game_id, added_date) VALUES
(1, 2, '2024-06-01'),
(1, 4, '2024-10-01'),
(2, 3, '2024-09-01'),
(3, 5, '2024-04-01'),
(4, 1, '2024-02-20'),
(5, 2, '2024-06-10');

INSERT INTO Purchase_History (user_id, game_id, platform_id, price_paid, purchase_date) VALUES
(1, 1, 1, 49.99, '2024-03-01'),
(1, 5, 1,  0.00, '2024-05-10'),
(2, 1, 2, 49.99, '2024-03-05'),
(2, 2, 2, 59.99, '2024-06-20'),
(3, 2, 1, 59.99, '2024-06-18'),
(3, 3, 4, 49.99, '2024-09-22'),
(4, 4, 3, 59.99, '2024-11-02'),
(5, 5, 3,  0.00, '2024-05-12');

INSERT INTO User_Library (user_id, game_id, hours_played, install_status, completion_status, added_date) VALUES
(1, 1, 42.50, 'installed',     'in_progress', '2024-03-01'),
(1, 5,  8.00, 'installed',     'in_progress', '2024-05-10'),
(2, 1, 15.00, 'installed',     'not_started', '2024-03-05'),
(2, 2, 60.00, 'installed',     'completed',   '2024-06-20'),
(3, 2, 88.50, 'installed',     'completed',   '2024-06-18'),
(3, 3, 22.00, 'not_installed', 'in_progress', '2024-09-22'),
(4, 4, 35.00, 'installed',     'in_progress', '2024-11-02'),
(5, 5,  5.50, 'installed',     'not_started', '2024-05-12');

INSERT INTO Reviews (user_id, game_id, rating, review_text, review_date) VALUES
(1, 1, 5, 'Absolutely mind-blowing. Worth the wait.',        '2024-03-15'),
(2, 1, 4, 'Great game, minor performance issues on launch.', '2024-03-16'),
(3, 2, 5, 'Best open-world RPG I have ever played.',         '2024-07-01'),
(4, 3, 3, 'Fun but feels repetitive after 20 hours.',        '2024-10-05'),
(5, 4, 5, 'Pokemon perfected. Incredible world.',            '2024-11-20'),
(1, 5, 4, 'Beautiful art and tight gameplay.',               '2024-05-25');

INSERT INTO Collections (user_id, name, description, is_public, creation_date) VALUES
(1, 'Weekend Picks',     'Games I play on weekends.',       FALSE, '2024-04-01'),
(1, 'Best Story Games',  'Greatest narrative experiences.', TRUE,  '2024-04-15'),
(2, 'RPG Marathon',      'Long RPGs for winter break.',     TRUE,  '2024-05-01'),
(3, 'Free Gems',         'Amazing free-to-play titles.',    TRUE,  '2024-05-20'),
(5, 'Hidden Indie Gems', 'Underrated indie games.',         TRUE,  '2024-06-01');

INSERT INTO Collection_Games VALUES
(1,1),(1,5),(2,1),(2,5),(3,2),(3,4),(4,5),(5,5);
