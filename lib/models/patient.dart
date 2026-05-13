import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum Sex { maschio, femmina, nonSpecificato }

extension SexExt on Sex {
  String get label {
    switch (this) {
      case Sex.maschio:
        return 'Maschio';
      case Sex.femmina:
        return 'Femmina';
      case Sex.nonSpecificato:
        return 'Non specificato';
    }
  }
}

class Patient {
  final String id;
  final String name;
  final Sex sex;
  final DateTime? birthday;
  final String telephone;
  final String email;
  final String remark;
  final DateTime createdAt;

  Patient({
    String? id,
    required this.name,
    this.sex = Sex.nonSpecificato,
    this.birthday,
    this.telephone = '',
    this.email = '',
    this.remark = '',
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  int? get age {
    if (birthday == null) return null;
    final now = DateTime.now();
    int age = now.year - birthday!.year;
    if (now.month < birthday!.month ||
        (now.month == birthday!.month && now.day < birthday!.day)) {
      age--;
    }
    return age;
  }

  Patient copyWith({
    String? name,
    Sex? sex,
    DateTime? birthday,
    String? telephone,
    String? email,
    String? remark,
  }) {
    return Patient(
      id: id,
      name: name ?? this.name,
      sex: sex ?? this.sex,
      birthday: birthday ?? this.birthday,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      remark: remark ?? this.remark,
      createdAt: createdAt,
    );
  }
}
