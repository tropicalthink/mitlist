#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

(cd "$here/../frontend" && EXPORT_RESOLUTION_FEATURES=1 flutter test test/services/resolution_feature_export_test.dart)
python3 "$here/ml/eval/resolution_eval.py" "$@"
