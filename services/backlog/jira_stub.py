"""A minimal JIRA stub for testing integration.

This module simulates creating issues and returning an ID.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Optional


@dataclass
class JiraIssue:
    id: str
    key: str
    summary: str


class JiraStub:
    def __init__(self):
        self._counter = 0
        self._issues: Dict[str, JiraIssue] = {}

    def create_issue(self, summary: str, description: Optional[str] = None) -> JiraIssue:
        self._counter += 1
        key = f"JIRA-{self._counter}"
        issue = JiraIssue(id=str(self._counter), key=key, summary=summary)
        self._issues[key] = issue
        return issue

    def get_issue(self, key: str) -> Optional[JiraIssue]:
        return self._issues.get(key)
