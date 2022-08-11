CREATE TABLE IF NOT EXISTS memos (
    id SERIAL NOT NULL,
    title VARCHAR(100) NOT NULL,
    content TEXT,
    PRIMARY KEY (id)
);