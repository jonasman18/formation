enum UserRole {
  apprenant,
  formateur,
  admin;

  static UserRole fromString(String? value) => UserRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => UserRole.apprenant,
      );

  bool get isStaff => this != UserRole.apprenant;

  String get label => switch (this) {
        UserRole.apprenant => 'Apprenant',
        UserRole.formateur => 'Formateur',
        UserRole.admin => 'Administrateur',
      };
}