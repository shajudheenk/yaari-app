/// Shared design system and sign-in flow for the Yaari apps.
///
/// Both apps import this so the brand is defined once. The customer app
/// runs on ember; the provider app runs on slate, so a provider can never
/// confuse which app they are looking at.
library;

export 'src/auth.dart';
export 'src/auth_screens.dart';
export 'src/feel.dart';
export 'src/map.dart';
export 'src/media.dart';
export 'src/ds/ds.dart';
export 'src/marks.dart';
export 'src/palette.dart';
export 'src/register.dart';
export 'src/theme.dart';
export 'src/tiles.dart';
export 'src/widgets.dart';
