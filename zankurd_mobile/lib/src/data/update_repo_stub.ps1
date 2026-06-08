(Get-Content -Path 'c:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile\lib\src\data\zankurd_repository.dart') -replace 'Future<void> ensureProfile\(\);', "Future<void> ensureProfile();
  Future<String> getProfileName();
  Future<void> updateProfileName(String name);
  Future<LeaderboardEntry?> getPlayerStats();" | Set-Content -Path 'c:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile\lib\src\data\zankurd_repository.dart'
