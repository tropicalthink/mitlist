import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from prepare_ocr_training_dataset import (  # noqa: E402
    choose_validation_writers,
    read_samples,
    write_dataset,
)


class PrepareOcrTrainingDatasetTest(unittest.TestCase):
    def test_split_is_writer_disjoint_and_writes_paddle_labels(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            exports = []
            for writer_index, writer in enumerate(("writer-a", "writer-b")):
                export = root / writer
                crops = export / "crops"
                crops.mkdir(parents=True)
                records = []
                for line_index, label in enumerate(("AB", "BA")):
                    name = f"{line_index}.jpg"
                    (crops / name).write_bytes(
                        bytes((writer_index, line_index, 0xFF, 0xD8))
                    )
                    records.append(
                        json.dumps(
                            {
                                "id": f"{writer}-{line_index}",
                                "writer_id": writer,
                                "image": f"crops/{name}",
                                "label": label,
                                "raw_ocr": label,
                            }
                        )
                    )
                (export / "samples.jsonl").write_text(
                    "\n".join(records) + "\n", encoding="utf-8"
                )
                exports.append(export)

            samples = read_samples(exports)
            validation = choose_validation_writers(samples, 0.5, seed=7)
            output = root / "dataset"
            report = write_dataset(output, samples, validation, ["A", "B"], 7)

            self.assertEqual(report["total_lines"], 4)
            self.assertEqual(report["writer_count"], 2)
            self.assertTrue((output / "train.txt").is_file())
            self.assertTrue((output / "val.txt").is_file())
            audit = [
                json.loads(line)
                for line in (output / "samples.jsonl")
                .read_text(encoding="utf-8")
                .splitlines()
            ]
            train_writers = {
                row["writer_id"] for row in audit if row["split"] == "train"
            }
            validation_writers = {
                row["writer_id"] for row in audit if row["split"] == "val"
            }
            self.assertFalse(train_writers & validation_writers)

    def test_requires_more_than_one_writer_for_validation(self) -> None:
        with self.assertRaisesRegex(ValueError, "two writer IDs"):
            choose_validation_writers(
                [{"writer_id": "only-writer"}], 0.2, seed=1
            )


if __name__ == "__main__":
    unittest.main()
