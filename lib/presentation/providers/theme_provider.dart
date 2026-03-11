import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 테마 모드 Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
