# Pinned ONNX Runtime wrapper

This directory contains the Dart FFI wrapper from
[`onnxruntime` 1.4.1](https://pub.dev/packages/onnxruntime), licensed under MIT,
with its native mobile runtime updated from ONNX Runtime 1.15.1 to 1.20.0.

Why it is local:

- the published Flutter wrapper bundles an Android library aligned for 4 KiB
  memory pages;
- the official ONNX Runtime 1.20.0 Android core library is aligned for 16 KiB
  pages;
- pinning the Android binaries and iOS CocoaPod here keeps both platforms on
  the same runtime version and prevents a transitive update from changing OCR
  behavior.

The Android libraries are copied from the official Maven Central artifact
`com.microsoft.onnxruntime:onnxruntime-android:1.20.0` (AAR SHA-256
`07a8f71ef890afed8c6087a56220e6d558a492804276ee2dd7cb7f6262242027`).
Only the C API library used by Dart FFI is bundled; the Java JNI wrapper is not
used. iOS resolves the matching official `onnxruntime-c` CocoaPod at build
time. The bundled library SHA-256 values are:

- arm64-v8a: `52329b7c8e5fcd5c1aa88b01093215faaef362e3f3d0e374cb8b10d1e4704677`
- armeabi-v7a: `634fc9868e3ac188f78feb75c9fd8bfe6cb5f52bda84df0863fbaebe083e6350`
