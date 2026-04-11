"""
VibeSpace — Flask Application
CS 5200 Group Project | CrossCurrent
Author: Tingxun Wang
"""

from flask import (
    Flask, render_template, request, redirect,
    url_for, session, flash, jsonify
)
import mysql.connector
from mysql.connector import Error
from functools import wraps

app = Flask(__name__)
app.secret_key = 'vibespace-crosscurrent-2026'

# ── Database Configuration ──────────────────────────────────
DB_CONFIG = {
    'host': '127.0.0.1',
    'port': 3306,
    'user': 'root',
    'password': '',  # fill in your MySQL password
    'database': 'vibespace',
    'autocommit': True
}


def get_db():
    """Create and return a new database connection."""
    return mysql.connector.connect(**DB_CONFIG)


def login_required(f):
    """Decorator: redirect to login if not authenticated."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        if 'user_id' not in session:
            flash('Please log in first.', 'warning')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return wrapper


# ════════════════════════════════════════════════════════════
#  AUTH ROUTES
# ════════════════════════════════════════════════════════════

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        email = request.form.get('email', '').strip()
        password = request.form.get('password', '')
        try:
            conn = get_db()
            cur = conn.cursor(dictionary=True)
            cur.callproc('RegisterUser', (username, email, password))
            for result in cur.stored_results():
                row = result.fetchone()
                if row:
                    flash('Registration successful! Please log in.', 'success')
                    return redirect(url_for('login'))
            cur.close()
            conn.close()
        except Error as e:
            flash(str(e), 'danger')
    return render_template('register.html')


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        try:
            conn = get_db()
            cur = conn.cursor(dictionary=True)
            cur.callproc('LoginUser', (username, password))
            for result in cur.stored_results():
                row = result.fetchone()
                if row and 'user_id' in row:
                    session['user_id'] = row['user_id']
                    session['username'] = row['username']
                    flash(f'Welcome back, {row["username"]}!', 'success')
                    return redirect(url_for('index'))
            cur.close()
            conn.close()
        except Error as e:
            flash(str(e), 'danger')
    return render_template('login.html')


@app.route('/logout')
def logout():
    session.clear()
    flash('Logged out.', 'info')
    return redirect(url_for('index'))


# ════════════════════════════════════════════════════════════
#  BROWSE / HOME
# ════════════════════════════════════════════════════════════

@app.route('/')
def index():
    keyword = request.args.get('keyword')
    genre_id = request.args.get('genre_id', type=int)
    platform_id = request.args.get('platform_id', type=int)
    max_price = request.args.get('max_price', type=float)

    conn = get_db()
    cur = conn.cursor(dictionary=True)

    # Browse games via stored procedure
    cur.callproc('BrowseGames', (keyword, genre_id, platform_id, max_price))
    games = []
    for result in cur.stored_results():
        games = result.fetchall()

    # Fetch filter options
    cur.execute('SELECT * FROM Genres ORDER BY genre_name')
    genres = cur.fetchall()
    cur.execute('SELECT * FROM Platforms ORDER BY platform_name')
    platforms = cur.fetchall()

    cur.close()
    conn.close()
    return render_template('index.html', games=games, genres=genres,
                           platforms=platforms, filters={
                               'keyword': keyword or '',
                               'genre_id': genre_id,
                               'platform_id': platform_id,
                               'max_price': max_price
                           })


# ════════════════════════════════════════════════════════════
#  GAME DETAIL
# ════════════════════════════════════════════════════════════

@app.route('/game/<int:game_id>')
def game_detail(game_id):
    conn = get_db()
    cur = conn.cursor(dictionary=True)

    # Game info
    cur.execute('''
        SELECT g.*, d.name AS developer, p.name AS publisher
        FROM Games g
        JOIN Developers d ON g.developer_id = d.developer_id
        JOIN Publishers p ON g.publisher_id = p.publisher_id
        WHERE g.game_id = %s
    ''', (game_id,))
    game = cur.fetchone()
    if not game:
        flash('Game not found.', 'danger')
        return redirect(url_for('index'))

    # Genres
    cur.execute('''
        SELECT ge.genre_name FROM Game_Genres gg
        JOIN Genres ge ON gg.genre_id = ge.genre_id
        WHERE gg.game_id = %s
    ''', (game_id,))
    game['genres'] = [r['genre_name'] for r in cur.fetchall()]

    # Tags
    cur.execute('''
        SELECT t.tag_name FROM Game_Tags gt
        JOIN Tags t ON gt.tag_id = t.tag_id
        WHERE gt.game_id = %s
    ''', (game_id,))
    game['tags'] = [r['tag_name'] for r in cur.fetchall()]

    # Platforms
    cur.execute('''
        SELECT pl.platform_id, pl.platform_name FROM Game_Platforms gp
        JOIN Platforms pl ON gp.platform_id = pl.platform_id
        WHERE gp.game_id = %s
    ''', (game_id,))
    game['platforms'] = cur.fetchall()

    # Average rating
    cur.execute('SELECT GetAverageRating(%s) AS avg_rating', (game_id,))
    game['avg_rating'] = cur.fetchone()['avg_rating']

    # Reviews
    cur.execute('''
        SELECT r.*, u.username FROM Reviews r
        JOIN Users u ON r.user_id = u.user_id
        WHERE r.game_id = %s ORDER BY r.review_date DESC
    ''', (game_id,))
    reviews = cur.fetchall()

    # Check ownership & wishlist for logged-in user
    owned = False
    in_wishlist = False
    user_review = None
    if 'user_id' in session:
        uid = session['user_id']
        cur.execute('SELECT IsGameOwned(%s, %s) AS owned', (uid, game_id))
        owned = cur.fetchone()['owned'] == 1
        cur.execute('SELECT COUNT(*) AS c FROM Wishlists WHERE user_id=%s AND game_id=%s',
                    (uid, game_id))
        in_wishlist = cur.fetchone()['c'] > 0
        for rv in reviews:
            if rv['user_id'] == uid:
                user_review = rv
                break

    cur.close()
    conn.close()
    return render_template('game_detail.html', game=game, reviews=reviews,
                           owned=owned, in_wishlist=in_wishlist,
                           user_review=user_review)


# ════════════════════════════════════════════════════════════
#  PURCHASE
# ════════════════════════════════════════════════════════════

@app.route('/purchase', methods=['POST'])
@login_required
def purchase():
    game_id = request.form.get('game_id', type=int)
    platform_id = request.form.get('platform_id', type=int)
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.callproc('PurchaseGame', (session['user_id'], game_id, platform_id))
        for result in cur.stored_results():
            row = result.fetchone()
            if row:
                flash(row.get('result', 'Purchase successful!'), 'success')
        cur.close()
        conn.close()
    except Error as e:
        flash(str(e), 'danger')
    return redirect(url_for('game_detail', game_id=game_id))


# ════════════════════════════════════════════════════════════
#  WISHLIST
# ════════════════════════════════════════════════════════════

@app.route('/wishlist')
@login_required
def wishlist():
    conn = get_db()
    cur = conn.cursor(dictionary=True)
    cur.execute('''
        SELECT w.*, g.title, g.price, g.release_date,
               GetAverageRating(g.game_id) AS avg_rating
        FROM Wishlists w
        JOIN Games g ON w.game_id = g.game_id
        WHERE w.user_id = %s ORDER BY w.added_date DESC
    ''', (session['user_id'],))
    items = cur.fetchall()
    cur.close()
    conn.close()
    return render_template('wishlist.html', items=items)


@app.route('/wishlist/add', methods=['POST'])
@login_required
def wishlist_add():
    game_id = request.form.get('game_id', type=int)
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.callproc('AddToWishlist', (session['user_id'], game_id))
        for result in cur.stored_results():
            row = result.fetchone()
            if row:
                flash(row.get('result', 'Added to wishlist!'), 'success')
        cur.close()
        conn.close()
    except Error as e:
        flash(str(e), 'danger')
    return redirect(request.referrer or url_for('index'))


@app.route('/wishlist/remove', methods=['POST'])
@login_required
def wishlist_remove():
    game_id = request.form.get('game_id', type=int)
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.callproc('RemoveFromWishlist', (session['user_id'], game_id))
        for result in cur.stored_results():
            row = result.fetchone()
            if row:
                flash(row.get('result', 'Removed from wishlist.'), 'info')
        cur.close()
        conn.close()
    except Error as e:
        flash(str(e), 'danger')
    return redirect(request.referrer or url_for('wishlist'))


# ════════════════════════════════════════════════════════════
#  LIBRARY
# ════════════════════════════════════════════════════════════

@app.route('/library')
@login_required
def library():
    conn = get_db()
    cur = conn.cursor(dictionary=True)
    cur.callproc('GetUserLibrary', (session['user_id'],))
    items = []
    for result in cur.stored_results():
        items = result.fetchall()

    # We also need game_id for update forms — fetch from User_Library directly
    cur.execute('''
        SELECT ul.game_id, g.title, g.price, ul.hours_played,
               ul.install_status, ul.completion_status, ul.added_date
        FROM User_Library ul
        JOIN Games g ON ul.game_id = g.game_id
        WHERE ul.user_id = %s ORDER BY ul.added_date DESC
    ''', (session['user_id'],))
    items = cur.fetchall()

    # Total spent
    cur.execute('SELECT GetTotalSpent(%s) AS total', (session['user_id'],))
    total_spent = cur.fetchone()['total']

    cur.close()
    conn.close()
    return render_template('library.html', items=items, total_spent=total_spent)


@app.route('/library/update', methods=['POST'])
@login_required
def library_update():
    game_id = request.form.get('game_id', type=int)
    hours = request.form.get('hours_played', type=float)
    status = request.form.get('completion_status', '')
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.callproc('UpdateLibraryProgress',
                     (session['user_id'], game_id, hours, status))
        for result in cur.stored_results():
            row = result.fetchone()
            if row:
                flash(row.get('result', 'Library updated!'), 'success')
        cur.close()
        conn.close()
    except Error as e:
        flash(str(e), 'danger')
    return redirect(url_for('library'))


# ════════════════════════════════════════════════════════════
#  REVIEWS
# ════════════════════════════════════════════════════════════

@app.route('/review/add', methods=['POST'])
@login_required
def review_add():
    game_id = request.form.get('game_id', type=int)
    rating = request.form.get('rating', type=int)
    text = request.form.get('review_text', '').strip()
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.callproc('AddReview', (session['user_id'], game_id, rating, text))
        for result in cur.stored_results():
            row = result.fetchone()
            if row:
                flash(row.get('result', 'Review submitted!'), 'success')
        cur.close()
        conn.close()
    except Error as e:
        flash(str(e), 'danger')
    return redirect(url_for('game_detail', game_id=game_id))


@app.route('/review/delete', methods=['POST'])
@login_required
def review_delete():
    game_id = request.form.get('game_id', type=int)
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.callproc('DeleteReview', (session['user_id'], game_id))
        for result in cur.stored_results():
            row = result.fetchone()
            if row:
                flash(row.get('result', 'Review deleted.'), 'info')
        cur.close()
        conn.close()
    except Error as e:
        flash(str(e), 'danger')
    return redirect(url_for('game_detail', game_id=game_id))


# ════════════════════════════════════════════════════════════
#  COLLECTIONS
# ════════════════════════════════════════════════════════════

@app.route('/collections')
@login_required
def collections():
    conn = get_db()
    cur = conn.cursor(dictionary=True)
    # User's own collections
    cur.execute('''
        SELECT c.*, COUNT(cg.game_id) AS game_count
        FROM Collections c
        LEFT JOIN Collection_Games cg ON c.collection_id = cg.collection_id
        WHERE c.user_id = %s
        GROUP BY c.collection_id
        ORDER BY c.creation_date DESC
    ''', (session['user_id'],))
    my_collections = cur.fetchall()

    # Public collections from other users
    cur.execute('''
        SELECT c.*, u.username, COUNT(cg.game_id) AS game_count
        FROM Collections c
        JOIN Users u ON c.user_id = u.user_id
        LEFT JOIN Collection_Games cg ON c.collection_id = cg.collection_id
        WHERE c.is_public = TRUE AND c.user_id != %s
        GROUP BY c.collection_id
        ORDER BY c.creation_date DESC
    ''', (session['user_id'],))
    public_collections = cur.fetchall()

    cur.close()
    conn.close()
    return render_template('collections.html',
                           my_collections=my_collections,
                           public_collections=public_collections)


@app.route('/collection/<int:collection_id>')
def collection_detail(collection_id):
    conn = get_db()
    cur = conn.cursor(dictionary=True)

    cur.execute('''
        SELECT c.*, u.username FROM Collections c
        JOIN Users u ON c.user_id = u.user_id
        WHERE c.collection_id = %s
    ''', (collection_id,))
    collection = cur.fetchone()
    if not collection:
        flash('Collection not found.', 'danger')
        return redirect(url_for('collections'))

    # Check access: private collection only visible to owner
    if not collection['is_public'] and \
       ('user_id' not in session or session['user_id'] != collection['user_id']):
        flash('This collection is private.', 'warning')
        return redirect(url_for('collections'))

    cur.execute('''
        SELECT g.game_id, g.title, g.price, g.release_date,
               GetAverageRating(g.game_id) AS avg_rating
        FROM Collection_Games cg
        JOIN Games g ON cg.game_id = g.game_id
        WHERE cg.collection_id = %s
    ''', (collection_id,))
    games = cur.fetchall()

    # For adding games — get all games not in this collection
    available_games = []
    is_owner = 'user_id' in session and session['user_id'] == collection['user_id']
    if is_owner:
        cur.execute('''
            SELECT g.game_id, g.title FROM Games g
            WHERE g.game_id NOT IN (
                SELECT game_id FROM Collection_Games WHERE collection_id = %s
            ) ORDER BY g.title
        ''', (collection_id,))
        available_games = cur.fetchall()

    cur.close()
    conn.close()
    return render_template('collection_detail.html', collection=collection,
                           games=games, available_games=available_games,
                           is_owner=is_owner)


@app.route('/collection/create', methods=['POST'])
@login_required
def collection_create():
    name = request.form.get('name', '').strip()
    description = request.form.get('description', '').strip()
    is_public = request.form.get('is_public') == 'on'
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.callproc('ManageCollection',
                     ('create', session['user_id'], None, name, description, is_public))
        for result in cur.stored_results():
            row = result.fetchone()
            if row:
                flash(row.get('result', 'Collection created!'), 'success')
        cur.close()
        conn.close()
    except Error as e:
        flash(str(e), 'danger')
    return redirect(url_for('collections'))


@app.route('/collection/delete', methods=['POST'])
@login_required
def collection_delete():
    collection_id = request.form.get('collection_id', type=int)
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.callproc('ManageCollection',
                     ('delete', session['user_id'], collection_id, None, None, None))
        for result in cur.stored_results():
            row = result.fetchone()
            if row:
                flash(row.get('result', 'Collection deleted.'), 'info')
        cur.close()
        conn.close()
    except Error as e:
        flash(str(e), 'danger')
    return redirect(url_for('collections'))


@app.route('/collection/add-game', methods=['POST'])
@login_required
def collection_add_game():
    collection_id = request.form.get('collection_id', type=int)
    game_id = request.form.get('game_id', type=int)
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.callproc('ManageCollectionGames',
                     ('add', session['user_id'], collection_id, game_id))
        for result in cur.stored_results():
            row = result.fetchone()
            if row:
                flash(row.get('result', 'Game added to collection!'), 'success')
        cur.close()
        conn.close()
    except Error as e:
        flash(str(e), 'danger')
    return redirect(url_for('collection_detail', collection_id=collection_id))


@app.route('/collection/remove-game', methods=['POST'])
@login_required
def collection_remove_game():
    collection_id = request.form.get('collection_id', type=int)
    game_id = request.form.get('game_id', type=int)
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.callproc('ManageCollectionGames',
                     ('remove', session['user_id'], collection_id, game_id))
        for result in cur.stored_results():
            row = result.fetchone()
            if row:
                flash(row.get('result', 'Game removed from collection.'), 'info')
        cur.close()
        conn.close()
    except Error as e:
        flash(str(e), 'danger')
    return redirect(url_for('collection_detail', collection_id=collection_id))


# ════════════════════════════════════════════════════════════
#  DASHBOARD (Bonus — Analytics & Visualization)
# ════════════════════════════════════════════════════════════

@app.route('/dashboard')
def dashboard():
    conn = get_db()
    cur = conn.cursor(dictionary=True)

    # Query 1: Average rating by genre (multi-join: Games + Game_Genres + Genres + Reviews)
    cur.execute('''
        SELECT ge.genre_name,
               ROUND(AVG(r.rating), 2) AS avg_rating,
               COUNT(DISTINCT r.review_id) AS review_count
        FROM Genres ge
        JOIN Game_Genres gg ON ge.genre_id = gg.genre_id
        JOIN Games g ON gg.game_id = g.game_id
        JOIN Reviews r ON g.game_id = r.game_id
        GROUP BY ge.genre_id
        ORDER BY avg_rating DESC
    ''')
    rating_by_genre = cur.fetchall()

    # Query 2: Top games by number of purchases
    #          (multi-join: Games + Purchase_History + Developers)
    cur.execute('''
        SELECT g.title,
               d.name AS developer,
               COUNT(ph.purchase_id) AS purchase_count,
               COALESCE(GetAverageRating(g.game_id), 0) AS avg_rating
        FROM Games g
        JOIN Purchase_History ph ON g.game_id = ph.game_id
        JOIN Developers d ON g.developer_id = d.developer_id
        GROUP BY g.game_id
        ORDER BY purchase_count DESC
    ''')
    top_games = cur.fetchall()

    # Query 3: Platform popularity — total purchases per platform
    #          (multi-join: Platforms + Purchase_History + Games)
    cur.execute('''
        SELECT pl.platform_name,
               COUNT(ph.purchase_id) AS total_purchases,
               ROUND(SUM(ph.price_paid), 2) AS total_revenue
        FROM Platforms pl
        JOIN Purchase_History ph ON pl.platform_id = ph.platform_id
        JOIN Games g ON ph.game_id = g.game_id
        GROUP BY pl.platform_id
        ORDER BY total_purchases DESC
    ''')
    platform_stats = cur.fetchall()

    # Query 4: User spending leaderboard
    #          (multi-join: Users + Purchase_History + User_Library)
    cur.execute('''
        SELECT u.username,
               GetTotalSpent(u.user_id) AS total_spent,
               COUNT(DISTINCT ul.game_id) AS games_owned,
               ROUND(COALESCE(SUM(ul.hours_played), 0), 1) AS total_hours
        FROM Users u
        LEFT JOIN User_Library ul ON u.user_id = ul.user_id
        GROUP BY u.user_id
        ORDER BY total_spent DESC
    ''')
    user_leaderboard = cur.fetchall()

    # Query 5: Completion status distribution across all users
    #          (aggregation on User_Library)
    cur.execute('''
        SELECT completion_status, COUNT(*) AS count
        FROM User_Library
        GROUP BY completion_status
    ''')
    completion_stats = cur.fetchall()

    cur.close()
    conn.close()
    return render_template('dashboard.html',
                           rating_by_genre=rating_by_genre,
                           top_games=top_games,
                           platform_stats=platform_stats,
                           user_leaderboard=user_leaderboard,
                           completion_stats=completion_stats)


# ════════════════════════════════════════════════════════════
#  RUN
# ════════════════════════════════════════════════════════════

if __name__ == '__main__':
    app.run(debug=True, port=5000)
