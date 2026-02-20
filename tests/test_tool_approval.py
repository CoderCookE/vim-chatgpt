"""
Tests for tool approval system in python3/chatgpt/tools.py

Tests the tool approval prompting and session-based permission management.
"""

import pytest
import os
from unittest.mock import Mock, patch, MagicMock

# Import the module under test
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "python3"))

from chatgpt.tools import (
    execute_tool,
    check_tool_approval,
    clear_tool_approvals,
    get_approved_tools,
)


class TestToolApproval:
    """Test tool approval system"""

    def setup_method(self):
        """Clear approvals before each test"""
        clear_tool_approvals()

    @patch("chatgpt.tools.vim")
    @patch("chatgpt.tools.safe_vim_eval")
    def test_approval_disabled_by_default(self, mock_safe_eval, mock_vim):
        """When approval is disabled (default), tools execute without prompting"""
        mock_safe_eval.return_value = "0"  # Disabled

        # Tool should execute without prompting
        result = execute_tool("get_working_directory", {})

        # Should not have called vim.eval for confirmation
        assert not any("confirm" in str(call) for call in mock_vim.eval.call_args_list)
        assert "Current working directory:" in result

    @patch("chatgpt.tools.vim")
    @patch("chatgpt.tools.safe_vim_eval")
    def test_approval_allow_once(self, mock_safe_eval, mock_vim):
        """Test 'Allow Once' option - tool executes but not cached"""
        mock_safe_eval.return_value = "1"  # Approval enabled
        mock_vim.eval.return_value = "1"  # User selects "Allow Once"

        # First execution - should prompt
        is_approved, msg = check_tool_approval("test_tool", {"arg": "value"})
        assert is_approved is True
        assert msg is None

        # Tool should not be in approved list
        approved = get_approved_tools()
        assert "test_tool" not in approved

        # Verify confirm was called
        confirm_calls = [c for c in mock_vim.eval.call_args_list if "confirm" in str(c)]
        assert len(confirm_calls) > 0

    @patch("chatgpt.tools.vim")
    @patch("chatgpt.tools.safe_vim_eval")
    def test_approval_always_allow(self, mock_safe_eval, mock_vim):
        """Test 'Always Allow' option - tool is cached for session"""
        mock_safe_eval.return_value = "1"  # Approval enabled
        mock_vim.eval.return_value = "2"  # User selects "Always Allow"

        # First execution - should prompt
        is_approved, msg = check_tool_approval("test_tool", {"arg": "value"})
        assert is_approved is True
        assert msg is None

        # Tool should be in approved list
        approved = get_approved_tools()
        assert "test_tool" in approved
        assert approved["test_tool"] == "always"

        # Second execution - should NOT prompt (cached)
        mock_vim.eval.reset_mock()
        is_approved, msg = check_tool_approval("test_tool", {"arg": "value"})
        assert is_approved is True

        # Verify confirm was NOT called again
        confirm_calls = [c for c in mock_vim.eval.call_args_list if "confirm" in str(c)]
        assert len(confirm_calls) == 0

    @patch("chatgpt.tools.vim")
    @patch("chatgpt.tools.safe_vim_eval")
    def test_approval_deny(self, mock_safe_eval, mock_vim):
        """Test 'Deny' option - tool is blocked and cached"""
        mock_safe_eval.return_value = "1"  # Approval enabled
        mock_vim.eval.return_value = "3"  # User selects "Deny"

        # First execution - should prompt and deny
        is_approved, msg = check_tool_approval("test_tool", {"arg": "value"})
        assert is_approved is False
        assert "denied by user" in msg

        # Tool should be in approved list as denied
        approved = get_approved_tools()
        assert "test_tool" in approved
        assert approved["test_tool"] == "denied"

        # Second execution - should NOT prompt, automatically denied
        mock_vim.eval.reset_mock()
        is_approved, msg = check_tool_approval("test_tool", {"arg": "value"})
        assert is_approved is False

        # Verify confirm was NOT called again
        confirm_calls = [c for c in mock_vim.eval.call_args_list if "confirm" in str(c)]
        assert len(confirm_calls) == 0

    @patch("chatgpt.tools.vim")
    @patch("chatgpt.tools.safe_vim_eval")
    def test_execute_tool_with_approval_enabled(self, mock_safe_eval, mock_vim):
        """Test full execute_tool flow with approval enabled"""
        mock_safe_eval.return_value = "1"  # Approval enabled
        mock_vim.eval.return_value = "2"  # User selects "Always Allow"

        # Execute tool - should prompt and succeed
        result = execute_tool("get_working_directory", {})

        # Should have executed successfully
        assert "Current working directory:" in result

        # Should have prompted for approval
        confirm_calls = [c for c in mock_vim.eval.call_args_list if "confirm" in str(c)]
        assert len(confirm_calls) > 0

    @patch("chatgpt.tools.vim")
    @patch("chatgpt.tools.safe_vim_eval")
    def test_execute_tool_denied(self, mock_safe_eval, mock_vim):
        """Test tool execution when denied"""
        mock_safe_eval.return_value = "1"  # Approval enabled
        mock_vim.eval.return_value = "3"  # User selects "Deny"

        # Execute tool - should be blocked
        result = execute_tool("get_working_directory", {})

        # Should be blocked
        assert "Tool execution blocked" in result
        assert "denied by user" in result

    def test_clear_approvals(self):
        """Test clearing all approvals"""
        # Manually add some approvals
        import chatgpt.tools

        chatgpt.tools._approved_tools["tool1"] = "always"
        chatgpt.tools._approved_tools["tool2"] = "denied"

        # Clear them
        clear_tool_approvals()

        # Should be empty
        approved = get_approved_tools()
        assert len(approved) == 0

    @patch("chatgpt.tools.vim")
    @patch("chatgpt.tools.safe_vim_eval")
    def test_approval_different_tools_independent(self, mock_safe_eval, mock_vim):
        """Test that different tools have independent approval states"""
        mock_safe_eval.return_value = "1"  # Approval enabled

        # Approve tool1
        mock_vim.eval.return_value = "2"  # Always Allow
        check_tool_approval("tool1", {})

        # Deny tool2
        mock_vim.eval.return_value = "3"  # Deny
        check_tool_approval("tool2", {})

        # Check states
        approved = get_approved_tools()
        assert approved["tool1"] == "always"
        assert approved["tool2"] == "denied"

    @patch("chatgpt.tools.vim")
    @patch("chatgpt.tools.safe_vim_eval")
    def test_approval_prompt_includes_arguments(self, mock_safe_eval, mock_vim):
        """Test that approval prompt shows tool arguments"""
        mock_safe_eval.return_value = "1"  # Approval enabled
        mock_vim.eval.return_value = "2"  # Always Allow

        # Execute with specific arguments
        check_tool_approval(
            "read_file", {"file_path": "/tmp/test.txt", "max_lines": 100}
        )

        # Check that confirm was called with arguments in the message
        confirm_calls = [c for c in mock_vim.eval.call_args_list if "confirm" in str(c)]
        assert len(confirm_calls) > 0

        # The call should contain the tool name and arguments
        call_str = str(confirm_calls[0])
        assert "read_file" in call_str
        assert "file_path" in call_str or "Arguments" in call_str


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
