# Bundled PP-OCRv6 models

The app bundles these official PaddlePaddle models for offline inference:

- `PaddlePaddle/PP-OCRv6_small_det_onnx`
- `PaddlePaddle/PP-OCRv6_medium_rec_onnx`

Source:

- https://huggingface.co/PaddlePaddle/PP-OCRv6_small_det_onnx
- https://huggingface.co/PaddlePaddle/PP-OCRv6_medium_rec_onnx

License: Apache License 2.0, as declared by both upstream repositories.

Both model graphs are byte-identical to upstream. SHA-256:

- detector: `d73e0058b7a8086bbd57f3d10b8bcd4ff95363f67e06e2762b5e814fe9c9410e`
- recognizer: `9c09abf0957f7968c7586464b7397b84ad2387a0497a351af40e9acc71b673ba`

Android and iOS both execute these graphs with the official ONNX Runtime
1.20.0 CPU runtime. The Android binary is 16 KiB page aligned. iOS 13 is the
minimum supported deployment target.

`characters.json` is generated from the official recognizer `inference.yml`.
Paddle's decoder appends a space class and reserves class zero for CTC blank.
