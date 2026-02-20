"""
Tests for python3/chatgpt/utils.py

Tests utility functions including logging, formatting, and history management.
"""

import pytest
import os
import tempfile
from unittest.mock import Mock, MagicMock, patch, mock_open
from datetime import datetime

# Import the module under test
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'python3'))

from chatgpt.utils import (
    debug_log,
    safe_vim_eval,
    save_to_history,
    format_box,
    format_separator,
    format_tool_call,
    format_tool_result,
    format_plan_display
)


class TestDebugLog:
    """Tests for debug_log function"""

    @patch('chatgpt.utils.vim')
    def test_debug_log_disabled(self, mock_vim):
        """Test that debug_log does nothing when logging is disabled"""
        mock_vim.eval.return_value = '0'

        with patch('builtins.open', mock_open()) as mock_file:
            debug_log("Test message")
            mock_file.assert_not_called()

    def test_debug_log_enabled(self):
        """Test that debug_log writes when enabled"""
        # Need to patch vim at the module level since debug_log imports it locally
        import sys
        mock_vim = MagicMock()
        mock_vim.eval.return_value = '2'  # Set log level to 2

        with patch.dict('sys.modules', {'vim': mock_vim}):
            with patch('builtins.open', mock_open()) as mock_file:
                debug_log("WARNING: Test message")

                # Check that open was called with the log file
                mock_file.assert_called_once_with('/tmp/vim-chatgpt-debug.log', 'a')
                # Get the file handle from the context manager
                handle = mock_file()
                # Verify write was called
                handle.write.assert_called()
                # Check the content
                written_content = ''.join(call.args[0] for call in handle.write.call_args_list)
                assert 'WARNING' in written_content
                assert 'Test message' in written_content

    @patch('chatgpt.utils.vim')
    def test_debug_log_with_exception(self, mock_vim):
        """Test that debug_log handles exceptions gracefully"""
        mock_vim.eval.side_effect = Exception("Vim error")

        # Should not raise exception
        debug_log("Test message")


class TestSafeVimEval:
    """Tests for safe_vim_eval function"""

    @patch('chatgpt.utils.vim')
    def test_safe_vim_eval_success(self, mock_vim):
        """Test successful vim eval"""
        mock_vim.eval.return_value = 'test_value'
        result = safe_vim_eval('g:test_var')
        assert result == 'test_value'

    def test_safe_vim_eval_exception(self):
        """Test safe_vim_eval handles vim.error"""
        import sys
        from tests.conftest import VimError

        with patch('chatgpt.utils.vim') as mock_vim:
            mock_vim.error = VimError
            mock_vim.eval.side_effect = VimError("Vim error")
            result = safe_vim_eval('g:test_var')
            assert result is None


class TestSaveToHistory:
    """Tests for save_to_history function"""

    @patch('chatgpt.utils.vim')
    @patch('os.path.exists')
    @patch('os.makedirs')
    @patch('os.getcwd')
    @patch('builtins.open', new_callable=mock_open)
    def test_save_to_history_enabled(self, mock_file, mock_getcwd, mock_makedirs, mock_exists, mock_vim):
        """Test saving to history when enabled"""
        mock_vim.eval.return_value = '1'
        mock_getcwd.return_value = '/test/dir'
        mock_exists.return_value = True  # Directory exists

        save_to_history("Test content")

        mock_file.assert_called_once()

    @patch('chatgpt.utils.vim')
    def test_save_to_history_disabled(self, mock_vim):
        """Test save_to_history does nothing when disabled"""
        mock_vim.eval.return_value = '0'

        with patch('builtins.open', mock_open()) as mock_file:
            save_to_history("Test content")
            mock_file.assert_not_called()


class TestFormatBox:
    """Tests for format_box function"""

    def test_format_box_with_title_only(self):
        """Test formatting box with title only"""
        result = format_box("Test Title", width=40)
        assert "Test Title" in result
        assert "╔" in result
        assert "╚" in result

    def test_format_box_with_title_and_content(self):
        """Test formatting box with title and content"""
        result = format_box("Title", "Content here", width=40)
        assert "Title" in result
        assert "Content here" in result

    def test_format_box_multiline_content(self):
        """Test formatting box with multiline content"""
        result = format_box("Title", "Line 1\nLine 2\nLine 3")
        assert "Line 1" in result
        assert "Line 2" in result
        assert "Line 3" in result


class TestFormatSeparator:
    """Tests for format_separator function"""

    def test_format_separator_default(self):
        """Test default separator"""
        result = format_separator()
        assert len(result) == 60
        assert all(c == "─" for c in result)

    def test_format_separator_custom_char(self):
        """Test custom separator character"""
        result = format_separator(char="=", width=30)
        assert len(result) == 30
        assert all(c == "=" for c in result)


class TestFormatToolCall:
    """Tests for format_tool_call function"""

    def test_format_tool_call_executing(self):
        """Test formatting executing tool call"""
        result = format_tool_call("test_tool", {"arg1": "value1"}, status="executing")
        assert "test_tool" in result
        assert "arg1" in result

    def test_format_tool_call_success(self):
        """Test formatting successful tool call"""
        result = format_tool_call("test_tool", {"arg1": "value1"}, status="success")
        assert "Success" in result
        assert "test_tool" in result

    def test_format_tool_call_error(self):
        """Test formatting error tool call"""
        result = format_tool_call("test_tool", {"arg1": "value1"}, status="error")
        assert "Error" in result
        assert "test_tool" in result

    def test_format_tool_call_long_args(self):
        """Test formatting tool call with long arguments"""
        long_value = "x" * 100
        result = format_tool_call("test_tool", {"arg1": long_value})
        # Should be truncated
        assert len(result) < 200


class TestFormatToolResult:
    """Tests for format_tool_result function"""

    def test_format_tool_result_basic(self):
        """Test basic tool result formatting"""
        result = format_tool_result("test_tool", {"arg1": "val1"}, "Output text")
        assert "test_tool" in result
        assert "Output text" in result
        assert "─" in result

    def test_format_tool_result_multiline(self):
        """Test tool result with multiple lines"""
        output = "\n".join([f"Line {i}" for i in range(5)])
        result = format_tool_result("test_tool", {}, output, max_lines=10)
        assert "Line 0" in result
        assert "Line 4" in result

    def test_format_tool_result_truncation(self):
        """Test tool result truncation"""
        output = "\n".join([f"Line {i}" for i in range(100)])
        result = format_tool_result("test_tool", {}, output, max_lines=5)
        assert "truncated" in result


class TestFormatPlanDisplay:
    """Tests for format_plan_display function"""

    def test_format_plan_display_basic(self):
        """Test basic plan formatting"""
        tool_calls = [
            {"name": "tool1", "arguments": {"arg1": "val1"}},
            {"name": "tool2", "arguments": {"arg2": "val2"}}
        ]
        result = format_plan_display("PLAN", "Test explanation", tool_calls)
        assert "PLAN FOR APPROVAL" in result
        assert "Test explanation" in result
        assert "tool1" in result
        assert "tool2" in result

    def test_format_plan_display_no_explanation(self):
        """Test plan formatting without explanation"""
        tool_calls = [{"name": "tool1", "arguments": {}}]
        result = format_plan_display("PLAN", "", tool_calls)
        assert "PLAN FOR APPROVAL" in result
        assert "tool1" in result

    def test_format_plan_display_multiple_tools(self):
        """Test plan with multiple tools"""
        tool_calls = [
            {"name": f"tool{i}", "arguments": {"arg": f"val{i}"}}
            for i in range(5)
        ]
        result = format_plan_display("REVISED PLAN", "Updating approach", tool_calls)
        assert "REVISED PLAN" in result
        assert "tool0" in result
        assert "tool4" in result
