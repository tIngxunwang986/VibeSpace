-- ============================================================
-- VibeSpace | File 4: Test Queries (Verified & Fixed)
-- Bro Run AFTER vibespace_procs.sql
-- Each test labeled: -- EXPECT PASS or -- EXPECT FAIL
-- Run each block individually in MySQL Workbench
-- ============================================================

USE vibespace;

-- ============================================================
-- TEST 1: RegisterUser
-- ============================================================

-- EXPECT PASS: brand new user not in sample data
CALL RegisterUser('john_doe', 'john@example.com', 'safepass');
-- Expected output: user_id=6, 'Registration successful.'

-- EXPECT FAIL: username 'ahmed_f' already exists in sample data
CALL RegisterUser('ahmed_f', 'other@example.com', 'safepass');
-- Expected error: 'Registration failed: username or email already exists.'

-- EXPECT FAIL: email 'ahmed@example.com' already exists in sample data
CALL RegisterUser('brandnew', 'ahmed@example.com', 'safepass');
-- Expected error: 'Registration failed: username or email already exists.'

-- EXPECT FAIL: empty username
CALL RegisterUser('', 'empty@example.com', 'safepass');
-- Expected error: 'Username cannot be empty.'

-- EXPECT FAIL: password fewer than 6 chars
CALL RegisterUser('shortpass_user', 'short@example.com', '123');
-- Expected error: 'Password must be at least 6 characters.'

-- ============================================================
-- TEST 2: LoginUser
-- ============================================================

-- EXPECT PASS: correct credentials from sample data
CALL LoginUser('ahmed_f', 'pass1234');
-- Expected output: user_id=1, username=ahmed_f, email, join_date, 'Login successful.'

-- EXPECT FAIL: correct username, wrong password
CALL LoginUser('ahmed_f', 'wrongpass');
-- Expected error: 'Login failed: incorrect password.'

-- EXPECT FAIL: username does not exist
CALL LoginUser('ghost_user', 'pass1234');
-- Expected error: 'Login failed: username not found.'

-- ============================================================
-- TEST 3: BrowseGames
-- ============================================================

-- EXPECT PASS: keyword match — 'Cyberpunk 2078' contains 'cyber'
CALL BrowseGames('cyber', NULL, NULL, NULL);
-- Expected: 1 row — Cyberpunk 2078

-- EXPECT PASS: genre_id=2 (RPG) — games 2 and 4 are RPG
CALL BrowseGames(NULL, 2, NULL, NULL);
-- Expected: 2 rows — Cyberpunk 2078, Pokemon Legends Z

-- EXPECT PASS: platform_id=1 (PC) — games 1,2,3,5 on PC
CALL BrowseGames(NULL, NULL, 1, NULL);
-- Expected: 4 rows — Half-Life 3, Cyberpunk 2078, AC Jade, Hollow Knight 2

-- EXPECT PASS: max price 49.99 — games 1,3,5
CALL BrowseGames(NULL, NULL, NULL, 49.99);
-- Expected: 3 rows — Half-Life 3 (49.99), AC Jade (49.99), Hollow Knight 2 (0.00)

-- EXPECT PASS: no filters — all 5 games
CALL BrowseGames(NULL, NULL, NULL, NULL);
-- Expected: 5 rows

-- ============================================================
-- TEST 4: PurchaseGame
-- ============================================================
-- Sample data purchases: (1,1),(1,5),(2,1),(2,2),(3,2),(3,3),(4,4),(5,5)
-- Sample data library  : (1,1),(1,5),(2,1),(2,2),(3,2),(3,3),(4,4),(5,5)

-- EXPECT PASS: user 5 buys game 1 on PC (platform 1)
-- user 5 has NOT purchased game 1, and game 1 IS on PC
CALL PurchaseGame(5, 1, 1);
-- Expected: 'Purchase successful. Game added to library.'

-- EXPECT FAIL: user 1 already purchased game 1 (in sample data)
CALL PurchaseGame(1, 1, 1);
-- Expected error: 'PurchaseGame failed: transaction rolled back.'

-- EXPECT FAIL: game 4 (Pokemon) is NOT available on PC (platform 1)
-- Game 4 is only on Nintendo Switch (platform 3)
CALL PurchaseGame(5, 4, 1);
-- Expected error: 'Game is not available on the specified platform.'

-- ============================================================
-- TEST 5: AddToWishlist
-- ============================================================
-- Sample wishlists: (1,2),(1,4),(2,3),(3,5),(4,1),(5,2)

-- EXPECT PASS: user 2 wishlists game 5 — not in sample data
CALL AddToWishlist(2, 5);
-- Expected: 'Game added to wishlist (or already exists).'

-- EXPECT PASS: duplicate — user 1 + game 2 already exists, silent skip
CALL AddToWishlist(1, 2);
-- Expected: 'Game added to wishlist (or already exists).' — no error

-- ============================================================
-- TEST 6: RemoveFromWishlist
-- ============================================================

-- EXPECT PASS: user 1 removes game 2 — exists in sample data
CALL RemoveFromWishlist(1, 2);
-- Expected: 'Game removed from wishlist successfully.'

-- EXPECT FAIL: game 99 does not exist in any wishlist
CALL RemoveFromWishlist(1, 99);
-- Expected error: 'Wishlist entry not found for this user and game.'

-- ============================================================
-- TEST 7: GetUserLibrary
-- ============================================================

-- EXPECT PASS: user 1 has 2 library entries (game 1 and game 5)
CALL GetUserLibrary(1);
-- Expected: 2 rows — Half-Life 3, Hollow Knight 2

-- EXPECT PASS: user 3 has 2 library entries (game 2 and game 3)
CALL GetUserLibrary(3);
-- Expected: 2 rows — Cyberpunk 2078, AC Jade

-- EXPECT FAIL: user 999 does not exist
CALL GetUserLibrary(999);
-- Expected error: 'User not found.'

-- ============================================================
-- TEST 8: UpdateLibraryProgress
-- ============================================================

-- EXPECT PASS: user 1 updates game 1 progress
CALL UpdateLibraryProgress(1, 1, 55.0, 'completed');
-- Expected: 'Library entry updated successfully.'

-- Verify Completion_Log received entry from trigger
SELECT * FROM Completion_Log;
-- Expected: 1 row with user_id=1, game_id=1

-- EXPECT FAIL: negative hours
CALL UpdateLibraryProgress(1, 1, -5.0, 'in_progress');
-- Expected error: 'Hours played cannot be negative.'

-- EXPECT FAIL: invalid status string
CALL UpdateLibraryProgress(1, 1, 10.0, 'finished');
-- Expected error: 'Invalid completion status.'

-- EXPECT FAIL: user 1 does not have game 99 in library
CALL UpdateLibraryProgress(1, 99, 10.0, 'in_progress');
-- Expected error: 'Library entry not found for this user and game.'

-- ============================================================
-- TEST 9: AddReview
-- ============================================================
-- Sample reviews: (1,1),(2,1),(3,2),(4,3),(5,4),(1,5)
-- Sample library : (1,1),(1,5),(2,1),(2,2),(3,2),(3,3),(4,4),(5,5)

-- EXPECT PASS: user 1 updates their existing review for game 1
CALL AddReview(1, 1, 5, 'Even better on second playthrough!');
-- Expected: 'Review submitted successfully.'

-- EXPECT PASS: user 2 writes new review for game 2
-- user 2 owns game 2 AND has no review for it yet
CALL AddReview(2, 2, 5, 'Incredible open world!');
-- Expected: 'Review submitted successfully.'

-- EXPECT FAIL: rating 6 is out of range
CALL AddReview(1, 1, 6, 'Too high rating.');
-- Expected error: 'Rating must be between 1 and 5.'

-- EXPECT FAIL: user 1 does not own game 3 (not in User_Library)
-- trigger before_review_insert will block this
CALL AddReview(1, 3, 4, 'Trying to review unowned game.');
-- Expected error: 'User must own the game before submitting a review.'

-- ============================================================
-- TEST 10: DeleteReview
-- ============================================================

-- EXPECT PASS: user 3 deletes their review for game 2 (exists in sample data)
CALL DeleteReview(3, 2);
-- Expected: 'Review deleted successfully.'

-- EXPECT FAIL: review for game 99 does not exist
CALL DeleteReview(1, 99);
-- Expected error: 'Review not found for this user and game.'

-- ============================================================
-- TEST 11: ManageCollection (create)
-- ============================================================

-- EXPECT PASS: user 1 creates a new public collection
CALL ManageCollection('create', 1, NULL, 'My Top RPGs', 'Best RPGs ever', TRUE);
-- Expected: new collection_id=6, 'Collection created successfully.'

-- EXPECT PASS: user 2 creates a private collection
CALL ManageCollection('create', 2, NULL, 'Secret List', NULL, FALSE);
-- Expected: new collection_id=7, 'Collection created successfully.'

-- EXPECT FAIL: empty collection name
CALL ManageCollection('create', 1, NULL, '', NULL, FALSE);
-- Expected error: 'Collection name cannot be empty.'

-- EXPECT FAIL: invalid action string
CALL ManageCollection('update', 1, NULL, 'Bad Action', NULL, FALSE);
-- Expected error: 'Invalid action. Use create or delete.'

-- ============================================================
-- TEST 12: ManageCollection (delete)
-- ============================================================
-- Sample collections: id=1(user1), id=2(user1), id=3(user2), id=4(user3), id=5(user5)

-- EXPECT PASS: user 1 deletes their own collection id=2
CALL ManageCollection('delete', 1, 2, NULL, NULL, NULL);
-- Expected: collection_id=2, 'Collection deleted successfully.'

-- EXPECT FAIL: collection id=999 does not exist
CALL ManageCollection('delete', 1, 999, NULL, NULL, NULL);
-- Expected error: 'Collection not found.'

-- EXPECT FAIL: user 1 tries to delete user 2's collection (id=3)
CALL ManageCollection('delete', 1, 3, NULL, NULL, NULL);
-- Expected error: 'You do not own this collection.'

-- ============================================================
-- TEST 13: ManageCollectionGames (add)
-- ============================================================
-- Sample collection_games: (1,1),(1,5),(2,1),(2,5),(3,2),(3,4),(4,5),(5,5)

-- EXPECT PASS: user 2 adds game 1 to collection 3
-- game 1 is NOT already in collection 3
CALL ManageCollectionGames('add', 2, 3, 1);
-- Expected: 'Game added to collection (or already exists).'

-- EXPECT PASS: duplicate — game 2 already in collection 3, silent skip
CALL ManageCollectionGames('add', 2, 3, 2);
-- Expected: 'Game added to collection (or already exists).' — no error

-- EXPECT FAIL: user 1 tries to add to user 2's collection (id=3)
CALL ManageCollectionGames('add', 1, 3, 1);
-- Expected error: 'You do not own this collection.'

-- ============================================================
-- TEST 14: ManageCollectionGames (remove)
-- ============================================================

-- EXPECT PASS: user 2 removes game 2 from collection 3 (exists in sample data)
CALL ManageCollectionGames('remove', 2, 3, 2);
-- Expected: 'Game removed from collection successfully.'

-- EXPECT FAIL: game 99 not in collection 3
CALL ManageCollectionGames('remove', 2, 3, 99);
-- Expected error: 'Game not found in this collection.'

-- EXPECT FAIL: user 1 tries to remove from user 2's collection
CALL ManageCollectionGames('remove', 1, 3, 4);
-- Expected error: 'You do not own this collection.'

-- ============================================================
-- TEST 15: User-Defined Functions
-- ============================================================

-- EXPECT: avg of ratings 5,4 = 4.50 for game 1
SELECT GetAverageRating(1) AS avg_rating_game1;

-- EXPECT: NULL — game 99 has no reviews
SELECT GetAverageRating(99) AS avg_rating_no_reviews;

-- EXPECT: 1 — user 1 owns game 1 (in User_Library)
SELECT IsGameOwned(1, 1) AS owned;

-- EXPECT: 0 — user 1 does NOT own game 3
SELECT IsGameOwned(1, 3) AS not_owned;

-- EXPECT: 49.99 + 0.00 = 49.99 for user 1
SELECT GetTotalSpent(1) AS total_spent_user1;

-- EXPECT: 49.99 + 59.99 = 109.98 for user 2
SELECT GetTotalSpent(2) AS total_spent_user2;

-- EXPECT: 0.00 — user 999 has no purchases
SELECT GetTotalSpent(999) AS total_spent_none;

-- ============================================================
-- TEST 16: Triggers
-- ============================================================

-- TRIGGER: after_purchase_insert
-- user 4 buys game 2 on platform 2 directly via INSERT
-- library entry for (4,2) should be auto-created by trigger
INSERT INTO Purchase_History (user_id, game_id, platform_id, price_paid)
VALUES (4, 2, 2, 59.99);
-- Verify library entry was auto-created
SELECT * FROM User_Library WHERE user_id = 4 AND game_id = 2;
-- Expected: 1 row with user_id=4, game_id=2

-- TRIGGER: before_review_insert
-- user 4 does NOT own game 2 originally in sample library
-- (4,2) only just got added above via trigger
-- So test with a user who definitely does not own a game:
-- user 2 does not own game 3 (game 3 only owned by user 3)
INSERT INTO Reviews (user_id, game_id, rating, review_text)
VALUES (2, 3, 4, 'Trying to review without owning.');
-- Expected error: 'User must own the game before submitting a review.'

-- TRIGGER: after_library_completion
-- user 1 game 5 is currently 'in_progress' in sample data
-- updating to 'completed' should fire the trigger
UPDATE User_Library
SET completion_status = 'completed'
WHERE user_id = 1 AND game_id = 5;
-- Verify log entry created
SELECT * FROM Completion_Log WHERE user_id = 1 AND game_id = 5;
-- Expected: 1 row with user_id=1, game_id=5