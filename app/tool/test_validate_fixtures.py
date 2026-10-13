"""validate_fixtures.py 테스트.

app/에서 실행합니다.
    uv run --with jsonschema --with pyyaml --with referencing --with rfc3339-validator python -I tool/test_validate_fixtures.py
"""

import importlib.util
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parent / "validate_fixtures.py"
_spec = importlib.util.spec_from_file_location("validate_fixtures", _SCRIPT)
validate_fixtures = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(validate_fixtures)


def _me_body(**overrides):
    body = {
        "accountId": "0b3f6a9e-6c1d-4f43-9a52-3c1e7d2b8a10",
        "status": "active",
        "consentRequired": False,
        "requiredConsents": [],
        "hasProfile": True,
        "adFree": {"active": False},
        "insight": {"active": False},
    }
    body.update(overrides)
    return {key: value for key, value in body.items() if value is not None}


class ValidateFixtureTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = validate_fixtures.Contract.load()

    def check(self, operation_id, fixture):
        return validate_fixtures.validate_fixture(self.contract, operation_id, fixture)

    def test_valid_me_passes(self):
        self.assertEqual(self.check("getMe", {"status": 200, "body": _me_body()}), [])

    def test_missing_required_field_fails_with_field_name(self):
        errors = self.check(
            "getMe", {"status": 200, "body": _me_body(hasProfile=None)}
        )
        self.assertEqual(len(errors), 1)
        self.assertIn("hasProfile", errors[0])
        self.assertTrue(errors[0].startswith("/body"))

    def test_nested_error_reports_json_pointer(self):
        errors = self.check(
            "getMe",
            {"status": 200, "body": _me_body(adFree={"active": "yes"})},
        )
        self.assertEqual(len(errors), 1)
        self.assertTrue(errors[0].startswith("/body/adFree/active:"), errors[0])

    def test_problem_response_uses_default_content_type(self):
        problem = {
            "type": "https://api.myungli.app/problems/auth.token_invalid",
            "title": "Invalid token",
            "status": 401,
            "code": "auth.token_invalid",
            "traceId": "t",
        }
        self.assertEqual(self.check("getMe", {"status": 401, "body": problem}), [])
        del problem["traceId"]
        errors = self.check("getMe", {"status": 401, "body": problem})
        self.assertIn("traceId", errors[0])

    def test_unlisted_status_falls_back_to_default(self):
        problem = {
            "type": "https://api.myungli.app/problems/not_implemented",
            "title": "Not implemented",
            "status": 501,
            "code": "not_implemented",
            "traceId": "t",
        }
        self.assertEqual(self.check("getMe", {"status": 501, "body": problem}), [])

    def test_wrong_media_type_fails(self):
        errors = self.check(
            "getMe",
            {
                "status": 200,
                "headers": {"Content-Type": "application/problem+json"},
                "body": _me_body(),
            },
        )
        self.assertIn("content-type", errors[0])

    def test_date_time_format_is_checked(self):
        errors = self.check(
            "getMe",
            {
                "status": 200,
                "body": _me_body(status="pending_deletion", deletionScheduledAt="내일"),
            },
        )
        self.assertEqual(len(errors), 1)
        self.assertIn("/body/deletionScheduledAt", errors[0])

    def test_sequence_validates_every_response(self):
        problem = {
            "type": "https://api.myungli.app/problems/auth.token_expired",
            "title": "Expired",
            "status": 401,
            "code": "auth.token_expired",
            "traceId": "t",
        }
        good = {"sequence": [{"status": 401, "body": problem}, {"status": 200, "body": _me_body()}]}
        self.assertEqual(self.check("getMe", good), [])
        bad = {"sequence": [{"status": 401, "body": problem}, {"status": 200, "body": _me_body(hasProfile=None)}]}
        errors = self.check("getMe", bad)
        self.assertEqual(len(errors), 1)
        self.assertTrue(errors[0].startswith("/sequence/1/body"), errors[0])
        self.assertIn("hasProfile", errors[0])

    def test_sequence_must_be_a_non_empty_array_alone(self):
        self.assertNotEqual(self.check("getMe", {"sequence": []}), [])
        self.assertNotEqual(
            self.check("getMe", {"sequence": [{"status": 200}], "status": 200}), []
        )

    def test_unknown_operation_fails(self):
        errors = self.check("noSuchOperation", {"status": 200, "body": {}})
        self.assertIn("noSuchOperation", errors[0])


class FileNameTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = validate_fixtures.Contract.load()

    def names(self, name):
        return validate_fixtures.check_file_name(self.contract, Path(name))

    def test_matching_parameter_values_pass(self):
        self.assertEqual(self.names("getCalendar__2026-10.json"), [])
        self.assertEqual(self.names("getDaily__2026-10-13.json"), [])
        self.assertEqual(self.names("getMe.json"), [])

    def test_wrong_piece_count_or_value_fails(self):
        self.assertNotEqual(self.names("getCalendar__2026.json"), [])
        self.assertNotEqual(self.names("getCalendar__2026-10-13.json"), [])
        self.assertNotEqual(self.names("getCalendar__2026-13.json"), [])
        self.assertNotEqual(self.names("getDaily__2026-10.json"), [])

    def test_parameters_on_operation_without_path_parameters_fail(self):
        self.assertNotEqual(self.names("getMe__2026.json"), [])


class ValidateAllTest(unittest.TestCase):
    def test_committed_fixtures_pass(self):
        contract = validate_fixtures.Contract.load()
        count, failures = validate_fixtures.validate_all(contract)
        self.assertEqual(failures, [])
        self.assertGreater(count, 0)


if __name__ == "__main__":
    unittest.main()
