Pod::Spec.new do |s|
  s.name             = 'onnxruntime'
  s.version          = '1.20.0'
  s.summary          = 'Pinned ONNX Runtime C API for Mitlist on-device OCR.'
  s.description      = 'Provides the official ONNX Runtime 1.20.0 binary to the shared Dart FFI OCR implementation.'
  s.homepage         = 'https://github.com/microsoft/onnxruntime'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'ONNX Runtime' => 'onnxruntime@microsoft.com' }
  s.source           = { :path => '.' }
  s.dependency 'Flutter'
  s.dependency 'onnxruntime-c', '1.20.0'
  s.platform         = :ios, '13.0'
  s.static_framework = true
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end

