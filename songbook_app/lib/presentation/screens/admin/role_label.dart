import 'package:flutter/material.dart';

import '../../../data/models/app_role.dart';
import '../../../l10n/app_localizations.dart';

/// The user-facing name of a role.
///
/// A function rather than a getter on [AppRole] because the enum lives in the
/// data layer and must not depend on localisation — and because these are the
/// names people read, so they are translated rather than being the wire names
/// with a capital letter. "Member" is not "member" is not `member`.
String roleLabel(AppLocalizations l10n, AppRole role) => switch (role) {
      AppRole.member => l10n.roleMember,
      AppRole.moderator => l10n.roleModerator,
      AppRole.administrator => l10n.roleAdministrator,
    };

/// What the role lets someone do, in one line, for a role picker.
String roleDescription(AppLocalizations l10n, AppRole role) => switch (role) {
      AppRole.member => l10n.roleMemberDescription,
      AppRole.moderator => l10n.roleModeratorDescription,
      AppRole.administrator => l10n.roleAdministratorDescription,
    };

/// One selectable role in a picker: a [ListTile] with a tick.
///
/// ListTile rather than RadioListTile, matching the decision already recorded in
/// `settings_screen.dart` — the Radio API those dialogs used is deprecated in
/// favour of a RadioGroup ancestor, and the choice taken there was to stop adding
/// to that debt rather than to migrate every dialog at once. Same dialog shape,
/// same reasoning.
class RoleOptionTile extends StatelessWidget {
  final AppRole role;
  final AppRole selected;
  final bool showDescription;
  final ValueChanged<AppRole> onSelected;

  const RoleOptionTile({
    super.key,
    required this.role,
    required this.selected,
    required this.onSelected,
    this.showDescription = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSelected = role == selected;

    return ListTile(
      title: Text(roleLabel(l10n, role)),
      subtitle: showDescription ? Text(roleDescription(l10n, role)) : null,
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      selected: isSelected,
      onTap: () => onSelected(role),
    );
  }
}
