import re, json, urllib.request

PROF = r"C:\Users\AMARGİ\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
def token():
    txt = open(PROF, encoding='utf-8').read()
    m = re.search(r'SUPABASE_ACCESS_TOKEN\s*=\s*["\']([^"\']+)["\']', txt)
    return m.group(1)

def query(sql):
    body = json.dumps({"query": sql}).encode('utf-8')
    req = urllib.request.Request(
        "https://api.supabase.com/v1/projects/hupivnxgjtsfafulzspo/database/query",
        data=body, method="POST",
        headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode('utf-8'))
