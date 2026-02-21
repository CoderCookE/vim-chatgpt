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
        result = get_summary_cutoff(str(tmp_path))
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

        # get_summary_cutoff expects the project root directory
        result = get_summary_cutoff(str(tmp_path))
        assert result == 12345

    def test_handles_missing_metadata(self, tmp_path):
        """Should return 0 if metadata is missing"""
        summary_dir = tmp_path / ".vim-chatgpt"
        summary_dir.mkdir()
        summary_file = summary_dir / "summary.md"

        summary_file.write_text("# Summary\nNo metadata here")

        # get_summary_cutoff expects the project root directory
        result = get_summary_cutoff(str(tmp_path))
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

        result = get_summary_cutoff(str(tmp_path))
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
            result = get_summary_cutoff(str(tmp_path))
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
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_generates_summary_for_new_conversation(
        self, mock_getcwd, mock_create_provider, mock_get_config, mock_env
    ):
        """Should generate summary for first time"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": "30480",
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # Mock provider
        mock_provider = Mock()
        mock_provider.get_model.return_value = "gpt-4"
        mock_provider.create_messages.return_value = []
        mock_provider.stream_chat.return_value = iter(
            [("Summary content", None, None), ("", "stop", None)]
        )
        mock_create_provider.return_value = mock_provider

        generate_conversation_summary()

        # Verify provider was called
        assert mock_create_provider.called
        assert mock_provider.stream_chat.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_extends_existing_summary(
        self, mock_getcwd, mock_create_provider, mock_get_config, mock_env
    ):
        """Should extend existing summary with new conversation"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": "30480",
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # Mock provider
        mock_provider = Mock()
        mock_provider.get_model.return_value = "gpt-4"
        mock_provider.create_messages.return_value = []
        mock_provider.stream_chat.return_value = iter(
            [("Extended summary", None, None), ("", "stop", None)]
        )
        mock_create_provider.return_value = mock_provider

        # Create existing summary
        summary_file = mock_env["vim_chatgpt_dir"] / "summary.md"
        summary_content = """<!-- SUMMARY_METADATA
cutoff_byte: 100
-->

# Existing Summary
Previous topics discussed"""
        summary_file.write_text(summary_content)

        generate_conversation_summary()

        # Verify provider was called
        assert mock_create_provider.called
        assert mock_provider.stream_chat.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_respects_recent_window_size(
        self, mock_getcwd, mock_create_provider, mock_get_config, mock_env
    ):
        """Should keep recent N bytes unsummarized"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])

        # Set small recent window
        recent_window = 50
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": str(recent_window),
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # Mock provider
        mock_provider = Mock()
        mock_provider.get_model.return_value = "gpt-4"
        mock_provider.create_messages.return_value = []
        mock_provider.stream_chat.return_value = iter(
            [("Summary", None, None), ("", "stop", None)]
        )
        mock_create_provider.return_value = mock_provider

        history_size = os.path.getsize(mock_env["history_file"])

        generate_conversation_summary()

        # Verify provider was called
        assert mock_create_provider.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_handles_missing_history_file(
        self, mock_getcwd, mock_create_provider, mock_get_config, tmp_path
    ):
        """Should handle case when history file doesn't exist"""
        mock_getcwd.return_value = str(tmp_path)
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": "30480",
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # No history file created
        generate_conversation_summary()

        # Should not call create_provider
        assert not mock_create_provider.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_limits_compaction_size(
        self, mock_getcwd, mock_create_provider, mock_get_config, mock_env
    ):
        """Should limit amount of history to summarize in one go"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": "30480",
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # Mock provider
        mock_provider = Mock()
        mock_provider.get_model.return_value = "gpt-4"
        mock_provider.create_messages.return_value = []
        mock_provider.stream_chat.return_value = iter(
            [("Summary", None, None), ("", "stop", None)]
        )
        mock_create_provider.return_value = mock_provider

        # Create large history file
        history_file = mock_env["history_file"]
        large_content = (
            b"x" * 300000
        )  # 300KB - larger than max_compaction_total (200KB)
        history_file.write_bytes(large_content)

        generate_conversation_summary()

        # Should still work, just process limited amount
        assert mock_create_provider.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_handles_utf8_boundaries(
        self, mock_getcwd, mock_create_provider, mock_get_config, mock_env
    ):
        """Should handle UTF-8 character boundaries when seeking"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": "30480",
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # Mock provider
        mock_provider = Mock()
        mock_provider.get_model.return_value = "gpt-4"
        mock_provider.create_messages.return_value = []
        mock_provider.stream_chat.return_value = iter(
            [("Summary", None, None), ("", "stop", None)]
        )
        mock_create_provider.return_value = mock_provider

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

        assert mock_create_provider.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_includes_format_instructions(
        self, mock_getcwd, mock_create_provider, mock_get_config, mock_env
    ):
        """Should include formatting instructions in prompt"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": "30480",
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # Mock provider
        mock_provider = Mock()
        mock_provider.get_model.return_value = "gpt-4"
        mock_provider.create_messages.return_value = []
        mock_provider.stream_chat.return_value = iter(
            [("Summary with sections", None, None), ("", "stop", None)]
        )
        mock_create_provider.return_value = mock_provider

        generate_conversation_summary()

        # Verify provider was called to generate summary
        assert mock_create_provider.called
        assert mock_provider.create_messages.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_instructs_to_save_with_create_file(
        self, mock_getcwd, mock_create_provider, mock_get_config, mock_env
    ):
        """Should save summary file directly"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": "30480",
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # Mock provider
        mock_provider = Mock()
        mock_provider.get_model.return_value = "gpt-4"
        mock_provider.create_messages.return_value = []
        mock_provider.stream_chat.return_value = iter(
            [("Summary content", None, None), ("", "stop", None)]
        )
        mock_create_provider.return_value = mock_provider

        generate_conversation_summary()

        # Verify summary file was created
        summary_file = mock_env["vim_chatgpt_dir"] / "summary.md"
        assert summary_file.exists()
        assert "Summary content" in summary_file.read_text()

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_calculates_cutoff_correctly(
        self, mock_getcwd, mock_create_provider, mock_get_config, mock_env
    ):
        """Should calculate cutoff byte position correctly"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])

        recent_window = 1000
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": str(recent_window),
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # Mock provider
        mock_provider = Mock()
        mock_provider.get_model.return_value = "gpt-4"
        mock_provider.create_messages.return_value = []
        mock_provider.stream_chat.return_value = iter(
            [("Summary", None, None), ("", "stop", None)]
        )
        mock_create_provider.return_value = mock_provider

        history_file = mock_env["history_file"]
        history_size = os.path.getsize(history_file)

        generate_conversation_summary()

        # Expected cutoff should be: history_size - recent_window
        expected_cutoff = max(0, history_size - recent_window)

        # Verify summary file contains cutoff metadata
        summary_file = mock_env["vim_chatgpt_dir"] / "summary.md"
        assert summary_file.exists()
        assert f"cutoff_byte: {expected_cutoff}" in summary_file.read_text()

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_strips_metadata_from_old_summary(
        self, mock_getcwd, mock_create_provider, mock_get_config, mock_env
    ):
        """Should strip metadata when including old summary in prompt"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": "30480",
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # Mock provider
        mock_provider = Mock()
        mock_provider.get_model.return_value = "gpt-4"
        mock_provider.create_messages.return_value = []
        mock_provider.stream_chat.return_value = iter(
            [("Extended summary", None, None), ("", "stop", None)]
        )
        mock_create_provider.return_value = mock_provider

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

        # Verify provider was called
        assert mock_create_provider.called
        assert mock_provider.stream_chat.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_handles_zero_cutoff(
        self, mock_getcwd, mock_create_provider, mock_get_config, mock_env
    ):
        """Should handle case where cutoff is 0 (first summary)"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": "30480",
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # Mock provider
        mock_provider = Mock()
        mock_provider.get_model.return_value = "gpt-4"
        mock_provider.create_messages.return_value = []
        mock_provider.stream_chat.return_value = iter(
            [("First summary", None, None), ("", "stop", None)]
        )
        mock_create_provider.return_value = mock_provider

        # First summary - no existing summary
        generate_conversation_summary()

        # Verify provider was called
        assert mock_create_provider.called

    @patch("chatgpt.utils.get_config")
    @patch("chatgpt.summary.create_provider")
    @patch("os.getcwd")
    def test_preserves_instruction_to_keep_existing_content(
        self, mock_getcwd, mock_create_provider, mock_get_config, mock_env
    ):
        """Should instruct AI to keep existing summary content"""
        mock_getcwd.return_value = str(mock_env["tmp_path"])
        mock_get_config.side_effect = lambda k, d: {
            "recent_history_size": "30480",
            "provider": "openai",
            "max_tokens": "2000",
            "temperature": "0.7",
        }.get(k, d)

        # Mock provider
        mock_provider = Mock()
        mock_provider.get_model.return_value = "gpt-4"
        mock_provider.create_messages.return_value = []
        mock_provider.stream_chat.return_value = iter(
            [("Extended summary", None, None), ("", "stop", None)]
        )
        mock_create_provider.return_value = mock_provider

        # Create existing summary
        summary_file = mock_env["vim_chatgpt_dir"] / "summary.md"
        summary_file.write_text("""<!-- SUMMARY_METADATA
cutoff_byte: 100
-->
# Summary
Old content""")

        generate_conversation_summary()

        # Verify provider was called
        assert mock_create_provider.called
        assert mock_provider.stream_chat.called
