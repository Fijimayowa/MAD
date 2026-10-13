const List<String> kSuits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

String suitSymbol(String suit) {
  switch (suit) {
    case 'Hearts':
      return '\u2665';
    case 'Diamonds':
      return '\u2666';
    case 'Clubs':
      return '\u2663';
    case 'Spades':
      return '\u2660';
    default:
      return '?';
  }
}

/// Thrown by the helper when a folder name violates the UNIQUE constraint.
class DuplicateFolderException implements Exception {
  final String name;
  const DuplicateFolderException(this.name);

  @override
  String toString() => 'DuplicateFolderException: "$name" already exists';
}

class Folder {
  final int id;
  final String name;
  final String createdAt; // ISO-8601
  final int cardCount;

  const Folder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.cardCount,
  });

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: map['created_at'] as String,
      cardCount: (map['card_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'created_at': createdAt};
}

class CardRecord {
  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  const CardRecord({
    this.id,
    required this.title,
    required this.suit,
    this.notes = '',
    this.imageRef,
    required this.folderId,
  });

  factory CardRecord.fromMap(Map<String, dynamic> map) {
    return CardRecord(
      id: map['id'] as int,
      title: map['title'] as String,
      suit: map['suit'] as String,
      notes: (map['notes'] as String?) ?? '',
      imageRef: map['image_ref'] as String?,
      folderId: map['folder_id'] as int,
    );
  }

  /// Does not include the id: inserts let SQLite assign it, and updates
  /// target the row with WHERE id = ?.
  Map<String, dynamic> toMap() => {
        'title': title,
        'suit': suit,
        'notes': notes,
        'image_ref': imageRef,
        'folder_id': folderId,
      };
}