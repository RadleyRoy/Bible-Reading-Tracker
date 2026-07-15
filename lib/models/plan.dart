import '../data/kjv_data.dart';

/// A single chapter of the Bible, addressable by a global index
/// (0..1188 across all 66 books in canonical order).
class ChapterRef {
  final int globalIndex;
  final int bookIndex;

  /// 1-based chapter number within the book.
  final int chapter;
  final int words;

  const ChapterRef(this.globalIndex, this.bookIndex, this.chapter, this.words);

  String get reference => '${kjvBooks[bookIndex].name} $chapter';
}

/// First global chapter index of each book.
final List<int> bookStartIndex = _buildBookStartIndex();

/// Flat list of all 1,189 chapters in canonical order.
final List<ChapterRef> allChapters = _buildAllChapters();

List<int> _buildBookStartIndex() {
  final starts = <int>[];
  var index = 0;
  for (final book in kjvBooks) {
    starts.add(index);
    index += book.chapterCount;
  }
  return starts;
}

List<ChapterRef> _buildAllChapters() {
  final chapters = <ChapterRef>[];
  for (var b = 0; b < kjvBooks.length; b++) {
    final book = kjvBooks[b];
    for (var c = 0; c < book.chapterCount; c++) {
      chapters.add(ChapterRef(chapters.length, b, c + 1, book.chapterWords[c]));
    }
  }
  return chapters;
}

/// A named reading plan covering a contiguous range of books, to be
/// finished by [endDate].
class Plan {
  final String id;
  String name;

  /// Inclusive book range, as indices into [kjvBooks].
  int startBook;
  int endBook;

  DateTime startDate;
  DateTime endDate;

  /// Global indices of chapters marked as read.
  final Set<int> readChapters;

  /// The day (date-only) for which [assignedChapters] was computed.
  DateTime? assignedDate;

  /// Global indices making up the portion for [assignedDate]. Pinned for
  /// the whole day so reading (or un-reading) today's chapters does not
  /// shuffle the rest of the schedule; only chapters beyond this range
  /// affect the upcoming days.
  List<int> assignedChapters;

  Plan({
    required this.id,
    required this.name,
    required this.startBook,
    required this.endBook,
    required this.startDate,
    required this.endDate,
    Set<int>? readChapters,
    this.assignedDate,
    List<int>? assignedChapters,
  }) : readChapters = readChapters ?? <int>{},
       assignedChapters = assignedChapters ?? <int>[];

  /// All chapters covered by this plan, in reading order.
  List<ChapterRef> get chapters {
    final start = bookStartIndex[startBook];
    final end = bookStartIndex[endBook] + kjvBooks[endBook].chapterCount;
    return allChapters.sublist(start, end);
  }

  List<ChapterRef> get unreadChapters =>
      chapters.where((c) => !readChapters.contains(c.globalIndex)).toList();

  int get totalChapters =>
      bookStartIndex[endBook] +
      kjvBooks[endBook].chapterCount -
      bookStartIndex[startBook];

  bool isRead(int globalIndex) => readChapters.contains(globalIndex);

  bool get isComplete => readChapters.length >= totalChapters;

  /// Drops read marks that fall outside the current book range
  /// (used after editing the plan's portion).
  void pruneReadChapters() {
    final start = bookStartIndex[startBook];
    final end = bookStartIndex[endBook] + kjvBooks[endBook].chapterCount;
    readChapters.removeWhere((i) => i < start || i >= end);
  }

  /// Forces today's portion to be recomputed on the next schedule request
  /// (after a restart or an edit to the plan's range or dates).
  void invalidateAssignment() {
    assignedDate = null;
    assignedChapters = <int>[];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startBook': startBook,
    'endBook': endBook,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'readChapters': readChapters.toList()..sort(),
    'assignedDate': assignedDate?.toIso8601String(),
    'assignedChapters': assignedChapters,
  };

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
    id: json['id'] as String,
    name: json['name'] as String,
    startBook: json['startBook'] as int,
    endBook: json['endBook'] as int,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    readChapters: (json['readChapters'] as List).map((e) => e as int).toSet(),
    assignedDate: json['assignedDate'] == null
        ? null
        : DateTime.parse(json['assignedDate'] as String),
    assignedChapters: (json['assignedChapters'] as List?)
        ?.map((e) => e as int)
        .toList(),
  );
}
