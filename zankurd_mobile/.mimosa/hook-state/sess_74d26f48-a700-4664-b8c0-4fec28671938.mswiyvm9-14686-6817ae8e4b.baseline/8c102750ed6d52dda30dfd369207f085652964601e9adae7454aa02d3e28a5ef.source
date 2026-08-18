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

def unescape_dart_string(s: str) -> str:
    return s.replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n').replace('\\\\', '\\')

def parse_dart_string_field(field_text: str) -> str:
    parts = re.findall(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"", field_text)
    str_parts = []
    for p1, p2 in parts:
        str_parts.append(p1 if p1 else p2)
    return unescape_dart_string(''.join(str_parts))

def parse_dart_list(field_text: str) -> list:
    parts = re.findall(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"", field_text)
    str_parts = []
    for p1, p2 in parts:
        str_parts.append(unescape_dart_string(p1 if p1 else p2))
    return str_parts

def parse_sources(dart_text: str) -> dict:
    sources = {}
    pattern = re.compile(r'const (_\w+) = QuestionMetadata\(')
    for m in pattern.finditer(dart_text):
        var_name = m.group(1)
        start = m.end()
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
        
        block = dart_text[start:pos]
        
        field_names = ['reviewStatus', 'dialect', 'sourceTitle', 'sourceReference', 'qualityVersion']
        field_positions = []
        for fn in field_names:
            fm = re.search(r'\b' + fn + r':', block)
            if fm:
                field_positions.append((fm.start(), fn, fm.end()))
        
        field_positions.sort(key=lambda x: x[0])
        
        fields = {}
        for i in range(len(field_positions)):
            _, fn, val_start = field_positions[i]
            val_end = field_positions[i+1][0] if i+1 < len(field_positions) else len(block)
            val_text = block[val_start:val_end].strip().rstrip(',')
            fields[fn] = val_text
        
        src_data = {
            'reviewStatus': 'approved',
            'dialect': 'Kurmancî',
            'sourceTitle': '',
            'sourceReference': '',
            'qualityVersion': 2
        }
        
        if 'reviewStatus' in fields:
            rm = re.search(r'ReviewStatus\.(\w+)', fields['reviewStatus'])
            if rm:
                src_data['reviewStatus'] = rm.group(1)
        if 'dialect' in fields:
            src_data['dialect'] = parse_dart_string_field(fields['dialect'])
        if 'sourceTitle' in fields:
            src_data['sourceTitle'] = parse_dart_string_field(fields['sourceTitle'])
        if 'sourceReference' in fields:
            src_data['sourceReference'] = parse_dart_string_field(fields['sourceReference'])
        if 'qualityVersion' in fields:
            qm = re.search(r'(\d+)', fields['qualityVersion'])
            if qm:
                src_data['qualityVersion'] = int(qm.group(1))
        
        sources[var_name] = src_data
        
    return sources

def parse_questions(dart_text: str, sources: dict) -> list:
    questions = []
    list_start = dart_text.find('const editorialQuestionBank = <QuizQuestion>[')
    if list_start == -1:
        print("ERROR: could not find editorialQuestionBank", file=sys.stderr)
        return []
    
    pattern = re.compile(r'\bQuizQuestion\s*\(')
    
    for m in pattern.finditer(dart_text, list_start):
        start = m.end()
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
        q = parse_question_block(block, sources)
        if q:
            questions.append(q)
    
    return questions

def parse_question_block(block: str, sources: dict) -> dict:
    q = {
        'type': 'multipleChoice',
        'difficulty': 2,
    }
    
    field_names = [
        'id', 'category', 'prompt', 'answers', 'correctAnswer',
        'explanation', 'explanationKu', 'explanationTr',
        'type', 'imageUrl', 'difficulty', 'metadata'
    ]
    
    field_positions = []
    for fn in field_names:
        m = re.search(r'\b' + fn + r':', block)
        if m:
            field_positions.append((m.start(), fn, m.end()))
    
    field_positions.sort(key=lambda x: x[0])
    
    fields = {}
    for i in range(len(field_positions)):
        _, fn, val_start = field_positions[i]
        val_end = field_positions[i+1][0] if i+1 < len(field_positions) else len(block)
        val_text = block[val_start:val_end].strip().rstrip(',')
        fields[fn] = val_text
    
    if 'id' in fields:
        q['id'] = parse_dart_string_field(fields['id'])
    else:
        return None
    
    if 'category' in fields:
        q['category'] = parse_dart_string_field(fields['category'])
    if 'prompt' in fields:
        q['prompt'] = parse_dart_string_field(fields['prompt'])
    if 'answers' in fields:
        q['answers'] = parse_dart_list(fields['answers'])
    if 'correctAnswer' in fields:
        q['correctAnswer'] = parse_dart_string_field(fields['correctAnswer'])
    if 'explanation' in fields:
        q['explanation'] = parse_dart_string_field(fields['explanation'])
    if 'explanationKu' in fields:
        q['explanationKu'] = parse_dart_string_field(fields['explanationKu'])
    if 'explanationTr' in fields:
        q['explanationTr'] = parse_dart_string_field(fields['explanationTr'])
    
    if 'explanation' not in q or not q['explanation']:
        q['explanation'] = q.get('explanationTr') or q.get('explanationKu') or ''
    
    if 'type' in fields:
        tm = re.search(r'QuestionType\.(\w+)', fields['type'])
        if tm:
            q['type'] = tm.group(1)
    
    if 'imageUrl' in fields:
        q['imageUrl'] = parse_dart_string_field(fields['imageUrl'])
    
    if 'difficulty' in fields:
        dm = re.search(r'(\d+)', fields['difficulty'])
        if dm:
            q['difficulty'] = int(dm.group(1))
    
    if 'metadata' in fields:
        mm = re.search(r'(_\w+)', fields['metadata'])
        if mm and mm.group(1) in sources:
            q['metadata'] = sources[mm.group(1)]
    
    return q

def main():
    with open(DART_FILE, 'r', encoding='utf-8') as f:
        dart_text = f.read()
    
    sources = parse_sources(dart_text)
    print(f'Parsed {len(sources)} metadata sources:', list(sources.keys()), file=sys.stderr)
    
    questions = parse_questions(dart_text, sources)
    print(f'Parsed {len(questions)} questions from editorial_question_bank.dart', file=sys.stderr)
    
    with open(OUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(questions, f, ensure_ascii=False, indent=2)
    
    print(f'Written to {OUT_FILE}', file=sys.stderr)

if __name__ == '__main__':
    main()
