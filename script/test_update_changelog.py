import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import update_changelog


def release(tag, **overrides):
    result = dict(
        tag_name=tag, draft=False, prerelease=False,
        published_at="2026-11-21T12:00:00Z",
        html_url=f"https://github.com/example/app/releases/tag/{tag}",
    )
    result.update(overrides)
    return result


class ChangelogTests(unittest.TestCase):
    def test_new_tag_uses_previous_stable_version_in_numeric_order(self):
        releases = [release("v1.0.10"), release("v1.0.9")]
        draft = release("v1.0.12")
        draft["draft"] = True
        prerelease = release("v2.0.0")
        prerelease["prerelease"] = True
        releases += [draft, prerelease]
        with patch.object(update_changelog, "github_api", return_value={"body": "Notes"}) as api:
            changelog, notes = update_changelog.generate("example/app", releases, "v1.0.11")
        self.assertEqual(
            [call.args[2] for call in api.call_args_list],
            [{"tag_name": "v1.0.9"},
             {"tag_name": "v1.0.10", "previous_tag_name": "v1.0.9"},
             {"tag_name": "v1.0.11", "previous_tag_name": "v1.0.10"}],
        )
        self.assertEqual(len(notes), 3)
        self.assertLess(changelog.index("## [v1.0.11]"), changelog.index("## [v1.0.10]"))

    def test_rerun_preserves_published_date_and_pr_author_links(self):
        body = "## What's Changed\n* Fix by @alice in https://github.com/example/app/pull/7"
        published = release("v1.0.11", published_at="2026-09-06T12:00:00Z")
        with patch.object(update_changelog, "github_api", return_value={"body": body}):
            first, notes = update_changelog.generate("example/app", [published], "v1.0.11")
            second, _ = update_changelog.generate("example/app", [published], "v1.0.11")
        self.assertEqual(first, second)
        self.assertIn("— 2026-09-06", first)
        self.assertIn("### What's Changed", first)
        self.assertIn("by @alice in https://github.com/example/app/pull/7", first)
        self.assertEqual(notes["v1.0.11"], body)

    def test_api_failure_does_not_replace_existing_changelog(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "CHANGELOG.md"
            output.write_text("Existing changelog", encoding="utf-8")
            args = ["update_changelog.py", "--repository", "example/app", "--output", str(output)]
            failure = subprocess.CalledProcessError(1, "gh", stderr="API unavailable")
            with patch.object(sys, "argv", args), patch.object(
                update_changelog, "github_api", side_effect=[[[release("v1.0.11")]], failure]
            ):
                with self.assertRaises(subprocess.CalledProcessError):
                    update_changelog.main()
            self.assertEqual(output.read_text(encoding="utf-8"), "Existing changelog")

    def test_release_without_prs_includes_commit_and_author(self):
        commit = {
            "parents": [{}], "author": {"login": "alice"},
            "commit": {"message": "Fix startup\n\nDetails", "author": {"name": "Alice"}},
            "html_url": "https://github.com/example/app/commit/abc",
        }
        with patch.object(update_changelog, "github_api", side_effect=[
            {"body": "**Full Changelog**: https://github.com/example/app/commits/v1.0.0"},
            [[commit]],
        ]):
            changelog, _ = update_changelog.generate("example/app", [release("v1.0.0")])
        self.assertIn("Fix startup by @alice in https://github.com/example/app/commit/abc", changelog)


if __name__ == "__main__":
    unittest.main()
