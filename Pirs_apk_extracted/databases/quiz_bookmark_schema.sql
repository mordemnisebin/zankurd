-- table: sqlite_sequence
CREATE TABLE sqlite_sequence(name,seq);

-- table: tbl_bookmark
CREATE TABLE "tbl_bookmark" (
	"id"	INTEGER PRIMARY KEY AUTOINCREMENT,
	"que_id"	INTEGER,
	"question"	TEXT,
	"answer"	TEXT,
	"option_a"	TEXT,
	"option_b"	TEXT,
	"option_c"	TEXT,
	"option_d"	TEXT,
	"option_e"	TEXT,
	"image_url"	TEXT,
	"extra_note"	TEXT,
	"cate_name"	TEXT,
	"lang_id"	TEXT
);