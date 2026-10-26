/// Kullanıcının gönderdiği soru önerisinin durumu ("Önerilerim").
///
/// Sunucuda `suggested_questions_read_own` politikası yalnız kendi
/// satırlarını okutur; burada yalnız listede gösterilenler taşınır.
enum MySuggestionStatus { pending, approved, rejected }

class MySuggestion {
  const MySuggestion({
    required this.id,
    required this.category,
    required this.prompt,
    required this.status,
    required this.createdAt,
    this.reviewNote,
  });

  final String id;
  final String category;
  final String prompt;
  final MySuggestionStatus status;
  final DateTime createdAt;

  /// Editörün notu (özellikle kabul edilmeyen öneride niçini).
  final String? reviewNote;

  factory MySuggestion.fromRow(Map<String, dynamic> row) {
    final note = (row['review_note'] as String?)?.trim();
    return MySuggestion(
      id: row['id'] as String,
      category: (row['category'] as String?) ?? '',
      prompt: (row['prompt'] as String?) ?? '',
      status: switch (row['status']) {
        'approved' => MySuggestionStatus.approved,
        'rejected' => MySuggestionStatus.rejected,
        _ => MySuggestionStatus.pending,
      },
      createdAt:
          DateTime.tryParse('${row['created_at']}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewNote: note == null || note.isEmpty ? null : note,
    );
  }
}
