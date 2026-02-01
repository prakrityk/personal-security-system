// lib/core/providers/app_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final initialAuthCheckCompletedProvider = StateProvider<bool>((ref) => false);
