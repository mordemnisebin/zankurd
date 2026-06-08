-- table: level
CREATE TABLE `level` (
	`id`	INTEGER PRIMARY KEY AUTOINCREMENT,
	`cat_id`	INTEGER,
	`sub_cat_id`	INTEGER,
	`level_no`	INTEGER
);

-- table: sqlite_sequence
CREATE TABLE sqlite_sequence(name,seq);