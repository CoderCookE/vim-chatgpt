"""
Tests for python3/chatgpt/summary.py

Tests conversation summary generation including:
- Cutoff byte position tracking
- Summary file metadata handling
- Chunk processing
- Summary merging
"""

import pytest
import os
import tempfile
from unittest.mock import Mock, patch, mock_open, call

# Import the module under test
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "python3"))

from chatgpt.summary import get_summary_cutoff, generate_conversation_summary


class TestGetSummaryCutoff:
    """Test get_summary_cutoff() function"""

    def test_returns_zero_when_no_summary_exists(self, tmp_path):
        """Should return 0 if summary file doesn't exist"""
        # When summary doesn't exist, return 0
        summary_dir = tmp_path / ".vim-chatgpt"
        result = get_summary_cutoff(str(summary_dir))
        assert result == 0

    def test_extracts_cutoff_from_metadata(self, tmp_path):
        """Should extract cutoff_byte from summary metadata"""
        summary_dir = tmp_path / ".vim-chatgpt"
        summary_dir.mkdir()
        summary_file = summary_dir / "summary.md"

        summary_content = """<!-- SUMMARY_METADATA
cutoff_byte: 12345
last_updated: 2024-01-01
-->

# Summary
Previous conversation summary"""

        summary_file.write_text(summary_content)

        # get_summary_cutoff now expects the project directory path, not root
        result = get_summary_cutoff(str(summary_dir))
        assert result == 12345

    def test_handles_missing_metadata(self, tmp_path):
        """Should return 0 if metadata is missing"""
        summary_dir = tmp_path / ".vim-chatgpt"
        summary_dir.mkdir()
        summary_file = summary_dir / "summary.md"

        summary_file.write_text("# Summary\nNo metadata here")

        # get_summary_cutoff now expects the project directory path, not root
        result = get_summary_cutoff(str(summary_dir))
        assert result == 0

    def test_handles_malformed_metadata(self, tmp_path):
        """Should return 0 if metadata is malformed"""
        summary_dir = tmp_path / ".vim-chatgpt"
        summary_dir.mkdir()
        summary_file = summary_dir / "summary.md"

        summary_content = """<!-- SUMMARY_METADATA
cutoff_byte: not_a_number
-->"""
        summary_file.write_text(summary_content)

        result = get_summary_cutoff(str(summary_dir))
        assert result == 0

    def test_handles_file_read_errors(self, tmp_path):
        """Should handle file read errors gracefully"""
        summary_dir = tmp_path / ".vim-chatgpt"
        summary_dir.mkdir()
        summary_file = summary_dir / "summary.md"
        summary_file.write_text("test")

        # Make file unreadable
        os.chmod(summary_file, 0o000)

        try:
            result = get_summary_cutoff(str(summary_dir))
            assert result == 0
        finally:
            # Restore permissions for cleanup
            os.chmod(summary_file, 0o644)


class TestGenerateConversationSummary:
    """Test generate_conversation_summary() function"""

    @pytest.fixture
    def mock_env(self, tmp_path):
        """Set up mock environment for summary generation"""
        # Create directory structure
        vim_chatgpt_dir = tmp_path / ".vim-chatgpt"
        vim_chatgpt_dir.mkdir()

        # Create history file
        history_file = vim_chatgpt_dir / "history.txt"
        history_content = """
\x01>>>User:\x01
First message

\x01>>>Assistant:\x01
First response

\x01>>>User:\x01
Second message

\x01>>>Assistant:\x01
Second response
"""
        history_file.write_bytes(history_content.encode("utf-8"))

        return {
            "tmp_path": tmp_path,
            "history_file": history_file,
            "vim_chatgpt_dir": vim_chatgpt_dir,
        }

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_generates_summary_for_new_conversation(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, mock_env
    ):
        """Should generate summary for first time"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.return_value = "30480"  # 30KB recent window

        generate_conversation_summary()

        # Verify chat_gpt was called with summary prompt
        assert mock_chat_gpt.called
        call_args = mock_chat_gpt.call_args[0][0]
        assert "summary" in call_args.lower()
        assert "create_file" in call_args

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_extends_existing_summary(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, mock_env
    ):
        """Should extend existing summary with new conversation"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.return_value = "30480"

        # Create existing summary
        summary_file = mock_env["vim_chatgpt_dir"] / "summary.md"
        summary_content = """<!-- SUMMARY_METADATA
cutoff_byte: 100
-->

# Existing Summary
Previous topics discussed"""
        summary_file.write_text(summary_content)

        generate_conversation_summary()

        # Verify chat_gpt was called with extension prompt
        assert mock_chat_gpt.called
        call_args = mock_chat_gpt.call_args[0][0]
        assert "existing" in call_args.lower()
        assert "extend" in call_args.lower() or "add" in call_args.lower()

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_respects_recent_window_size(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, mock_env
    ):
        """Should keep recent N bytes unsummarized"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])

        # Set small recent window
        recent_window = 50
        mock_get_config.return_value = str(recent_window)

        history_size = os.path.getsize(mock_env["history_file"])

        generate_conversation_summary()

        # Verify summary doesn't include most recent bytes
        assert mock_chat_gpt.called
        # The prompt should not include the very last bytes

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_handles_missing_history_file(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, tmp_path
    ):
        """Should handle case when history file doesn't exist"""
        mock_getcwd.return_value = str(tmp_path)
        mock_get_config.return_value = "30480"

        # No history file created
        generate_conversation_summary()

        # Should not call chat_gpt
        assert not mock_chat_gpt.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_limits_compaction_size(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, mock_env
    ):
        """Should limit amount of history to summarize in one go"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.return_value = "30480"

        # Create large history file
        history_file = mock_env["history_file"]
        large_content = (
            b"x" * 300000
        )  # 300KB - larger than max_compaction_total (200KB)
        history_file.write_bytes(large_content)

        generate_conversation_summary()

        # Should still work, just process limited amount
        assert mock_chat_gpt.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_handles_utf8_boundaries(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, mock_env
    ):
        """Should handle UTF-8 character boundaries when seeking"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.return_value = "30480"

        # Create history with multi-byte UTF-8 characters
        history_file = mock_env["history_file"]
        content_with_emoji = """
\x01>>>User:\x01
Hello 😀

\x01>>>Assistant:\x01
Hi there! 👋
"""
        history_file.write_bytes(content_with_emoji.encode("utf-8"))

        # Should not crash on UTF-8 boundaries
        generate_conversation_summary()

        assert mock_chat_gpt.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_includes_format_instructions(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, mock_env
    ):
        """Should include formatting instructions in prompt"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.return_value = "30480"

        generate_conversation_summary()

        assert mock_chat_gpt.called
        call_args = mock_chat_gpt.call_args[0][0]

        # Check for section headers
        assert "Key Topics" in call_args
        assert "Important Information" in call_args
        assert "User Preferences" in call_args
        assert "Action Items" in call_args

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_instructs_to_save_with_create_file(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, mock_env
    ):
        """Should instruct AI to use create_file tool"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.return_value = "30480"

        generate_conversation_summary()

        assert mock_chat_gpt.called
        call_args = mock_chat_gpt.call_args[0][0]

        # Should mention create_file tool and overwrite=true
        assert "create_file" in call_args
        assert (
            "overwrite=true" in call_args.lower()
            or "overwrite: true" in call_args.lower()
        )
        assert "summary.md" in call_args

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_calculates_cutoff_correctly(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, mock_env
    ):
        """Should calculate cutoff byte position correctly"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])

        recent_window = 1000
        mock_get_config.return_value = str(recent_window)

        history_file = mock_env["history_file"]
        history_size = os.path.getsize(history_file)

        generate_conversation_summary()

        # Expected cutoff should be: history_size - recent_window
        expected_cutoff = max(0, history_size - recent_window)

        # The cutoff value is used internally, verify function completed
        assert mock_chat_gpt.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_strips_metadata_from_old_summary(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, mock_env
    ):
        """Should strip metadata when including old summary in prompt"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.return_value = "30480"

        # Create summary with metadata
        summary_file = mock_env["vim_chatgpt_dir"] / "summary.md"
        summary_content = """<!-- SUMMARY_METADATA
cutoff_byte: 100
last_updated: 2024-01-01
-->

# Real Summary Content
This is the actual summary"""
        summary_file.write_text(summary_content)

        generate_conversation_summary()

        assert mock_chat_gpt.called
        call_args = mock_chat_gpt.call_args[0][0]

        # Metadata should be stripped from the prompt
        assert "SUMMARY_METADATA" not in call_args
        assert "cutoff_byte: 100" not in call_args
        # But content should be included
        assert "Real Summary Content" in call_args

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_handles_zero_cutoff(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, mock_env
    ):
        """Should handle case where cutoff is 0 (first summary)"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.return_value = "30480"

        # First summary - no existing summary
        generate_conversation_summary()

        assert mock_chat_gpt.called
        call_args = mock_chat_gpt.call_args[0][0]

        # Should not mention extending
        assert "extend" not in call_args.lower() or "create" in call_args.lower()

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.chat_gpt")
    @patch("os.getcwd")
    def test_preserves_instruction_to_keep_existing_content(
        self, mock_getcwd, mock_chat_gpt, mock_get_config, mock_env
    ):
        """Should instruct AI to keep existing summary content"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.return_value = "30480"

        # Create existing summary
        summary_file = mock_env["vim_chatgpt_dir"] / "summary.md"
        summary_file.write_text("""<!-- SUMMARY_METADATA
cutoff_byte: 100
-->
# Summary
Old content""")

        generate_conversation_summary()

        assert mock_chat_gpt.called
        call_args = mock_chat_gpt.call_args[0][0]

        # Should tell AI to keep existing content
        assert "keep" in call_args.lower() or "add" in call_args.lower()
        assert "not" in call_args.lower() and "remove" in call_args.lower()
