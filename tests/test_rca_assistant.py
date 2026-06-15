from pathlib import Path
import unittest

from src.rca_assistant.assistant import RCAAssistant
from src.rca_assistant.classifier import classify_issue


class ClassifierTests(unittest.TestCase):
    def test_low_count_wins_over_facility_context(self):
        result = classify_issue("CT study count is low for yesterday at facility SITE_A")
        self.assertEqual(result.issue_type, "missing_or_low_count")

    def test_stale_dashboard_classification(self):
        result = classify_issue("The dashboard is stale and the daily trend did not refresh")
        self.assertEqual(result.issue_type, "stale_dashboard")


class AssistantTests(unittest.TestCase):
    def test_assistant_returns_lineage_and_sources(self):
        assistant = RCAAssistant.from_default_paths(Path("."))
        response = assistant.answer("Files failed parsing and dashboard count is low")

        self.assertIn("Likely pipeline path", response.answer)
        self.assertIn("Starter SQL checks", response.answer)
        self.assertGreater(len(response.sources), 0)


if __name__ == "__main__":
    unittest.main()
