#!/usr/bin/env python3
"""
editorial_to_json.py
Parses editorial_question_bank.dart and extracts questions to JSON.
"""

import re
import json
import sys

DART_FILE = 'lib/src/data/editorial_question_bank.dart'
OUT_FILE = 'assets/data/editorial_questions.json'

# Source metadata map (matches the _xxxSource consts in the dart file)
SOURCES = {
    '_rezimanSource': {
        'reviewStatus': 'approved',
        'dialect': 'Kurmancî',
        'sourceTitle': 'Rêzimana kurdî — Bedirxan & Lescot',
        'sourceReference': 'Celadet Alî Bedirxan & Roger Lescot, Grammaire Kurde (Dialecte Kurmandji), Paris 1970; Hawar (1932-1943)',
        'qualityVersion': 2,
    },
    '_ferhengSource': {
        'reviewStatus': 'approved',
        'dialect': 'Kurmancî',
        'sourceTitle': 'Ferhenga kurdî',
        'sourceReference': 'Zana Farqînî, Ferhenga Kurdî-Tirkî (2004); Michael L. Chyet, Kurdish-English Dictionary (Yale, 2003)',
        'qualityVersion': 2,
    },
    '_diroknasSource': {
        'reviewStatus': 'approved',
        'dialect': 'Kurmancî',
        'sourceTitle': 'Dîroka kurdan — çavkaniyên akademîk',
        'sourceReference': 'The Cambridge History of the Kurds (2021); Encyclopaedia Iranica — Kurds; Şerefxanê Bidlîsî, Şerefname (1597)',
        'qualityVersion': 2,
    },
    '_wejeSource': {
        'reviewStatus': 'approved',
        'dialect': 'Kurmancî',
        'sourceTitle': 'Wêjeya kurdî — antolojî û berhem',
        'sourceReference': 'Ehmedê Xanî, Mem û Zîn (1692); Mehmed Uzun, Kürt Edebiyatına Giriş; Melayê Cizîrî, Dîwan',
        'qualityVersion': 2,
    },
    '_cografyaSource': {
        'reviewStatus': 'approved',
        'dialect': 'Kurmancî',
        'sourceTitle': 'Erdnîgariya herêmê',
        'sourceReference': 'Encyclopaedia Britannica — Kurdistan, Zagros, Lake Van; UNESCO World Heritage List (Diyarbakır Fortress and Hevsel Gardens, 2015)',
        'qualityVersion': 2,
    },
    '_kulturSource': {
        'reviewStatus': 'approved',
        'dialect': 'Kurmancî',
        'sourceTitle': 'Çanda kurdî',
        'sourceReference': 'Philip Kreyenbroek & Christine Allison, Kurdish Culture and Identity (1996); Encyclopaedia Iranica — Newroz',
        'qualityVersion': 2,
    },
    '_muzikSource': {
        'reviewStatus': 'approved',
        'dialect': 'Kurmancî',
        'sourceTitle': 'Muzîka kurdî',
        'sourceReference': 'Martin van Bruinessen, Kurdish Ethno-Nationalism versus Nation-Building States (2000); Encyclopaedia Iranica — Kurdish Music',
        'qualityVersion': 2,
    },
    '_paradSource': {
        'reviewStatus': 'approved',
        'dialect': 'Kurmancî',
        'sourceTitle': 'Paradîgma demokratîk',
        'sourceReference': 'Abdullah Öcalan, Democratic Confederalism (2011); Jineolojî Academy publications',
        'qualityVersion': 2,
    },
    '_siyasetSource': {
        'reviewStatus': 'approved',
        'dialect': 'Kurmancî',
        'sourceTitle': 'Siyaseta kurdî',
        'sourceReference': 'David McDowall, A Modern History of the Kurds (2004); Encyclopaedia Iranica — Kurdish Political Parties',
        'qualityVersion': 2,
    },
    '_teknolSource': {
        'reviewStatus': 'approved',
        'dialect': 'Kurmancî',
        'sourceTitle': 'Teknolojî û zanist',
        'sourceReference': 'MIT Technology Review; Wikipedia — Kurdish-language Wikipedia statistics',
        'qualityVersion': 2,
    },
    '_jineolSource': {
        'reviewStatus': 'approved',
        'dialect': 'Kurmancî',
        'sourceTitle': 'Jineolojî',
        'sourceReference': "Cambridge, Beyond Feminism? Jineolojî and the Kurdish Women's Freedom Movement; https://kongra-star.org/eng/about/",
        'qualityVersion': 2,
    },
}

def unescape_dart_string(s: str) -> str:
    """Basic Dart string unescaping."""
    return s.replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n').replace('\\\\', '\\')

def parse_dart_string_value(raw: str) -> str:
    """Extract string content from a Dart field value (handles single and adjacent strings)."""
    raw = raw.strip().rstrip(',')
    # Handle string concatenation: 'a' 'b'
    parts = re.findall(r"'((?:[^'\\]|\\.)*)'", raw)
    if parts:
        return unescape_dart_string(''.join(parts))
    # Try double quotes
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', raw)
    if parts:
        return unescape_dart_string(''.join(parts))
    return raw

def parse_dart_list(raw: str) -> list:
    """Parse a Dart list of strings like ['a', 'b', 'c']."""
    items = re.findall(r"'((?:[^'\\]|\\.)*)'", raw)
    if not items:
        items = re.findall(r'"((?:[^"\\]|\\.)*)"', raw)
    return [unescape_dart_string(i) for i in items]

def read_dart_field(text: str, pos: int):
    """
    Starting at pos (after 'fieldName:'), reads a Dart value:
    - string literal (single or adjacent)
    - list literal [...]
    - identifier (_xxxSource, QuestionType.xxx, number)
    Returns (value_as_string, new_pos).
    """
    # skip whitespace and newlines
    while pos < len(text) and text[pos] in ' \t\n\r':
        pos += 1
    
    if pos >= len(text):
        return None, pos
    
    ch = text[pos]
    
    if ch == '[':
        # find matching ]
        depth = 0
        start = pos
        while pos < len(text):
            if text[pos] == '[':
                depth += 1
            elif text[pos] == ']':
                depth -= 1
                if depth == 0:
                    pos += 1
                    break
            pos += 1
        return text[start:pos], pos
    
    elif ch == "'":
        # Collect adjacent string literals
        result = ''
        while pos < len(text) and text[pos] == "'":
            pos += 1  # skip opening '
            s = ''
            while pos < len(text):
                c = text[pos]
                if c == '\\':
                    pos += 1
                    if pos < len(text):
                        s += '\\' + text[pos]
                        pos += 1
                elif c == "'":
                    pos += 1
                    break
                else:
                    s += c
                    pos += 1
            result += s
            # skip whitespace between adjacent strings
            while pos < len(text) and text[pos] in ' \t\n\r':
                pos += 1
        return result, pos
    
    elif ch == '"':
        pos += 1
        s = ''
        while pos < len(text):
            c = text[pos]
            if c == '\\':
                pos += 1
                if pos < len(text):
                    nc = text[pos]
                    if nc == 'n': s += '\n'
                    elif nc == 't': s += '\t'
                    else: s += nc
                    pos += 1
            elif c == '"':
                pos += 1
                break
            else:
                s += c
                pos += 1
        return s, pos
    
    else:
        # identifier or number — read until comma or closing paren
        start = pos
        while pos < len(text) and text[pos] not in ',)\n':
            pos += 1
        return text[start:pos].strip(), pos

def parse_questions(dart_text: str) -> list:
    """Parse all QuizQuestion(...) blocks from dart text."""
    questions = []
    
    # Find start of the list
    list_start = dart_text.find('const editorialQuestionBank = <QuizQuestion>[')
    if list_start == -1:
        print("ERROR: could not find editorialQuestionBank", file=sys.stderr)
        return []
    
    # Find all QuizQuestion( blocks
    pattern = re.compile(r'\bQuizQuestion\s*\(')
    
    for m in pattern.finditer(dart_text, list_start):
        start = m.end()  # position after '('
        
        # Find the matching closing paren
        depth = 1
        pos = start
        while pos < len(dart_text) and depth > 0:
            c = dart_text[pos]
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    break
            elif c == "'":
                pos += 1
                while pos < len(dart_text):
                    cc = dart_text[pos]
                    if cc == '\\':
                        pos += 1
                    elif cc == "'":
                        break
                    pos += 1
            elif c == '"':
                pos += 1
                while pos < len(dart_text):
                    cc = dart_text[pos]
                    if cc == '\\':
                        pos += 1
                    elif cc == '"':
                        break
                    pos += 1
            pos += 1
        
        block = dart_text[start:pos - 1]
        q = parse_question_block(block)
        if q:
            questions.append(q)
    
    return questions

def parse_question_block(block: str) -> dict:
    """Parse a QuizQuestion parameter block."""
    q = {
        'type': 'multipleChoice',
        'difficulty': 2,
    }
    
    # Field extraction using regex for named parameters
    fields = {
        'id': r"id:\s*'([^']*)'",
        'category': r"category:\s*'([^']*)'",
        'prompt': None,  # handle separately (multiline)
        'correctAnswer': r"correctAnswer:\s*'([^']*)'",
        'type': r'type:\s*QuestionType\.(\w+)',
        'imageUrl': r"imageUrl:\s*'([^']*)'",
        'difficulty': r'difficulty:\s*(\d+)',
        'metadata': r'metadata:\s*(_\w+)',
    }
    
    # id
    m = re.search(r"id:\s*'((?:[^'\\]|\\.)*)'", block)
    if not m:
        return None
    q['id'] = unescape_dart_string(m.group(1))
    
    # category
    m = re.search(r"category:\s*'((?:[^'\\]|\\.)*)'", block)
    if m:
        q['category'] = unescape_dart_string(m.group(1))
    
    # prompt — might span multiple lines with concatenation
    m = re.search(r'prompt:\s*([\s\S]*?)(?=,\s*\w+:|,\s*metadata:|,\s*\))', block)
    if m:
        prompt_raw = m.group(1)
        parts = re.findall(r"'((?:[^'\\]|\\.)*)'", prompt_raw)
        q['prompt'] = unescape_dart_string(''.join(parts)) if parts else prompt_raw.strip()
    
    # answers
    m = re.search(r'answers:\s*\[([\s\S]*?)\]', block)
    if m:
        q['answers'] = parse_dart_list('[' + m.group(1) + ']')
    
    # correctAnswer
    m = re.search(r"correctAnswer:\s*'((?:[^'\\]|\\.)*)'", block)
    if m:
        q['correctAnswer'] = unescape_dart_string(m.group(1))
    
    # explanation
    m = re.search(r'explanation:\s*([\s\S]*?)(?=,\s*\w+:|,\s*metadata:|\),)', block)
    if m:
        raw = m.group(1)
        parts = re.findall(r"'((?:[^'\\]|\\.)*)'", raw)
        if parts:
            q['explanation'] = unescape_dart_string(''.join(parts))
    
    # explanationKu
    m = re.search(r'explanationKu:\s*([\s\S]*?)(?=,\s*\w+:|,\s*metadata:|\),)', block)
    if m:
        raw = m.group(1)
        parts = re.findall(r"'((?:[^'\\]|\\.)*)'", raw)
        if parts:
            q['explanationKu'] = unescape_dart_string(''.join(parts))
    
    # explanationTr
    m = re.search(r'explanationTr:\s*([\s\S]*?)(?=,\s*\w+:|,\s*metadata:|\),)', block)
    if m:
        raw = m.group(1)
        parts = re.findall(r"'((?:[^'\\]|\\.)*)'", raw)
        if parts:
            q['explanationTr'] = unescape_dart_string(''.join(parts))
    
    # type
    m = re.search(r'type:\s*QuestionType\.(\w+)', block)
    if m:
        q['type'] = m.group(1)
    
    # imageUrl
    m = re.search(r"imageUrl:\s*'((?:[^'\\]|\\.)*)'", block)
    if m:
        q['imageUrl'] = unescape_dart_string(m.group(1))
    
    # difficulty
    m = re.search(r'difficulty:\s*(\d+)', block)
    if m:
        q['difficulty'] = int(m.group(1))
    
    # metadata
    m = re.search(r'metadata:\s*(_\w+)', block)
    if m:
        src_name = m.group(1)
        if src_name in SOURCES:
            q['metadata'] = SOURCES[src_name]
    
    # Validate minimal required fields
    if 'prompt' not in q or 'answers' not in q or 'correctAnswer' not in q:
        print(f"WARNING: incomplete question {q.get('id', '?')}", file=sys.stderr)
        return None
    
    return q


def main():
    with open(DART_FILE, 'r', encoding='utf-8') as f:
        dart_text = f.read()
    
    questions = parse_questions(dart_text)
    print(f'Parsed {len(questions)} questions from editorial_question_bank.dart', file=sys.stderr)
    
    with open(OUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(questions, f, ensure_ascii=False, indent=2)
    
    print(f'Written to {OUT_FILE}', file=sys.stderr)


if __name__ == '__main__':
    main()
