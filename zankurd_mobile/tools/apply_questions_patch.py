import os
import sys

try:
    from supabase import create_client, Client
except ImportError:
    print("Installing supabase client library...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "supabase"])
    from supabase import create_client, Client

def main():
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    
    if not url or not key:
        print("Error: Please set SUPABASE_URL and SUPABASE_SERVICE_KEY environment variables.")
        sys.exit(1)
        
    print("Connecting to Supabase...")
    supabase: Client = create_client(url, key)
    
    # 1) Fix known leaked/wrong question IDs
    leaked_ids = [
        '09ee8855-9989-413f-902c-54c52c8722b5',
        '0db5f493-43d8-4918-b1b5-d76145ae0b59',
        '149cf5b1-1147-4111-b58b-eae6036eb3c2',
        '1bc1d1cd-e273-4ecc-bbe3-19a3f870b565',
        '244b3b1e-51f1-4f57-99fb-0104d4848037',
        '2eba9a25-3ed5-4027-9d44-d7429c80df90',
        '3a287cc2-e435-49f5-8481-f791fb7322d8',
        '4071753a-708f-4a1f-87ac-956de425746e',
        '49ad383e-0eb4-46d2-8941-bcd12f6a9fde',
        '83abb3ea-470e-404e-b18d-07252f54feb5',
        '9f7b8b61-8be5-43d8-9c7c-f0450838d26e',
        'e3862f30-9ccc-454e-a109-504dc2742206'
    ]
    print(f"Disapproving {len(leaked_ids)} leaked/incorrect questions...")
    try:
        res = supabase.table('questions').update({'is_approved': False}).in_('id', leaked_ids).execute()
        print("Leaked questions updated successfully.")
    except Exception as e:
        print(f"Error updating leaked questions: {e}")
        
    # 2) Find duplicates and disapprove them
    print("Fetching active questions to check for duplicates...")
    try:
        # Fetching questions (select only the required fields to keep payload small)
        res = supabase.table('questions').select('id, prompt, difficulty, created_at').execute()
        questions = res.data
        print(f"Fetched {len(questions)} questions.")
        
        # Group by prompt
        grouped = {}
        for q in questions:
            prompt = q['prompt'].strip().lower()
            if prompt not in grouped:
                grouped[prompt] = []
            grouped[prompt].append(q)
            
        duplicate_ids_to_disapprove = []
        for prompt, list_q in grouped.items():
            if len(list_q) > 1:
                # Sort: keep the one with lowest difficulty, then oldest created_at, then lowest id
                list_q.sort(key=lambda x: (x.get('difficulty', 5), x.get('created_at', ''), x['id']))
                keep_q = list_q[0]
                for dup in list_q[1:]:
                    duplicate_ids_to_disapprove.append(dup['id'])
                    
        if duplicate_ids_to_disapprove:
            print(f"Found {len(duplicate_ids_to_disapprove)} duplicate questions to disapprove.")
            # Update in batches of 100 to avoid URL length issues
            batch_size = 100
            for i in range(0, len(duplicate_ids_to_disapprove), batch_size):
                batch = duplicate_ids_to_disapprove[i:i+batch_size]
                supabase.table('questions').update({'is_approved': False}).in_('id', batch).execute()
            print("Duplicate questions disapproved successfully.")
        else:
            print("No duplicate questions found.")
            
    except Exception as e:
        print(f"Error processing duplicates: {e}")

if __name__ == "__main__":
    main()
