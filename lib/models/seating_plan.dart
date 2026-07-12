class SeatingPlan {
  final int? id;
  final String name;
  final int rows;
  final int columns;
  final String? extraLabel; // z.B. "Betrieb", "Firma", "Instrument"
  final String? extraLabel2;
  final String? extraLabel3;
  final String? groupName; // z.B. "Klasse 7a", "Kurs Mathe"
  final DateTime createdAt;
  final DateTime updatedAt;

  SeatingPlan({
    this.id,
    required this.name,
    required this.rows,
    required this.columns,
    this.extraLabel,
    this.extraLabel2,
    this.extraLabel3,
    this.groupName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get hasExtraField => extraLabels.isNotEmpty;
  List<String> get extraLabels => [
    extraLabel,
    extraLabel2,
    extraLabel3,
  ].whereType<String>().where((label) => label.isNotEmpty).toList();

  SeatingPlan copyWith({
    int? id,
    String? name,
    int? rows,
    int? columns,
    String? extraLabel,
    String? extraLabel2,
    String? extraLabel3,
    String? groupName,
    bool clearExtraLabel = false,
    bool clearExtraLabel2 = false,
    bool clearExtraLabel3 = false,
    bool clearGroupName = false,
    DateTime? updatedAt,
  }) {
    return SeatingPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      extraLabel: clearExtraLabel ? null : (extraLabel ?? this.extraLabel),
      extraLabel2: clearExtraLabel2 ? null : (extraLabel2 ?? this.extraLabel2),
      extraLabel3: clearExtraLabel3 ? null : (extraLabel3 ?? this.extraLabel3),
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
      'extra_label_2': extraLabel2,
      'extra_label_3': extraLabel3,
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
      extraLabel2: map['extra_label_2'] as String?,
      extraLabel3: map['extra_label_3'] as String?,
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
  final String? extraInfo2;
  final String? extraInfo3;

  Seat({
    this.id,
    required this.planId,
    required this.row,
    required this.col,
    this.firstName,
    this.lastName,
    this.photoPath,
    this.extraInfo,
    this.extraInfo2,
    this.extraInfo3,
  });

  bool get isEmpty =>
      firstName == null &&
      lastName == null &&
      photoPath == null &&
      extraInfo == null &&
      extraInfo2 == null &&
      extraInfo3 == null;
  List<String?> get extraInfos => [extraInfo, extraInfo2, extraInfo3];

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
    String? extraInfo2,
    String? extraInfo3,
    bool clearPhoto = false,
    bool clearExtraInfo = false,
    bool clearExtraInfo2 = false,
    bool clearExtraInfo3 = false,
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
      extraInfo2: clearExtraInfo2 ? null : (extraInfo2 ?? this.extraInfo2),
      extraInfo3: clearExtraInfo3 ? null : (extraInfo3 ?? this.extraInfo3),
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
      'extra_info_2': extraInfo2,
      'extra_info_3': extraInfo3,
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
      extraInfo2: map['extra_info_2'] as String?,
      extraInfo3: map['extra_info_3'] as String?,
    );
  }
}
