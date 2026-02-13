"""
Tests for python3/chatgpt/utils.py

Tests utility functions including logging, formatting, and history management.
"""

import pytest
import os
import tempfile
from unittest.mock import Mock, patch, mock_open
from datetime import datetime

# Import the module under test
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'python3'))

from chatgpt.utils import (
    debug_log,
    safe_vim_eval,
    format_vim_string,
    get_project_root,
    get_history_path,
    read_history,
    append_to_history,
    clear_history,
    get_context_path,
    read_context
)


class TestDebugLog:
    """Tests for debug_log function"""
    
    def test_debug_log_disabled(self, mock_vim):
        """Test that debug_log does nothing when debug is disabled"""
        mock_vim.eval.return_value = '0'
        
        with patch('builtins.open', mock_open()) as mock_file:
            debug_log("Test message")
            mock_file.assert_not_called()
    
    def test_debug_log_enabled(self, mock_vim, temp_project_dir):
        """Test that debug_log writes when enabled"""
        mock_vim.eval.return_value = '1'
        
        with patch('chatgpt.utils.get_project_root', return_value=temp_project_dir):
            debug_log("Test debug message")
            
            log_file = os.path.join(temp_project_dir, '.vim-chatgpt', 'debug.log')
            assert os.path.exists(log_file)
            
            with open(log_file, 'r') as f:
                content = f.read()
                assert "Test debug message" in content
    
    def test_debug_log_with_exception(self, mock_vim, temp_project_dir):
        """Test debug_log handles exceptions gracefully"""
        mock_vim.eval.return_value = '1'
        
        with patch('builtins.open', side_effect=IOError("Cannot write")):
            # Should not raise exception
            debug_log("Test message")


class TestSafeVimEval:
    """Tests for safe_vim_eval function"""
    
    def test_safe_vim_eval_success(self, mock_vim):
        """Test successful vim eval"""
        mock_vim.eval.return_value = 'test_value'
        result = safe_vim_eval('g:test_var')
        assert result == 'test_value'
    
    def test_safe_vim_eval_with_default(self, mock_vim):
        """Test vim eval with default value"""
        mock_vim.eval.side_effect = Exception("Vim error")
        result = safe_vim_eval('g:test_var', 'default_value')
        assert result == 'default_value'
    
    def test_safe_vim_eval_exception_without_default(self, mock_vim):
        """Test vim eval exception without default"""
        mock_vim.eval.side_effect = Exception("Vim error")
        result = safe_vim_eval('g:test_var')
        assert result == ''


class TestFormatVimString:
    """Tests for format_vim_string function"""
    
    def test_format_vim_string_basic(self):
        """Test basic string formatting"""
        result = format_vim_string("Hello World")
        assert result == "Hello World"
    
    def test_format_vim_string_with_quotes(self):
        """Test escaping quotes"""
        result = format_vim_string('He said "hello"')
        assert '\\"' in result or "'" in result
    
    def test_format_vim_string_with_newlines(self):
        """Test handling newlines"""
        result = format_vim_string("Line 1\nLine 2")
        assert "Line 1" in result
        assert "Line 2" in result


class TestProjectRoot:
    """Tests for get_project_root function"""
    
    def test_get_project_root_with_git(self, temp_project_dir):
        """Test finding project root with .git directory"""
        with patch('os.getcwd', return_value=temp_project_dir):
            root = get_project_root()
            assert root == temp_project_dir
    
    def test_get_project_root_without_git(self, tmp_path):
        """Test project root when no .git directory"""
        test_dir = tmp_path / "test"
        test_dir.mkdir()
        
        with patch('os.getcwd', return_value=str(test_dir)):
            root = get_project_root()
            assert root == str(test_dir)
    
    def test_get_project_root_nested(self, temp_project_dir):
        """Test finding project root from nested directory"""
        nested_dir = os.path.join(temp_project_dir, 'src', 'nested')
        os.makedirs(nested_dir, exist_ok=True)
        
        with patch('os.getcwd', return_value=nested_dir):
            root = get_project_root()
            assert root == temp_project_dir


class TestHistoryManagement:
    """Tests for history file management"""
    
    def test_get_history_path(self, temp_project_dir):
        """Test getting history file path"""
        with patch('chatgpt.utils.get_project_root', return_value=temp_project_dir):
            path = get_history_path()
            expected = os.path.join(temp_project_dir, '.vim-chatgpt', 'history.txt')
            assert path == expected
    
    def test_read_history_existing(self, mock_history_file):
        """Test reading existing history"""
        with patch('chatgpt.utils.get_history_path', return_value=mock_history_file):
            history = read_history()
            assert "Hello" in history
            assert "Hi there" in history
    
    def test_read_history_nonexistent(self, temp_project_dir):
        """Test reading non-existent history"""
        fake_path = os.path.join(temp_project_dir, 'nonexistent.txt')
        with patch('chatgpt.utils.get_history_path', return_value=fake_path):
            history = read_history()
            assert history == ""
    
    def test_append_to_history(self, temp_project_dir):
        """Test appending to history"""
        history_path = os.path.join(temp_project_dir, '.vim-chatgpt', 'history.txt')
        
        with patch('chatgpt.utils.get_history_path', return_value=history_path):
            append_to_history("User: Test message")
            
            with open(history_path, 'r') as f:
                content = f.read()
                assert "User: Test message" in content
    
    def test_clear_history(self, mock_history_file):
        """Test clearing history"""
        with patch('chatgpt.utils.get_history_path', return_value=mock_history_file):
            clear_history()
            
            with open(mock_history_file, 'r') as f:
                content = f.read()
                assert content == ""


class TestContextManagement:
    """Tests for context file management"""
    
    def test_get_context_path(self, temp_project_dir):
        """Test getting context file path"""
        with patch('chatgpt.utils.get_project_root', return_value=temp_project_dir):
            path = get_context_path()
            expected = os.path.join(temp_project_dir, '.vim-chatgpt', 'context.md')
            assert path == expected
    
    def test_read_context_existing(self, mock_context_file):
        """Test reading existing context"""
        with patch('chatgpt.utils.get_context_path', return_value=mock_context_file):
            context = read_context()
            assert "Project Context" in context
            assert "test project" in context
    
    def test_read_context_nonexistent(self, temp_project_dir):
        """Test reading non-existent context"""
        fake_path = os.path.join(temp_project_dir, 'nonexistent.md')
        with patch('chatgpt.utils.get_context_path', return_value=fake_path):
            context = read_context()
            assert context == ""


class TestEdgeCases:
    """Tests for edge cases and error handling"""
    
    def test_empty_strings(self):
        """Test handling empty strings"""
        assert format_vim_string("") == ""
    
    def test_very_long_strings(self):
        """Test handling very long strings"""
        long_string = "A" * 10000
        result = format_vim_string(long_string)
        assert len(result) >= 10000
    
    def test_unicode_strings(self):
        """Test handling unicode characters"""
        unicode_str = "Hello 世界 🌍"
        result = format_vim_string(unicode_str)
        assert "Hello" in result
    
    def test_special_characters(self):
        """Test handling special characters"""
        special = "Test\t\r\n\\"
        result = format_vim_string(special)
        assert result is not None


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
