"""validate_fixtures.py 테스트.

app/에서 실행합니다.
    uv run --with jsonschema --with pyyaml --with referencing python -I tool/test_validate_fixtures.py
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

    def test_unknown_operation_fails(self):
        errors = self.check("noSuchOperation", {"status": 200, "body": {}})
        self.assertIn("noSuchOperation", errors[0])


class ValidateAllTest(unittest.TestCase):
    def test_committed_fixtures_pass(self):
        contract = validate_fixtures.Contract.load()
        count, failures = validate_fixtures.validate_all(contract)
        self.assertEqual(failures, [])
        self.assertGreater(count, 0)


if __name__ == "__main__":
    unittest.main()
