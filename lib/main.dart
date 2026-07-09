import 'package:flutter/widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:wetaran_pharma/app/bootstrap/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrap();
}
