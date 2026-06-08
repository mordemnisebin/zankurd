$content = Get-Content -Path 'c:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile\lib\src\data\supabase_zankurd_repository.dart' -Raw
$oldString = @"
  @override
  Future<void> ensureProfile() {
    return upsertProfile(displayName: 'ZanKurd Oyuncusu');
  }

  @override
  Future<List<String>> loadCategories() async {
