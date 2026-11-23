/// A class queue for the Flamingo station. Roll IDs only: no names, no
/// photos, nothing else about a child.
class Roster {
  final List<String> _queue;
  final Set<String> _done = {};

  Roster(Iterable<String> rollIds) : _queue = _clean(rollIds);

  /// One roll ID per line, or separated by commas or semicolons.
  factory Roster.parse(String text) => Roster(text.split(RegExp(r'[\n,;]')));

  static List<String> _clean(Iterable<String> ids) {
    final seen = <String>{};
    return [
      for (final raw in ids)
        if (raw.trim().isNotEmpty && seen.add(raw.trim())) raw.trim(),
    ];
  }

  List<String> get all => List.unmodifiable(_queue);
  int get total => _queue.length;
  int get doneCount => _done.length;
  bool get finished => total > 0 && doneCount == total;

  /// The next child who has not been tested yet, or null.
  String? get next {
    for (final id in _queue) {
      if (!_done.contains(id)) return id;
    }
    return null;
  }

  bool isDone(String id) => _done.contains(id);

  /// Mark a child as tested. Unknown IDs are ignored.
  void markDone(String id) {
    if (_queue.contains(id)) _done.add(id);
  }

  /// Put a child back in the queue, e.g. after a deleted trial.
  void reopen(String id) => _done.remove(id);

  Map<String, dynamic> toMap() => {'queue': _queue, 'done': _done.toList()};

  static Roster fromMap(Map<dynamic, dynamic> map) {
    final roster = Roster(
        (map['queue'] as List? ?? const []).whereType<String>().toList());
    for (final id in (map['done'] as List? ?? const []).whereType<String>()) {
      roster.markDone(id);
    }
    return roster;
  }
}
