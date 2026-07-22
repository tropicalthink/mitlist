import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) => writeResponseData(
      data,
      testOutputFilename: 'ocr_eval_results_ppocrv6_device',
    ),
  );
}
