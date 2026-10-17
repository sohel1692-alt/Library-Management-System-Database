

CREATE DATABASE IF NOT EXISTS library_db;
USE library_db;

-- ---------- 1. Users (login accounts, with role) ----------
CREATE TABLE IF NOT EXISTS users (
    user_id       INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash CHAR(64)     NOT NULL,                       -- SHA-256 hex
    role          ENUM('ADMIN','USER') NOT NULL DEFAULT 'USER',
    is_active     TINYINT(1)   NOT NULL DEFAULT 1,             -- 0 = blocked by admin
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------- 2. Permissions master list ----------
CREATE TABLE IF NOT EXISTS permissions (
    perm_id     INT AUTO_INCREMENT PRIMARY KEY,
    perm_name   VARCHAR(30)  NOT NULL UNIQUE,
    description VARCHAR(100)
);

-- ---------- 3. Which user has which permission (many-to-many) ----------
CREATE TABLE IF NOT EXISTS user_permissions (
    user_id    INT NOT NULL,
    perm_id    INT NOT NULL,
    granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, perm_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id)       ON DELETE CASCADE,
    FOREIGN KEY (perm_id) REFERENCES permissions(perm_id) ON DELETE CASCADE
);

-- ---------- 4. Books ----------
CREATE TABLE IF NOT EXISTS books (
    book_id          INT AUTO_INCREMENT PRIMARY KEY,
    title            VARCHAR(150) NOT NULL,
    author           VARCHAR(100) NOT NULL,
    isbn             VARCHAR(30)  NOT NULL DEFAULT 'N/A',
    total_copies     INT NOT NULL,
    available_copies INT NOT NULL,
    CHECK (total_copies >= 0),
    CHECK (available_copies >= 0 AND available_copies <= total_copies),
    INDEX idx_books_title  (title),
    INDEX idx_books_author (author)
);

-- ---------- 5. Issue / return history ----------
CREATE TABLE IF NOT EXISTS issue_records (
    record_id   INT AUTO_INCREMENT PRIMARY KEY,
    book_id     INT NOT NULL,
    member_name VARCHAR(100) NOT NULL,
    issued_by   INT NULL,                       -- staff user who issued it
    issue_date  DATE NOT NULL,
    return_date DATE NULL,                      -- NULL = still issued
    FOREIGN KEY (book_id)   REFERENCES books(book_id) ON DELETE RESTRICT,
    FOREIGN KEY (issued_by) REFERENCES users(user_id) ON DELETE SET NULL
);

-- ---------- 6. View: currently issued books ----------
CREATE OR REPLACE VIEW v_active_issues AS
SELECT r.record_id, b.title, r.member_name, u.username AS issued_by, r.issue_date
FROM issue_records r
JOIN books b       ON b.book_id = r.book_id
LEFT JOIN users u  ON u.user_id = r.issued_by
WHERE r.return_date IS NULL;

-- ---------- Seed data ----------
INSERT IGNORE INTO permissions (perm_name, description) VALUES
 ('ADD_BOOK',    'Add new books to the catalog'),
 ('VIEW_BOOKS',  'View the full book list'),
 ('ISSUE_BOOK',  'Issue books to members'),
 ('RETURN_BOOK', 'Process book returns'),
 ('SEARCH_BOOK', 'Search the catalog');

-- Default admin: admin / admin123
INSERT INTO users (username, password_hash, role)
SELECT 'admin', SHA2('admin123', 256), 'ADMIN' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');

INSERT INTO books (title, author, isbn, total_copies, available_copies)
SELECT * FROM (
    SELECT 'The Pragmatic Programmer' AS t, 'Andrew Hunt' AS a, '9780135957059' AS i, 3 AS tc, 3 AS ac UNION ALL
    SELECT 'Clean Code', 'Robert C. Martin', '9780132350884', 2, 2 UNION ALL
    SELECT 'Effective Java', 'Joshua Bloch', '9780134685991', 4, 4
) AS seed
WHERE NOT EXISTS (SELECT 1 FROM books);

