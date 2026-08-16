"""Dependency-free packaging and metadata contract checks."""

from __future__ import annotations

import ast
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]
INTEGRATION = ROOT / "custom_components" / "mitlist"


class IntegrationContractTest(unittest.TestCase):
    def test_python_sources_compile(self) -> None:
        for path in INTEGRATION.glob("*.py"):
            with self.subTest(path=path.name):
                ast.parse(path.read_text(), filename=str(path))

    def test_manifest_platforms_have_modules(self) -> None:
        const_tree = ast.parse((INTEGRATION / "const.py").read_text())
        platforms: tuple[str, ...] = ()
        for node in const_tree.body:
            if isinstance(node, ast.Assign) and any(
                isinstance(target, ast.Name) and target.id == "PLATFORMS"
                for target in node.targets
            ):
                platforms = ast.literal_eval(node.value)
        self.assertTrue(platforms)
        for platform in platforms:
            self.assertTrue((INTEGRATION / f"{platform}.py").is_file(), platform)

    def test_registered_services_are_documented(self) -> None:
        const_tree = ast.parse((INTEGRATION / "const.py").read_text())
        registered: set[str] = set()
        for node in const_tree.body:
            if not isinstance(node, ast.Assign) or not isinstance(
                node.value, ast.Constant
            ):
                continue
            if any(
                isinstance(target, ast.Name) and target.id.startswith("SERVICE_")
                for target in node.targets
            ):
                registered.add(str(node.value.value))
        documented = set(
            re.findall(
                r"^([a-z][a-z0-9_]+):$",
                (INTEGRATION / "services.yaml").read_text(),
                flags=re.MULTILINE,
            )
        )
        self.assertEqual(registered, documented)

    def test_english_translation_matches_source_strings(self) -> None:
        strings = json.loads((INTEGRATION / "strings.json").read_text())
        translation = json.loads((INTEGRATION / "translations" / "en.json").read_text())
        self.assertEqual(strings, translation)


if __name__ == "__main__":
    unittest.main()
