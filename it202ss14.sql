create database session14;
use session14;

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    posts_count INT DEFAULT 0
);

CREATE TABLE posts (
    post_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS followers (
    follower_id INT NOT NULL,
    followed_id INT NOT NULL,
    PRIMARY KEY (follower_id, followed_id),
	FOREIGN KEY (follower_id) REFERENCES users(user_id) ON DELETE CASCADE,
	FOREIGN KEY (followed_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- ls1
INSERT INTO users (username)
VALUES ('alice'), ('bob');

START TRANSACTION;
INSERT INTO posts (user_id, content)
VALUES (1, 'Bài viết đầu tiên của Alice');
UPDATE users
SET posts_count = posts_count + 1
WHERE user_id = 1;
COMMIT;

START TRANSACTION;
INSERT INTO posts (user_id, content)
VALUES (999, 'lỗi');
UPDATE users
SET posts_count = posts_count + 1
WHERE user_id = 999;
ROLLBACK;

SELECT * FROM posts;
SELECT * FROM users;

-- ls2
CREATE TABLE likes (
    like_id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
	FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
	FOREIGN KEY (user_id) REFERENCES users(user_id) ON UPDATE CASCADE,
    CONSTRAINT unique_like
        UNIQUE (post_id, user_id)
);
ALTER TABLE posts
ADD COLUMN likes_count INT DEFAULT 0;

START TRANSACTION;

INSERT INTO likes (post_id, user_id)
VALUES (1, 2);

UPDATE posts
SET likes_count = likes_count + 1
WHERE post_id = 1;

COMMIT;

SELECT * FROM likes;
SELECT post_id, likes_count FROM posts;

START TRANSACTION;

INSERT INTO likes (post_id, user_id)
VALUES (1, 2);

UPDATE posts
SET likes_count = likes_count + 1
WHERE post_id = 1;

ROLLBACK;

-- ls3
ALTER TABLE users
ADD COLUMN following_count INT DEFAULT 0,
ADD COLUMN followers_count INT DEFAULT 0;

DELIMITER //

CREATE PROCEDURE sp_follow_user (
    IN p_follower_id INT,
    IN p_followed_id INT
)
BEGIN
    DECLARE v_count INT DEFAULT 0;
    -- Bắt lỗi SQL bất kỳ
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        INSERT INTO follow_log (follower_id, followed_id, error_message)
        VALUES (p_follower_id, p_followed_id, 'SQL Exception xảy ra');
    END;
    START TRANSACTION;
    -- 1. Không được tự follow chính mình
    IF p_follower_id = p_followed_id THEN
        INSERT INTO follow_log (follower_id, followed_id, error_message)
        VALUES (p_follower_id, p_followed_id, 'Không thể tự follow chính mình');
        ROLLBACK;
        LEAVE proc_end;
    END IF;
    -- 2. Kiểm tra follower tồn tại
    SELECT COUNT(*) INTO v_count
    FROM users
    WHERE user_id = p_follower_id;
    IF v_count = 0 THEN
        INSERT INTO follow_log (follower_id, followed_id, error_message)
        VALUES (p_follower_id, p_followed_id, 'Follower không tồn tại');
        ROLLBACK;
        LEAVE proc_end;
    END IF;
    -- 3. Kiểm tra followed tồn tại
    SELECT COUNT(*) INTO v_count
    FROM users
    WHERE user_id = p_followed_id;
    IF v_count = 0 THEN
        INSERT INTO follow_log (follower_id, followed_id, error_message)
        VALUES (p_follower_id, p_followed_id, 'User được follow không tồn tại');
        ROLLBACK;
        LEAVE proc_end;
    END IF;
    -- 4. Kiểm tra đã follow trước đó chưa
    SELECT COUNT(*) INTO v_count
    FROM followers
    WHERE follower_id = p_follower_id
      AND followed_id = p_followed_id;
    IF v_count > 0 THEN
        INSERT INTO follow_log (follower_id, followed_id, error_message)
        VALUES (p_follower_id, p_followed_id, 'Đã follow trước đó');
        ROLLBACK;
        LEAVE proc_end;
    END IF;
    -- 5. Thực hiện follow
    INSERT INTO followers (follower_id, followed_id)
    VALUES (p_follower_id, p_followed_id);
    -- 6. Cập nhật following_count
    UPDATE users
    SET following_count = following_count + 1
    WHERE user_id = p_follower_id;
    -- 7. Cập nhật followers_count
    UPDATE users
    SET followers_count = followers_count + 1
    WHERE user_id = p_followed_id;
    COMMIT;
    proc_end: BEGIN END;
END//

DELIMITER ;
CALL sp_follow_user(1, 2);
CALL sp_follow_user(1, 1);
CALL sp_follow_user(1, 999);

SELECT * FROM followers;
SELECT user_id, following_count, followers_count FROM users;
SELECT * FROM follow_log;

-- ls4
CREATE TABLE IF NOT EXISTS comments (
    comment_id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
	FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
ALTER TABLE posts
ADD COLUMN comments_count INT DEFAULT 0;
DELIMITER //

CREATE PROCEDURE sp_post_comment (
    IN p_post_id INT,
    IN p_user_id INT,
    IN p_content TEXT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    START TRANSACTION;
    -- 1. Thêm bình luận
    INSERT INTO comments (post_id, user_id, content)
    VALUES (p_post_id, p_user_id, p_content);
    -- 2. Tạo SAVEPOINT sau khi insert comment
    SAVEPOINT after_insert;
    -- 3. Giả lập lỗi khi content = 'ERROR'
    IF p_content = 'ERROR' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Giả lập lỗi ở bước UPDATE';
    END IF;
    -- 4. Cập nhật số lượng bình luận
    UPDATE posts
    SET comments_count = comments_count + 1
    WHERE post_id = p_post_id;
    -- 5. Nếu mọi thứ thành công
    COMMIT;
END//

DELIMITER ;
CALL sp_post_comment(1, 2, 'Bình luận hợp lệ');
CALL sp_post_comment(1, 2, 'ERROR');

SELECT * FROM comments;
SELECT post_id, comments_count FROM posts;
