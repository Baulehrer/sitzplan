class SeatingPlan {
  final int? id;
  final String name;
  final int rows;
  final int columns;
  final String? extraLabel; // z.B. "Betrieb", "Firma", "Instrument"
  final String? groupName; // z.B. "Klasse 7a", "Kurs Mathe"
  final DateTime createdAt;
  final DateTime updatedAt;

  SeatingPlan({
    this.id,
    required this.name,
    required this.rows,
    required this.columns,
    this.extraLabel,
    this.groupName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get hasExtraField => extraLabel != null && extraLabel!.isNotEmpty;

  SeatingPlan copyWith({
    int? id,
    String? name,
    int? rows,
    int? columns,
    String? extraLabel,
    String? groupName,
    bool clearExtraLabel = false,
    bool clearGroupName = false,
    DateTime? updatedAt,
  }) {
    return SeatingPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      extraLabel: clearExtraLabel ? null : (extraLabel ?? this.extraLabel),
      groupName: clearGroupName ? null : (groupName ?? this.groupName),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'rows': rows,
      'columns': columns,
      'extra_label': extraLabel,
      'group_name': groupName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SeatingPlan.fromMap(Map<String, dynamic> map) {
    return SeatingPlan(
      id: map['id'] as int,
      name: map['name'] as String,
      rows: map['rows'] as int,
      columns: map['columns'] as int,
      extraLabel: map['extra_label'] as String?,
      groupName: map['group_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class Seat {
  final int? id;
  final int planId;
  final int row;
  final int col;
  final String? firstName;
  final String? lastName;
  final String? photoPath;
  final String? extraInfo; // z.B. Betriebsname

  Seat({
    this.id,
    required this.planId,
    required this.row,
    required this.col,
    this.firstName,
    this.lastName,
    this.photoPath,
    this.extraInfo,
  });

  bool get isEmpty =>
      firstName == null &&
      lastName == null &&
      photoPath == null &&
      extraInfo == null;

  String get displayName {
    if (firstName == null && lastName == null) return '';
    return [
      firstName,
      lastName,
    ].where((s) => s != null && s.isNotEmpty).join(' ');
  }

  Seat copyWith({
    int? id,
    int? planId,
    int? row,
    int? col,
    String? firstName,
    String? lastName,
    String? photoPath,
    String? extraInfo,
    bool clearPhoto = false,
    bool clearExtraInfo = false,
  }) {
    return Seat(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      row: row ?? this.row,
      col: col ?? this.col,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      extraInfo: clearExtraInfo ? null : (extraInfo ?? this.extraInfo),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'plan_id': planId,
      'row': row,
      'col': col,
      'first_name': firstName,
      'last_name': lastName,
      'photo_path': photoPath,
      'extra_info': extraInfo,
    };
  }

  factory Seat.fromMap(Map<String, dynamic> map) {
    return Seat(
      id: map['id'] as int,
      planId: map['plan_id'] as int,
      row: map['row'] as int,
      col: map['col'] as int,
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      photoPath: map['photo_path'] as String?,
      extraInfo: map['extra_info'] as String?,
    );
  }
}
