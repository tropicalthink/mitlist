import 'package:dio/dio.dart';

import 'dio_platform_stub.dart' if (dart.library.html) 'dio_platform_web.dart'
    as platform;

void configureDioForPlatform(Dio dio) => platform.configureDioForPlatform(dio);
