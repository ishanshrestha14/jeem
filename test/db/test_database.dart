import 'package:drift/native.dart';
import 'package:gymflow/db/app_database.dart';

AppDatabase testDatabase() => AppDatabase(NativeDatabase.memory());
