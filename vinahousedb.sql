CREATE DATABASE  vinahouseDB;
USE vinahouseDB;


CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,                      
    username VARCHAR(100) NOT NULL UNIQUE,                  
    email VARCHAR(100) NOT NULL UNIQUE,                    
    password VARCHAR(255) NOT NULL,                         
    full_name VARCHAR(255),                                 
    avatar_url VARCHAR(255),                                
    is_active BOOLEAN DEFAULT TRUE,                         
    role ENUM('user', 'premium_user', 'artist', 'admin') DEFAULT 'user', 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,         
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP 
);

CREATE TABLE artists (
    id INT AUTO_INCREMENT PRIMARY KEY,                      
    name VARCHAR(255) NOT NULL,                             
    image_url VARCHAR(255),                                 
    verified BOOLEAN DEFAULT FALSE,                         
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,         
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP 
);


CREATE TABLE genres (
    id INT AUTO_INCREMENT PRIMARY KEY,                      
    name VARCHAR(255) NOT NULL UNIQUE                       
);


CREATE TABLE songs (
    id INT AUTO_INCREMENT PRIMARY KEY,                      
    title VARCHAR(255) NOT NULL,                            
    song_file_url VARCHAR(255) NOT NULL,                    
    image_url VARCHAR(255),                                 
    duration INT,                                          
    file_format VARCHAR(10),                                
    file_size INT,                                          
    is_featured BOOLEAN DEFAULT FALSE,                      
    is_approved BOOLEAN DEFAULT TRUE,                       
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,         
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP 
);


CREATE TABLE song_genre (
    song_id INT,                                            
    genre_id INT,                                           
    FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE, 
    FOREIGN KEY (genre_id) REFERENCES genres(id) ON DELETE CASCADE, 
    PRIMARY KEY (song_id, genre_id)                         
);


CREATE TABLE song_artist (
    song_id INT,                                            
    artist_id INT,                                          
    role ENUM('primary', 'featured', 'composer', 'producer') DEFAULT 'primary',
    FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE, 
    FOREIGN KEY (artist_id) REFERENCES artists(id) ON DELETE CASCADE, 
    PRIMARY KEY (song_id, artist_id, role)                  
);


CREATE TABLE playlists (
    id INT AUTO_INCREMENT PRIMARY KEY,                      
    name VARCHAR(255) NOT NULL,                             
    user_id INT,                                            
    is_public BOOLEAN DEFAULT FALSE,                        
    cover_image_url VARCHAR(255),                           
    song_count INT DEFAULT 0,                               
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,         
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, 
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE 
);

-- Bảng playlist_song: Quan hệ nhiều-nhiều giữa danh sách phát và bài hát
CREATE TABLE playlist_song (
    playlist_id INT,                                        
    song_id INT,                                            
    position INT NOT NULL,                                  
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,           
    FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE, 
    FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE, 
    PRIMARY KEY (playlist_id, song_id)                      
);

-- Bảng favorites: Lưu bài hát yêu thích của người dùng
CREATE TABLE favorites (
    user_id INT,                                            
    song_id INT,                                            
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,           
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE, 
    FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE, 
    PRIMARY KEY (user_id, song_id)                          
);

-- Bảng listening_history: Lưu lịch sử nghe nhạc
CREATE TABLE listening_history (
    id INT AUTO_INCREMENT PRIMARY KEY,                      
    user_id INT,                                            
    song_id INT,                                            
    listened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,        
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE, 
    FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE  
);

-- Tạo các chỉ mục (index) để tối ưu hóa truy vấn
CREATE INDEX idx_songs_title ON songs(title);               -- Index cho tìm kiếm bài hát theo tên
CREATE INDEX idx_songs_is_featured ON songs(is_featured);   -- Index cho lọc bài hát nổi bật
CREATE INDEX idx_users_username ON users(username);         -- Index cho tìm kiếm người dùng theo tên đăng nhập
CREATE INDEX idx_users_email ON users(email);               -- Index cho tìm kiếm người dùng theo email
CREATE INDEX idx_listening_history_listened_at ON listening_history(listened_at); -- Index cho lọc lịch sử theo thời gian
CREATE INDEX idx_playlists_user_id ON playlists(user_id);   -- Index cho lấy danh sách playlist theo người dùng
CREATE INDEX idx_playlists_is_public ON playlists(is_public); -- Index cho lọc playlist công khai
CREATE INDEX idx_favorites_user_id ON favorites(user_id);   -- Index cho lấy danh sách yêu thích theo người dùng

-- Tạo FULLTEXT index cho tìm kiếm nhanh
CREATE FULLTEXT INDEX idx_songs_search ON songs(title);     -- Fulltext index cho tìm kiếm bài hát
CREATE FULLTEXT INDEX idx_artists_search ON artists(name);  -- Fulltext index cho tìm kiếm nghệ sĩ

-- Trigger để cập nhật số lượng bài hát trong playlist khi thêm/xóa bài hát
DELIMITER //
CREATE TRIGGER update_playlist_count_insert AFTER INSERT ON playlist_song
FOR EACH ROW
BEGIN
    UPDATE playlists SET song_count = song_count + 1 WHERE id = NEW.playlist_id;
END//

CREATE TRIGGER update_playlist_count_delete AFTER DELETE ON playlist_song
FOR EACH ROW
BEGIN
    UPDATE playlists SET song_count = song_count - 1 WHERE id = OLD.playlist_id;
END//
DELIMITER ;

ALTER TABLE users 
MODIFY COLUMN role ENUM('user', 'artist', 'admin') DEFAULT 'user';

DROP TABLE listening_history;

-- tạo dữ liệu người dùng 
DELIMITER //
CREATE PROCEDURE register_user(
    IN p_username VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_password VARCHAR(255),
    IN p_full_name VARCHAR(255)
)
BEGIN
    -- Kiểm tra username và email đã tồn tại chưa
    IF EXISTS (SELECT 1 FROM users WHERE username = p_username) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username already exists';
    END IF;
    
    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email already exists';
    END IF;
    
    -- Thêm user mới
    INSERT INTO users (username, email, password, full_name, role, is_active)
    VALUES (p_username, p_email, p_password, p_full_name, 'user', TRUE);
END//
DELIMITER ;

-- giúp người dùng thay đổi pass
DELIMITER //
CREATE PROCEDURE change_user_password(
    IN p_user_id INT,
    IN p_old_password VARCHAR(255),
    IN p_new_password VARCHAR(255)
)
BEGIN
    -- Kiểm tra password cũ có đúng không
    IF (SELECT password FROM users WHERE id = p_user_id) != p_old_password THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Incorrect old password';
    END IF;
    
    -- Cập nhật password mới
    UPDATE users 
    SET password = p_new_password,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_user_id;
END//
DELIMITER ;

-- tạo bảng để lưu dữ thông tin chỉnh sửa 
CREATE TABLE admin_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    admin_id INT,
    action VARCHAR(255) NOT NULL,
    target_table VARCHAR(100),
    target_id INT,
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE SET NULL
);

-- quản lý user 
DELIMITER //
CREATE PROCEDURE manage_user(
    IN p_admin_id INT,
    IN p_user_id INT,
    IN p_action ENUM('ACTIVATE', 'DEACTIVATE', 'DELETE'),
    IN p_reason VARCHAR(255)
)
BEGIN
    -- Kiểm tra quyền admin
    IF (SELECT role FROM users WHERE id = p_admin_id) != 'admin' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only admins can perform this action';
    END IF;
    
    -- Không cho admin tự xóa hoặc vô hiệu hóa chính mình
    IF p_admin_id = p_user_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Admin cannot modify their own account';
    END IF;
    
    CASE p_action
        WHEN 'ACTIVATE' THEN
            UPDATE users SET is_active = TRUE WHERE id = p_user_id;
        WHEN 'DEACTIVATE' THEN
            UPDATE users SET is_active = FALSE WHERE id = p_user_id;
        WHEN 'DELETE' THEN
            DELETE FROM users WHERE id = p_user_id;
    END CASE;
    
    -- Ghi log hành động
    INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
    VALUES (p_admin_id, p_action, 'users', p_user_id, p_reason);
END//
DELIMITER ;

-- quản lý dữ liệu bài hát
DELIMITER //
CREATE PROCEDURE manage_song(
    IN p_admin_id INT,
    IN p_song_id INT,
    IN p_action ENUM('APPROVE', 'REJECT', 'DELETE', 'FEATURE'),
    IN p_reason VARCHAR(255)
)
BEGIN
    -- Kiểm tra quyền admin
    IF (SELECT role FROM users WHERE id = p_admin_id) != 'admin' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only admins can perform this action';
    END IF;
    
    CASE p_action
        WHEN 'APPROVE' THEN
            UPDATE songs SET is_approved = TRUE WHERE id = p_song_id;
        WHEN 'REJECT' THEN
            UPDATE songs SET is_approved = FALSE WHERE id = p_song_id;
        WHEN 'DELETE' THEN
            DELETE FROM songs WHERE id = p_song_id;
        WHEN 'FEATURE' THEN
            UPDATE songs SET is_featured = TRUE WHERE id = p_song_id;
    END CASE;
    
    -- Ghi log hành động
    INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
    VALUES (p_admin_id, p_action, 'songs', p_song_id, p_reason);
END//
DELIMITER ;

-- quản lý ca sĩ - dj
DELIMITER //
CREATE PROCEDURE manage_artist(
    IN p_admin_id INT,
    IN p_artist_id INT,
    IN p_action ENUM('CREATE', 'UPDATE', 'DELETE', 'VERIFY', 'UNVERIFY'),
    IN p_name VARCHAR(255),
    IN p_image_url VARCHAR(255),
    IN p_reason VARCHAR(255)
)
BEGIN
    -- Kiểm tra quyền admin
    IF (SELECT role FROM users WHERE id = p_admin_id) != 'admin' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only admins can perform this action';
    END IF;
    
    -- Không cho admin tự xóa hoặc vô hiệu hóa chính mình nếu có liên quan
    IF p_action = 'DELETE' AND p_artist_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM users WHERE id = p_admin_id AND role = 'artist' AND id = p_artist_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Admin cannot delete their own artist profile';
    END IF;
    
    CASE p_action
        WHEN 'CREATE' THEN
            INSERT INTO artists (name, image_url, verified)
            VALUES (p_name, p_image_url, FALSE);
            SET @new_artist_id = LAST_INSERT_ID();
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'CREATE', 'artists', @new_artist_id, p_reason);
            
        WHEN 'UPDATE' THEN
            UPDATE artists 
            SET name = COALESCE(p_name, name),
                image_url = COALESCE(p_image_url, image_url),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = p_artist_id;
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'UPDATE', 'artists', p_artist_id, p_reason);
            
        WHEN 'DELETE' THEN
            DELETE FROM artists WHERE id = p_artist_id;
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'DELETE', 'artists', p_artist_id, p_reason);
            
        WHEN 'VERIFY' THEN
            UPDATE artists SET verified = TRUE WHERE id = p_artist_id;
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'VERIFY', 'artists', p_artist_id, p_reason);
            
        WHEN 'UNVERIFY' THEN
            UPDATE artists SET verified = FALSE WHERE id = p_artist_id;
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'UNVERIFY', 'artists', p_artist_id, p_reason);
    END CASE;
END//
DELIMITER ;

-- quản lý thể loại 
DELIMITER //
CREATE PROCEDURE manage_genre(
    IN p_admin_id INT,
    IN p_genre_id INT,
    IN p_action ENUM('CREATE', 'UPDATE', 'DELETE'),
    IN p_name VARCHAR(255),
    IN p_reason VARCHAR(255)
)
BEGIN
    -- Kiểm tra quyền admin
    IF (SELECT role FROM users WHERE id = p_admin_id) != 'admin' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only admins can perform this action';
    END IF;
    
    CASE p_action
        WHEN 'CREATE' THEN
            INSERT INTO genres (name)
            VALUES (p_name);
            SET @new_genre_id = LAST_INSERT_ID();
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'CREATE', 'genres', @new_genre_id, p_reason);
            
        WHEN 'UPDATE' THEN
            UPDATE genres 
            SET name = COALESCE(p_name, name)
            WHERE id = p_genre_id;
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'UPDATE', 'genres', p_genre_id, p_reason);
            
        WHEN 'DELETE' THEN
            DELETE FROM genres WHERE id = p_genre_id;
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'DELETE', 'genres', p_genre_id, p_reason);
    END CASE;
END//
DELIMITER ;

-- quản lý playlist 
DELIMITER //
CREATE PROCEDURE manage_playlist(
    IN p_admin_id INT,
    IN p_playlist_id INT,
    IN p_action ENUM('UPDATE', 'DELETE', 'MAKE_PUBLIC', 'MAKE_PRIVATE'),
    IN p_name VARCHAR(255),
    IN p_cover_image_url VARCHAR(255),
    IN p_reason VARCHAR(255)
)
BEGIN
    -- Kiểm tra quyền admin
    IF (SELECT role FROM users WHERE id = p_admin_id) != 'admin' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only admins can perform this action';
    END IF;
    
    CASE p_action
        WHEN 'UPDATE' THEN
            UPDATE playlists 
            SET name = COALESCE(p_name, name),
                cover_image_url = COALESCE(p_cover_image_url, cover_image_url),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = p_playlist_id;
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'UPDATE', 'playlists', p_playlist_id, p_reason);
            
        WHEN 'DELETE' THEN
            DELETE FROM playlists WHERE id = p_playlist_id;
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'DELETE', 'playlists', p_playlist_id, p_reason);
            
        WHEN 'MAKE_PUBLIC' THEN
            UPDATE playlists SET is_public = TRUE WHERE id = p_playlist_id;
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'MAKE_PUBLIC', 'playlists', p_playlist_id, p_reason);
            
        WHEN 'MAKE_PRIVATE' THEN
            UPDATE playlists SET is_public = FALSE WHERE id = p_playlist_id;
            INSERT INTO admin_logs (admin_id, action, target_table, target_id, details)
            VALUES (p_admin_id, 'MAKE_PRIVATE', 'playlists', p_playlist_id, p_reason);
    END CASE;
END//
DELIMITER ;

-- dữ liệu bài hát
INSERT INTO songs (id, title, song_file_url, image_url, duration, file_format, file_size, is_featured, is_approved, created_at, updated_at) VALUES
(1, 'GIAC MO TUYET TRANG', 'C:\\Users\\phung\\Downloads\\-- GIAC MO TUYET TRANG - RUM X BIONIC FULL H.mp3', NULL, 282, 'MP3', 11052, 1, 1, '2025-03-17 01:48:14', '2025-03-17 01:48:14'),
(2, 'Sai Nguoi Sai Thoi Diem', 'C:\\Users\\phung\\Downloads\\Sai Nguoi Sai Thoi Diem - Rum Full.mp3', NULL, 401, 'MP3', 15672, 1, 1, '2025-03-17 01:48:14', '2025-03-17 01:48:14'),
(3, 'TINH EM LA DAI DUONG', 'C:\\Users\\phung\\Downloads\\TINH EM LA DAI DUONG _ RUM.mp3', NULL, 352, 'MP3', 13777, 1, 1, '2025-03-17 01:48:14', '2025-03-17 01:48:14'),
(4, 'DEM TRANG TINH YEU', 'C:\\Users\\phung\\Downloads\\DEM TRANG TINH YEU _ RUMBARCADI FULL.mp3', NULL, 364, 'MP3', 14235, 1, 1, '2025-03-17 01:48:14', '2025-03-17 01:48:14'),
(5, 'Ngoi Nha Hoa Hong Full', 'C:\\Users\\phung\\Downloads\\Ngoi Nha Hoa Hong Full - Rum ft NhanCivili HD.mp3', NULL, 254, 'MP3', 9946, 1, 1, '2025-03-17 01:48:14', '2025-03-17 01:48:14'),
(6, 'TUYET YEU THUONG _ DJ RUMBARCADI Ft LEEDUY REMIX', 'C:\\Users\\phung\\Downloads\\TUYET YEU THUONG _ DJ RUMBARCADI Ft LEEDUY REMIX.mp3', NULL, 331, 'MP3', 12951, 1, 1, '2025-03-17 01:48:14', '2025-03-17 01:48:14'),
(7, 'KHI NAO _ RUMBARCADI MIX FULL-1', 'C:\\Users\\phung\\Downloads\\KHI NAO _ RUMBARCADI MIX FULL-1.mp3', NULL, 274, 'MP3', 10708, 1, 1, '2025-03-17 01:48:14', '2025-03-17 01:48:14'),
(8, 'MUA TUYET _ RUMBARCADI MIX1', 'C:\\Users\\phung\\Downloads\\MUA TUYET _ RUMBARCADI MIX1.mp3', NULL, 329, 'MP3', 12865, 1, 1, '2025-03-17 01:48:14', '2025-03-17 01:48:14'),
(9, 'PHUT BIET LY _ HD JESSICA FULL', 'C:\\Users\\phung\\Downloads\\PHUT BIET LY _ HD JESSICA FULL.mp3', NULL, 316, 'MP3', 12359, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52'),
(10, 'NGUOI NAO DO _ RUMBARCADI FT TINBLACKY _ FULL', 'C:\\Users\\phung\\Downloads\\NGUOI NAO DO _ RUMBARCADI FT TINBLACKY _ FULL.mp3', NULL, 272, 'MP3', 10652, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52');

INSERT INTO songs (id, title, song_file_url, image_url, duration, file_format, file_size, is_featured, is_approved, created_at, updated_at) VALUES
(11, 'XUAN LY _ TINH VE NOI DAU _ DJ RUMBARCADI MIX FULL', 'C:\\Users\\phung\\Downloads\\XUAN LY _ TINH VE NOI DAU _ DJ RUMBARCADI MIX FULL.mp3', NULL, 337, 'MP3', 13194, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52'),
(12, 'Dung Co Yeu - Rumbarcadi Ft Bionic', 'C:\\Users\\phung\\Downloads\\Khac Viet - Dung Co Yeu - Rumbarcadi Ft Bionic Full Mix.mp3', NULL, 260, 'MP3', 10182, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52'),
(13, 'VI MOT NGUOI _ RUM _ LEEDUY _ BIONIC FULL MIX', 'C:\\Users\\phung\\Downloads\\VI MOT NGUOI _ RUM _ LEEDUY _ BIONIC FULL MIX.mp3', NULL, 293, 'MP3', 11465, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52'),
(14, 'LUA DOI _ RUMBARCADI FULL', 'C:\\Users\\phung\\Downloads\\LUA DOI _ RUMBARCADI FULL.wav', NULL, 283, 'WAV', 48856, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52'),
(15, 'B - Energy 7 - Cuu Van Kip Khong - Rumbarcadi Remixx Vocal', 'C:\\Users\\phung\\Downloads\\B - 140 - Cuu Van Kip Khong - Rumbarcadi.mp3', NULL, 290, 'MP3', 11340, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52'),
(16, 'HO YEU AI MAT ROI _ RUMBARCADI MIXXX', 'C:\\Users\\phung\\Downloads\\HO YEU AI MAT ROI _ RUMBARCADI MIXXX.mp3', NULL, 364, 'MP3', 14235, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52'),
(17, 'CO LE A CHUA TUNG _ RUMBARCADI MIXX', 'C:\\Users\\phung\\Downloads\\CO LE A CHUA TUNG _ RUMBARCADI MIXX.mp3', NULL, 348, 'MP3', 13602, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52'),
(18, 'Rum - Hoang Mang - Full', 'C:\\Users\\phung\\Downloads\\Rum - Hoang Mang - Full.mp3', NULL, 340, 'MP3', 13320, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52'),
(19, 'ANH _ RUMBARCADI MIX', 'C:\\Users\\phung\\Downloads\\ANH _ RUMBARCADI MIX.mp3', NULL, 371, 'MP3', 14528, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52'),
(20, 'Ho Quang Hieu - Nguyen Dinh Vu - Con Buom Xuan - DJ Rumbarcadi ft Leeduy Remix', 'Ho Quang Hieu - Nguyen Dinh Vu - Con Buom Xuan - DJ Rumbarcadi ft Leeduy Remix', NULL, 270, 'MP3', 11408, 1, 1, '2025-03-17 09:43:52', '2025-03-17 09:43:52');

INSERT INTO songs (id, title, song_file_url, image_url, duration, file_format, file_size, is_featured, is_approved, created_at, updated_at) VALUES
(21, 'HÀ NHI-DĨ VÃNG NHẠT NHOÀ (KHANG CHJVAS REMIX)', 'C:\\Users\\phung\\Downloads\\HÀ NHI-DĨ VÃNG NHẠT NHOÀ (KHANG CHJVAS REMIX).mp3', NULL, 327, 'MP3', 12804, 1, 1, '2025-03-17 12:21:00', '2025-03-17 12:21:00'),
(22, 'Alan Walker-Faded( Ranji Remake+Intro)', 'C:\\Users\\phung\\Downloads\\Alan Walker-Faded( Ranji Remake+Intro).wav', NULL, 414, 'WAV', 71398, 1, 1, '2025-03-17 12:21:00', '2025-03-17 12:21:00'),
(23, 'GMT', 'C:\\Users\\phung\\Downloads\\GMT (2).mp3', NULL, 337, 'MP3', 13169, 1, 1, '2025-03-17 12:21:00', '2025-03-17 12:21:00'),
(24, 'I Need Your Love 2020 (TH Mix)', 'C:\\Users\\phung\\Downloads\\I Need Your Love 2020 (TH Mix).mp3', NULL, 369, 'MP3', 14779, 1, 1, '2025-03-17 12:21:00', '2025-03-17 12:21:00'),
(25, 'You 2021 - Thai Hoang Rmx', 'C:\\Users\\phung\\Downloads\\You 2021 - Thai Hoang Rmx.mp3', NULL, 338, 'MP3', 5292, 1, 1, '2025-03-17 12:21:00', '2025-03-17 12:21:00'),
(26, 'Khong Dau Vi Qua Dau - TH', 'C:\\Users\\phung\\Downloads\\Khong Dau Vi Qua Dau - TH.mp3', NULL, 358, 'MP3', 14382, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(27, 'Tinh Nong Ft Ngon Nen Truoc Gio - Thai Hoang', 'C:\\Users\\phung\\Downloads\\Tinh Nong Ft Ngon Nen Truoc Gio - Thai Hoang.mp3', NULL, 379, 'MP3', 16062, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(28, 'Bara Bara Bere Bere - Thai Hoang Remix', 'C:\\Users\\phung\\Downloads\\Bara Bara Bere Bere - Thai Hoang Remix.mp3', NULL, 289, 'MP3', 9607, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(29, '1977 Vlog - Thai Hoang Remix FULL', 'C:\\Users\\phung\\Downloads\\1977 Vlog - Thai Hoang Remix FULL.mp3', NULL, 329, 'MP3', 10864, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(30, 'China Mix - Tay Trai Chi Trang - Thai Hoang Remix Full', 'C:\\Users\\phung\\Downloads\\China Mix - Tay Trai Chi Trang - Thai Hoang Remix Full.wav', NULL, 314, 'WAV', 59061, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37');

INSERT INTO songs (id, title, song_file_url, image_url, duration, file_format, file_size, is_featured, is_approved, created_at, updated_at) VALUES
(31, 'DUY MANH - VẪN MÃI YÊU EM - THÁI HOÀNG REMIX', 'C:\\Users\\phung\\Downloads\\DUY MANH - VẪN MÃI YÊU EM - THÁI HOÀNG REMIX.wav', NULL, 320, 'WAV', 60001, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(32, 'City Of Dreams - Thái Hoàng Remix FULL', 'C:\\Users\\phung\\Downloads\\City Of Dreams - Thái Hoàng Remix FULL.mp3', NULL, 313, 'MP3', 10246, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(33, 'Song Xa Anh Ft Lan Cuoi - ThaiHoang (Trung Hoang)', 'C:\\Users\\phung\\Downloads\\Song Xa Anh Ft Lan Cuoi - ThaiHoang (Trung Hoang).mp3', NULL, 325, 'MP3', 12707, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(34, 'Hanh Phuc Do Em Khong Co (Version 2) - Thang Kanta X Thai Hoang Remix', 'C:\\Users\\phung\\Downloads\\Hanh Phuc Do Em Khong Co (Version 2) - Thang Kanta X Thai Hoang Remix.mp3', NULL, 332, 'MP3', 13424, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(35, 'Than Thoai (DJ Thai Hoang Remix)', 'C:\\Users\\phung\\Downloads\\Than Thoai (DJ Thai Hoang Remix).mp3', NULL, 363, 'MP3', 14251, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(36, 'Super Bomb', 'C:\\Users\\phung\\Downloads\\(DOC) Super Bomb - Thang Kanta X Dat Myn Remix.mp3', NULL, 261, 'MP3', 10630, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(37, 'Dong Thoi Gian - VAVH', 'C:\\Users\\phung\\Downloads\\Dong Thoi Gian - VAVH.mp3', NULL, 300, 'MP3', 11721, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(38, '10A - CHAY VE KHOC VOI ANH 2022- VAVH HD Tiddy', 'C:\\Users\\phung\\Downloads\\10A - CHAY VE KHOC VOI ANH 2022- VAVH HD Tiddy.mp3', NULL, 325, 'MP3', 12728, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(39, 'I Love My People - VAVH', 'C:\\Users\\phung\\Downloads\\I Love My People - VAVH.mp3', NULL, 285, 'MP3', 11163, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37'),
(40, 'Amore Mio - VAVH', 'C:\\Users\\phung\\Downloads\\Amore Mio - VAVH.mp3', NULL, 356, 'MP3', 13994, 1, 1, '2025-03-17 18:52:37', '2025-03-17 18:52:37');

INSERT INTO songs (id, title, song_file_url, image_url, duration, file_format, file_size, is_featured, is_approved, created_at, updated_at) VALUES
(41, 'KẸO FT A KO BIET DAU', 'C:\\Users\\phung\\Downloads\\KẸO FT A KO BIET DAU- VAVH .mp3', NULL, 257, 'MP3', 10066, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(42, 'VAVH - FEEL 2024 - REMIX', 'C:\\Users\\phung\\Downloads\\VAVH - FEEL 2024 - REMIX.mp3', NULL, 285, 'MP3', 11168, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(43, 'VAVH - NEXT LEVEL - REMIX', 'C:\\Users\\phung\\Downloads\\VAVH - NEXT LEVEL - REMIX.mp3', NULL, 284, 'MP3', 11030, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(44, 'Hen Gap Em Duoi Anh Trang (GLG Remix)', 'C:\\Users\\phung\\Downloads\\Hen Gap Em Duoi Anh Trang (GLG Remix).mp3', NULL, 238, 'MP3', 9354, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(45, 'Juicce, Ishimaru - Tek Tek Tek (Extended Mix)', 'C:\\Users\\phung\\Downloads\\Juicce, Ishimaru - Tek Tek Tek (Extended Mix).wav', NULL, 247, 'WAV', 42616, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(46, 'From Space & Reaction - Cabide OFICIAL 16bit', 'C:\\Users\\phung\\Downloads\\From Space & Reaction - Cabide OFICIAL 16bit.wav', NULL, 278, 'WAV', 52138, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(47, 'HƯƠNG NGỌC LAN - VAVH REMIX', 'C:\\Users\\phung\\Downloads\\HƯƠNG NGỌC LAN - VAVH REMIX.mp3', NULL, 288, 'MP3', 11256, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(48, 'Bye Baby Bye bye 2021 - Quan Rapper ft Vavh (1)', 'C:\\Users\\phung\\Downloads\\Bye Baby Bye bye 2021 - Quan Rapper ft Vavh (1).mp3', NULL, 340, 'MP3', 13310, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(49, 'Sao em no vay 2021 - VAVH', 'C:\\Users\\phung\\Downloads\\Sao em no vay 2021 - VAVH.mp3', NULL, 333, 'MP3', 13029, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(50, 'DJ Got Us Fallin\' In Love - VAVH', 'C:\\Users\\phung\\Downloads\\DJ Got Us Fallin\' In Love - VAVH.mp3', NULL, 308, 'MP3', 12056, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58');

INSERT INTO songs (id, title, song_file_url, image_url, duration, file_format, file_size, is_featured, is_approved, created_at, updated_at) VALUES
(51, 'STEREO LOVE - VAVH HD', 'C:\\Users\\phung\\Downloads\\STEREO LOVE - VAVH HD.mp3', NULL, 287, 'MP3', 11231, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(52, 'RUN TO YOU 2 - VAVH', 'C:\\Users\\phung\\Downloads\\RUN TO YOU 2 - VAVH.mp3', NULL, 263, 'MP3', 10276, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(53, 'I Like To Move It - VAVH', 'C:\\Users\\phung\\Downloads\\I Like To Move It - VAVH.mp3', NULL, 260, 'MP3', 9412, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(54, 'Drive By - VAVH', 'C:\\Users\\phung\\Downloads\\Drive By - VAVH.mp3', NULL, 296, 'MP3', 11587, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(55, 'Ghostly & Zai Hư - VAVH HD', 'C:\\Users\\phung\\Downloads\\Ghostly & Zai Hư - VAVH HD.mp3', NULL, 321, 'MP3', 12571, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(56, 'Thiên Đường Vắng Em - VAVH', 'C:\\Users\\phung\\Downloads\\Thiên Đường Vắng Em - VAVH.mp3', NULL, 322, 'MP3', 12584, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(57, 'She Got It - VAVH Remix', 'C:\\Users\\phung\\Downloads\\She Got It - VAVH Remix.mp3', NULL, 308, 'MP3', 12033, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(58, 'Nhu Vay Nhe - VAVH HD LinhLee', 'C:\\Users\\phung\\Downloads\\Nhu Vay Nhe - VAVH HD LinhLee.mp3', NULL, 342, 'MP3', 13372, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(59, 'Nắm Lấy Tay Anh - VAVH', 'C:\\Users\\phung\\Downloads\\Nắm Lấy Tay Anh - VAVH.mp3', NULL, 342, 'MP3', 13396, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58'),
(60, 'I WANT IT THAT WAY - VAVH (1)', 'C:\\Users\\phung\\Downloads\\I WANT IT THAT WAY - VAVH (1).mp3', NULL, 343, 'MP3', 13417, 1, 1, '2025-03-19 22:43:58', '2025-03-19 22:43:58');

INSERT INTO songs (id, title, song_file_url, image_url, duration, file_format, file_size, is_featured, is_approved, created_at, updated_at) VALUES
(61, 'CHAN TINH 2021 - VAVH FULL', 'C:\\Users\\phung\\Downloads\\CHAN TINH 2021 - VAVH FULL.mp3', NULL, 337, 'MP3', 13197, 1, 1, '2025-03-19 23:04:52', '2025-03-19 23:04:52'),
(62, 'Destination - VAVH', 'C:\\Users\\phung\\Downloads\\Destination - VAVH.mp3', NULL, 267, 'MP3', 10444, 1, 1, '2025-03-19 23:04:52', '2025-03-19 23:04:52'),
(63, 'Set fire to the rain 2021 - VAVH Remix', 'C:\\Users\\phung\\Downloads\\Set fire to the rain 2021 - VAVH Remix.wav', NULL, 312, 'WAV', 60217, 1, 1, '2025-03-19 23:04:52', '2025-03-19 23:04:52'),
(64, 'Love Me Or Hate Me - VAVH', 'C:\\Users\\phung\\Downloads\\Love Me Or Hate Me - VAVH.mp3', NULL, 276, 'MP3', 10788, 1, 1, '2025-03-19 23:04:52', '2025-03-19 23:04:52'),
(65, 'Chicken 2021 - VAVH', 'C:\\Users\\phung\\Downloads\\Chicken 2021 - VAVH.mp3', NULL, 253, 'MP3', 9907, 1, 1, '2025-03-19 23:04:52', '2025-03-19 23:04:52'),
(66, 'Sweet but Psycho - VaVh Remix', 'C:\\Users\\phung\\Downloads\\Sweet but Psycho - VaVh Remix.mp3', NULL, 257, 'MP3', 10059, 1, 1, '2025-03-19 23:04:52', '2025-03-19 23:04:52'),
(67, 'Rise Up 2020 - VAVH', 'C:\\Users\\phung\\Downloads\\Rise Up 2020 - VAVH.mp3', NULL, 264, 'MP3', 10333, 1, 1, '2025-03-19 23:04:52', '2025-03-19 23:04:52'),
(68, 'Outside - VAVH', 'C:\\Users\\phung\\Downloads\\Outside - VAVH.mp3', NULL, 304, 'MP3', 11895, 1, 1, '2025-03-19 23:04:52', '2025-03-19 23:04:52'),
(69, 'MAGIC TOUCH 2019 - VAVH', 'C:\\Users\\phung\\Downloads\\MAGIC TOUCH 2019 - VAVH.mp3', NULL, 311, 'MP3', 12158, 1, 1, '2025-03-19 23:04:52', '2025-03-19 23:04:52'),
(70, 'I Say Yeah - VAVH', 'C:\\Users\\phung\\Downloads\\I Say Yeah - VAVH.mp3', NULL, 298, 'MP3', 11655, 1, 1, '2025-03-19 23:04:52', '2025-03-19 23:04:52');

INSERT INTO songs (id, title, song_file_url, image_url, duration, file_format, file_size, is_featured, is_approved, created_at, updated_at) VALUES
(71, 'NUMA MUMA - BEE Remix', 'C:\\Users\\phung\\Downloads\\NUMA MUMA - BEE Remix.mp3', NULL, 365, 'MP3', 14267, 1, 1, '2025-03-19 23:39:13', '2025-03-19 23:39:13'),
(72, 'Find Your Self - Bee', 'C:\\Users\\phung\\Downloads\\Find Your Self - Bee.mp3', NULL, 309, 'MP3', 12107, 1, 1, '2025-03-19 23:39:13', '2025-03-19 23:39:13'),
(73, 'XIANG XIANG - BEE REMIX', 'C:\\Users\\phung\\Downloads\\XIANG XIANG - BEE REMIX.mp3', NULL, 322, 'MP3', 12581, 1, 1, '2025-03-19 23:39:13', '2025-03-19 23:39:13'),
(74, 'My Neck My Back - BEE Remix', 'C:\\Users\\phung\\Downloads\\My Neck My Back - BEE Remix.mp3', NULL, 313, 'MP3', 12262, 1, 1, '2025-03-19 23:39:13', '2025-03-19 23:39:13'),
(75, 'Relax 2020 - Bee Remix', 'C:\\Users\\phung\\Downloads\\Relax 2020 - Bee Remix.mp3', NULL, 281, 'MP3', 10985, 1, 1, '2025-03-19 23:39:13', '2025-03-19 23:39:13'),
(76, 'Take Me To Your Heart - Dj Bee 2', 'C:\\Users\\phung\\Downloads\\Take Me To Your Heart - Dj Bee 2.mp3', NULL, 341, 'MP3', 13328, 1, 1, '2025-03-19 23:39:13', '2025-03-19 23:39:13'),
(77, 'No More Goodbye - Bee remix', 'C:\\Users\\phung\\Downloads\\No More Goodbye - Bee remix.mp3', NULL, 354, 'MP3', 13894, 1, 1, '2025-03-19 23:39:13', '2025-03-19 23:39:13'),
(78, 'Anh Trang Tinh Ai - Bee', 'C:\\Users\\phung\\Downloads\\Anh Trang Tinh Ai - Bee.mp3', NULL, 306, 'MP3', 11989, 1, 1, '2025-03-19 23:39:13', '2025-03-19 23:39:13'),
(79, 'Tinh Dep Den May Cung Tan - Dj Bee', 'C:\\Users\\phung\\Downloads\\Tinh Dep Den May Cung Tan - Dj Bee.mp3', NULL, 257, 'MP3', 10054, 1, 1, '2025-03-19 23:39:13', '2025-03-19 23:39:13'),
(80, 'GỬI NGÀN LỜI YÊU - DJ BEE REMIX', 'C:\\Users\\phung\\Downloads\\GỬI NGÀN LỜI YÊU - DJ BEE REMIX.mp3', NULL, 335, 'MP3', 13100, 1, 1, '2025-03-19 23:39:13', '2025-03-19 23:39:13');

INSERT INTO songs (id, title, song_file_url, image_url, duration, file_format, file_size, is_featured, is_approved, created_at, updated_at) VALUES
(81, 'Không Nên Vấn Vương - JET Remix', 'C:\\Users\\phung\\Downloads\\Không Nên Vấn Vương - JET Remix.mp3', NULL, 393, 'MP3', 15356, 1, 1, '2025-03-20 16:01:43', '2025-03-20 16:01:43'),
(82, 'Bao Ngoc - Tình Khúc Vàng - Jet Remix', 'C:\\Users\\phung\\Downloads\\Bao Ngoc - Tình Khúc Vàng - Jet Remix.mp3', NULL, 334, 'MP3', 13049, 1, 1, '2025-03-20 16:01:43', '2025-03-20 16:01:43'),
(83, 'Noo - Quen - JET Remix', 'C:\\Users\\phung\\Downloads\\Noo - Quen - JET Remix.mp3', NULL, 294, 'MP3', 11491, 1, 1, '2025-03-20 16:01:43', '2025-03-20 16:01:43'),
(84, 'Toan Yo - Con Mua Bang Gia - JET Remix (full)', 'C:\\Users\\phung\\Downloads\\Toan Yo - Con Mua Bang Gia - JET Remix (full).mp3', NULL, 320, 'MP3', 10324, 1, 1, '2025-03-20 16:01:43', '2025-03-20 16:01:43'),
(85, 'NGAY MAI K CON NHO - JET', 'C:\\Users\\phung\\Downloads\\NGAY MAI K CON NHO - JET.mp3', NULL, 316, 'MP3', 12350, 1, 1, '2025-03-20 16:01:43', '2025-03-20 16:01:43'),
(86, 'E - READY TO FLY JET REMIX', 'C:\\Users\\phung\\Downloads\\E - READY TO FLY JET REMIX.mp3', NULL, 282, 'MP3', 11050, 1, 1, '2025-03-20 16:01:43', '2025-03-20 16:01:43'),
(87, 'Dung Di - JET Remix', 'C:\\Users\\phung\\Downloads\\Dung Di - JET Remix.mp3', NULL, 348, 'MP3', 13616, 1, 1, '2025-03-20 16:01:43', '2025-03-20 16:01:43'),
(88, 'Khac Viet - Sau bao năm - JET Remix', 'C:\\Users\\phung\\Downloads\\Khac Viet - Sau bao năm - JET Remix.mp3', NULL, 361, 'MP3', 14134, 1, 1, '2025-03-20 16:01:43', '2025-03-20 16:01:43'),
(89, 'Sugar Daddy HD Jet', 'C:\\Users\\phung\\Downloads\\Sugar Daddy HD Jet.wav', NULL, 294, 'WAV', 50769, 1, 1, '2025-03-20 16:01:43', '2025-03-20 16:01:43'),
(90, 'WHY - JET HD', 'C:\\Users\\phung\\Downloads\\WHY - JET HD.mp3', NULL, 325, 'MP3', 12713, 1, 1, '2025-03-20 16:01:43', '2025-03-20 16:01:43');

INSERT INTO songs (id, title, song_file_url, image_url, duration, file_format, file_size, is_featured, is_approved, created_at, updated_at) VALUES
(91, 'Timebomb - T-Bynz Remix (1)', 'C:\\Users\\phung\\Downloads\\Timebomb - T-Bynz Remix (1).mp3', NULL, 315, 'MP3', 13567, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08'),
(92, 'Make It Bum Style - T.Bynz', 'C:\\Users\\phung\\Downloads\\Make It Bum Style - T.Bynz.mp3', NULL, 343, 'MP3', 13424, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08'),
(93, 'Hom Qua Toi Da Khoc', 'C:\\Users\\phung\\Downloads\\Hom Qua Toi Da Khoc.mp3', NULL, 329, 'MP3', 12872, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08'),
(94, 'All My People - Lemon2k', 'C:\\Users\\phung\\Downloads\\All My People - Lemon2k .mp3', NULL, 333, 'MP3', 13025, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08'),
(95, 'Ana', 'C:\\Users\\phung\\Downloads\\Ana.mp3', NULL, 278, 'MP3', 10862, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08'),
(96, 'LEMON2K - STRONGER 2023 V2', 'C:\\Users\\phung\\Downloads\\LEMON2K - STRONGER 2023 V2.mp3', NULL, 301, 'MP3', 11788, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08'),
(97, 'Lao nhao', 'C:\\Users\\phung\\Downloads\\Lao nhao.mp3', NULL, 300, 'MP3', 11721, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08'),
(98, 'Battle Forte (Tiktok Remix)', 'C:\\Users\\phung\\Downloads\\BattleForteTiktokRemix-Lollipop-6037422.mp3', NULL, 233, 'MP3', 3661, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08'),
(99, 'Sweet Boy (TikTok Remix)', 'C:\\Users\\phung\\Downloads\\SweetBoyTikTokRemix-VA-5946929.mp3', NULL, 162, 'MP3', 2540, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08'),
(100, 'Bang Bang Bang (Tiktok Remix)', 'C:\\Users\\phung\\Downloads\\BangBangBangTiktokRemix-BigBang-6953716.mp3', NULL, 195, 'MP3', 3108, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08'),
(101, 'Leaving (Tiktok Remix)', 'C:\\Users\\phung\\Downloads\\LeavingTiktokRemix-VA-7004130.mp3', NULL, 157, 'MP3', 2468, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08'),
(102, 'Em Ơi Đừng Khóc (TikTok Remix)', 'C:\\Users\\phung\\Downloads\\EmOiDungKhocTikTokRemix-TangDuyTan-7615590.mp3', NULL, 146, 'MP3', 2301, 1, 1, '2025-03-20 22:49:08', '2025-03-20 22:49:08');

-- dữ liệu artist 
INSERT INTO artists (id, name, image_url, verified, created_at, updated_at) VALUES
(1, 'RUM BARACADI', NULL, 1, '2025-03-21 15:09:07', '2025-03-21 15:09:07'),
(2, 'THÁI HOÀNG', NULL, 1, '2025-03-21 15:09:07', '2025-03-21 15:09:07'),
(3, 'VAVH', NULL, 1, '2025-03-21 15:09:07', '2025-03-21 15:09:07'),
(4, 'BEE', NULL, 1, '2025-03-21 15:09:07', '2025-03-21 15:09:07'),
(5, 'JET', NULL, 1, '2025-03-21 15:09:07', '2025-03-21 15:09:07'),
(6, 'TBYNZ', NULL, 1, '2025-03-21 15:09:07', '2025-03-21 15:09:07'),
(7, 'LEMON_2K', NULL, 1, '2025-03-21 15:09:07', '2025-03-21 15:09:07');

-- dữ liệu genre 
INSERT INTO genres (id, name) VALUES
(6, 'NHẠC CỔ'),
(1, 'NHẠC GỖ'),
(2, 'NHẠC TRỐI'),
(3, 'NHẠC TỪNG TỪNG'),
(4, 'NHẠC VIỆT HOT'),
(5, 'TIKTOK REMIX');

-- dữ liệu playlist 
INSERT INTO playlists (id, name, user_id, is_public, cover_image_url, song_count, created_at, updated_at) VALUES
(1, 'Nhạc cổ dân hộc ban bay', NULL, 1, NULL, 0, '2025-03-21 15:10:59', '2025-03-21 15:10:59'),
(2, 'Nỗi tình yêu bất đầu', NULL, 1, NULL, 0, '2025-03-21 15:10:59', '2025-03-21 15:10:59'),
(3, 'nhạc phòng bay 2025', NULL, 1, NULL, 0, '2025-03-21 15:10:59', '2025-03-21 15:10:59'),
(4, 'thiên đường nhạc cổ', NULL, 1, NULL, 0, '2025-03-21 15:10:59', '2025-03-21 15:10:59'),
(5, 'Hơi ức', NULL, 1, NULL, 0, '2025-03-21 15:10:59', '2025-03-21 15:10:59'),
(6, 'Chặng trai năm ấy', NULL, 1, NULL, 0, '2025-03-21 15:10:59', '2025-03-21 15:10:59');

-- dữ liệu song - artist 
INSERT INTO song_artist (song_id, artist_id, role) VALUES
(1, 1, 'primary'),
(2, 1, 'primary'),
(3, 1, 'primary'),
(4, 1, 'primary'),
(5, 1, 'primary'),
(6, 1, 'primary'),
(7, 1, 'primary'),
(8, 1, 'primary'),
(9, 1, 'primary'),
(10, 1, 'primary'),
(11, 1, 'primary'),
(12, 1, 'primary'),
(13, 1, 'primary'),
(14, 1, 'primary'),
(15, 1, 'primary'),
(16, 1, 'primary'),
(17, 1, 'primary'),
(18, 1, 'primary'),
(19, 1, 'primary'),
(20, 1, 'primary'),
(21, 2, 'primary'),
(22, 2, 'primary'),
(23, 2, 'primary'),
(24, 2, 'primary'),
(25, 2, 'primary'),
(26, 2, 'primary'),
(27, 2, 'primary'),
(28, 2, 'primary'),
(29, 2, 'primary'),
(30, 2, 'primary'),
(31, 2, 'primary'),
(32, 2, 'primary'),
(33, 2, 'primary'),
(34, 2, 'primary'),
(35, 2, 'primary'),
(36, 3, 'primary'),
(37, 3, 'primary'),
(38, 3, 'primary'),
(39, 3, 'primary'),
(40, 3, 'primary'),
(41, 3, 'primary'),
(42, 3, 'primary'),
(43, 3, 'primary'),
(44, 3, 'primary'),
(45, 3, 'primary'),
(46, 3, 'primary'),
(47, 3, 'primary'),
(48, 3, 'primary'),
(49, 3, 'primary'),
(50, 3, 'primary'),
(51, 3, 'primary'),
(52, 3, 'primary'),
(53, 3, 'primary'),
(54, 3, 'primary'),
(55, 3, 'primary'),
(56, 3, 'primary'),
(57, 3, 'primary'),
(58, 3, 'primary'),
(59, 3, 'primary'),
(60, 3, 'primary'),
(61, 3, 'primary'),
(62, 3, 'primary'),
(63, 3, 'primary'),
(64, 3, 'primary'),
(65, 3, 'primary'),
(66, 3, 'primary'),
(67, 3, 'primary'),
(68, 3, 'primary'),
(69, 3, 'primary'),
(70, 3, 'primary'),
(71, 4, 'primary'),
(72, 4, 'primary'),
(73, 4, 'primary'),
(74, 4, 'primary'),
(75, 4, 'primary'),
(76, 4, 'primary'),
(77, 4, 'primary'),
(78, 4, 'primary'),
(79, 4, 'primary'),
(80, 4, 'primary'),
(81, 5, 'primary'),
(82, 5, 'primary'),
(83, 5, 'primary'),
(84, 5, 'primary'),
(85, 5, 'primary'),
(86, 5, 'primary'),
(87, 5, 'primary'),
(88, 5, 'primary'),
(89, 5, 'primary'),
(90, 5, 'primary'),
(91, 6, 'primary'),
(92, 6, 'primary'),
(93, 7, 'primary'),
(94, 7, 'primary'),
(95, 7, 'primary'),
(96, 7, 'primary'),
(97, 7, 'primary');

-- dữ liệu song genre
INSERT INTO song_genre (song_id, genre_id) VALUES
-- Thể loại 1: NHẠC GỖ (id 1-17)
(1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1), (10, 1),
(11, 1), (12, 1), (13, 1), (14, 1), (15, 1), (16, 1), (17, 1),
-- Thể loại 2: NHẠC TRỐI (id 18-34)
(18, 2), (19, 2), (20, 2), (21, 2), (22, 2), (23, 2), (24, 2), (25, 2), (26, 2), (27, 2),
(28, 2), (29, 2), (30, 2), (31, 2), (32, 2), (33, 2), (34, 2),
-- Thể loại 3: NHẠC TỪNG TỪNG (id 35-51)
(35, 3), (36, 3), (37, 3), (38, 3), (39, 3), (40, 3), (41, 3), (42, 3), (43, 3), (44, 3),
(45, 3), (46, 3), (47, 3), (48, 3), (49, 3), (50, 3), (51, 3),
-- Thể loại 4: NHẠC VIỆT HOT (id 52-68)
(52, 4), (53, 4), (54, 4), (55, 4), (56, 4), (57, 4), (58, 4), (59, 4), (60, 4), (61, 4),
(62, 4), (63, 4), (64, 4), (65, 4), (66, 4), (67, 4), (68, 4),
-- Thể loại 5: TIKTOK REMIX (id 69-86)
(69, 5), (70, 5), (71, 5), (72, 5), (73, 5), (74, 5), (75, 5), (76, 5), (77, 5), (78, 5),
(79, 5), (80, 5), (81, 5), (82, 5), (83, 5), (84, 5), (85, 5), (86, 5),
-- Thể loại 6: NHẠC CỔ (id 87-102)
(87, 6), (88, 6), (89, 6), (90, 6), (91, 6), (92, 6), (93, 6), (94, 6), (95, 6), (96, 6),
(97, 6), (98, 6), (99, 6), (100, 6), (101, 6), (102, 6);

-- dữ liệu trong song playlist 
INSERT INTO playlist_song (playlist_id, song_id, position) VALUES
-- Playlist 1: Playlist Nhạc Gỗ (song_id 1-17)
(1, 1, 1), (1, 2, 2), (1, 3, 3), (1, 4, 4), (1, 5, 5), (1, 6, 6), (1, 7, 7), (1, 8, 8), (1, 9, 9), (1, 10, 10),
(1, 11, 11), (1, 12, 12), (1, 13, 13), (1, 14, 14), (1, 15, 15), (1, 16, 16), (1, 17, 17),
-- Playlist 2: Playlist Nhạc Trối (song_id 18-34)
(2, 18, 1), (2, 19, 2), (2, 20, 3), (2, 21, 4), (2, 22, 5), (2, 23, 6), (2, 24, 7), (2, 25, 8), (2, 26, 9), (2, 27, 10),
(2, 28, 11), (2, 29, 12), (2, 30, 13), (2, 31, 14), (2, 32, 15), (2, 33, 16), (2, 34, 17),
-- Playlist 3: Playlist Nhạc Từng Từng (song_id 35-51)
(3, 35, 1), (3, 36, 2), (3, 37, 3), (3, 38, 4), (3, 39, 5), (3, 40, 6), (3, 41, 7), (3, 42, 8), (3, 43, 9), (3, 44, 10),
(3, 45, 11), (3, 46, 12), (3, 47, 13), (3, 48, 14), (3, 49, 15), (3, 50, 16), (3, 51, 17),
-- Playlist 4: Playlist Nhạc Việt Hot (song_id 52-68)
(4, 52, 1), (4, 53, 2), (4, 54, 3), (4, 55, 4), (4, 56, 5), (4, 57, 6), (4, 58, 7), (4, 59, 8), (4, 60, 9), (4, 61, 10),
(4, 62, 11), (4, 63, 12), (4, 64, 13), (4, 65, 14), (4, 66, 15), (4, 67, 16), (4, 68, 17),
-- Playlist 5: Playlist TikTok Remix (song_id 69-86)
(5, 69, 1), (5, 70, 2), (5, 71, 3), (5, 72, 4), (5, 73, 5), (5, 74, 6), (5, 75, 7), (5, 76, 8), (5, 77, 9), (5, 78, 10),
(5, 79, 11), (5, 80, 12), (5, 81, 13), (5, 82, 14), (5, 83, 15), (5, 84, 16), (5, 85, 17), (5, 86, 18),
-- Playlist 6: Playlist Nhạc Cổ (song_id 87-102)
(6, 87, 1), (6, 88, 2), (6, 89, 3), (6, 90, 4), (6, 91, 5), (6, 92, 6), (6, 93, 7), (6, 94, 8), (6, 95, 9), (6, 96, 10),
(6, 97, 11), (6, 98, 12), (6, 99, 13), (6, 100, 14), (6, 101, 15), (6, 102, 16);

-- dữ liệu admin 
INSERT INTO users (username, email, password, full_name, role, is_active)
VALUES ('admin1', 'admin1@vinahouse.com', 'secureAdminPass123', 'Admin One', 'admin', TRUE);

-- dữ liệu cho user 
INSERT INTO users (username, email, password, full_name) VALUES
('user0', 'user1@example.com', 'password123', 'Nguyễn Văn A'),
('user2', 'user2@example.com', 'password456', 'Trần Thị B'),
('user3', 'user3@example.com', 'password789', 'Lê Văn C');


