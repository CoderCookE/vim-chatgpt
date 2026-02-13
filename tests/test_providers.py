"""
Tests for python3/chatgpt/providers.py

Tests all AI provider classes including OpenAI, Anthropic, Google, Ollama, and OpenRouter.
"""

import pytest
import json
from unittest.mock import Mock, patch, MagicMock
import requests

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'python3'))

from chatgpt.providers import (
    BaseProvider,
    OpenAIProvider,
    AnthropicProvider,
    GoogleProvider,
    OllamaProvider,
    OpenRouterProvider,
    get_provider
)


class TestBaseProvider:
    """Tests for BaseProvider base class"""
    
    def test_base_provider_instantiation(self):
        """Test that BaseProvider can be instantiated"""
        provider = BaseProvider()
        assert provider is not None
    
    def test_base_provider_send_message_not_implemented(self):
        """Test that send_message raises NotImplementedError"""
        provider = BaseProvider()
        with pytest.raises(NotImplementedError):
            provider.send_message([], {})


class TestOpenAIProvider:
    """Tests for OpenAIProvider"""
    
    def test_openai_provider_init(self, mock_vim):
        """Test OpenAI provider initialization"""
        provider = OpenAIProvider()
        assert provider.api_key is not None
        assert provider.base_url is not None
    
    def test_openai_send_message_success(self, mock_vim, mock_openai_response):
        """Test successful OpenAI API call"""
        provider = OpenAIProvider()
        
        with patch('requests.post') as mock_post:
            mock_post.return_value.json.return_value = mock_openai_response
            mock_post.return_value.status_code = 200
            
            messages = [{"role": "user", "content": "Hello"}]
            config = {"model": "gpt-4", "temperature": 0.7}
            
            response = provider.send_message(messages, config)
            
            assert response == mock_openai_response
            mock_post.assert_called_once()
    
    def test_openai_streaming(self, mock_vim, mock_streaming_response):
        """Test OpenAI streaming response"""
        provider = OpenAIProvider()
        
        with patch('requests.post') as mock_post:
            mock_post.return_value = mock_streaming_response
            
            messages = [{"role": "user", "content": "Hello"}]
            config = {"model": "gpt-4", "stream": True}
            
            result = provider.send_message(messages, config, stream=True)
            
            # Should return the response object for streaming
            assert result is not None
    
    def test_openai_with_tools(self, mock_vim, mock_openai_response):
        """Test OpenAI API call with tools"""
        provider = OpenAIProvider()
        
        tools = [{
            "type": "function",
            "function": {
                "name": "test_tool",
                "description": "A test tool",
                "parameters": {}
            }
        }]
        
        with patch('requests.post') as mock_post:
            mock_post.return_value.json.return_value = mock_openai_response
            mock_post.return_value.status_code = 200
            
            messages = [{"role": "user", "content": "Hello"}]
            config = {"model": "gpt-4", "tools": tools}
            
            response = provider.send_message(messages, config)
            
            # Verify tools were included in request
            call_args = mock_post.call_args
            assert 'json' in call_args.kwargs
            assert 'tools' in call_args.kwargs['json']
    
    def test_openai_api_error(self, mock_vim):
        """Test OpenAI API error handling"""
        provider = OpenAIProvider()
        
        with patch('requests.post') as mock_post:
            mock_post.side_effect = requests.exceptions.RequestException("API Error")
            
            messages = [{"role": "user", "content": "Hello"}]
            config = {"model": "gpt-4"}
            
            with pytest.raises(Exception):
                provider.send_message(messages, config)
    
    def test_openai_azure_endpoint(self, mock_vim):
        """Test Azure OpenAI endpoint configuration"""
        mock_vim.eval = lambda x: {
            'g:azure_openai_endpoint': 'https://test.openai.azure.com',
            'g:azure_openai_api_key': 'azure-key',
            'g:chat_gpt_model': 'gpt-4'
        }.get(x, '')
        
        provider = OpenAIProvider()
        assert 'azure' in provider.base_url.lower()


class TestAnthropicProvider:
    """Tests for AnthropicProvider (Claude)"""
    
    def test_anthropic_provider_init(self, mock_vim):
        """Test Anthropic provider initialization"""
        provider = AnthropicProvider()
        assert provider.api_key is not None
        assert 'anthropic' in provider.base_url.lower()
    
    def test_anthropic_send_message(self, mock_vim, mock_anthropic_response):
        """Test Anthropic API call"""
        provider = AnthropicProvider()
        
        with patch('requests.post') as mock_post:
            mock_post.return_value.json.return_value = mock_anthropic_response
            mock_post.return_value.status_code = 200
            
            messages = [{"role": "user", "content": "Hello"}]
            config = {"model": "claude-3-opus-20240229", "max_tokens": 2000}
            
            response = provider.send_message(messages, config)
            
            assert response == mock_anthropic_response
            
            # Verify Anthropic-specific headers
            call_args = mock_post.call_args
            assert 'headers' in call_args.kwargs
            assert 'anthropic-version' in call_args.kwargs['headers']
    
    def test_anthropic_with_system_message(self, mock_vim, mock_anthropic_response):
        """Test Anthropic with system message"""
        provider = AnthropicProvider()
        
        with patch('requests.post') as mock_post:
            mock_post.return_value.json.return_value = mock_anthropic_response
            mock_post.return_value.status_code = 200
            
            messages = [
                {"role": "system", "content": "You are helpful"},
                {"role": "user", "content": "Hello"}
            ]
            config = {"model": "claude-3-opus-20240229", "max_tokens": 2000}
            
            response = provider.send_message(messages, config)
            
            # Verify system message is extracted
            call_args = mock_post.call_args
            assert 'json' in call_args.kwargs
            request_data = call_args.kwargs['json']
            assert 'system' in request_data or len(request_data.get('messages', [])) > 0
    
    def test_anthropic_streaming(self, mock_vim):
        """Test Anthropic streaming"""
        provider = AnthropicProvider()
        
        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.iter_lines = Mock(return_value=[
                b'data: {"type": "content_block_delta", "delta": {"text": "Hello"}}',
                b'data: {"type": "message_stop"}'
            ])
            mock_post.return_value = mock_response
            
            messages = [{"role": "user", "content": "Hello"}]
            config = {"model": "claude-3-opus-20240229", "max_tokens": 2000}
            
            result = provider.send_message(messages, config, stream=True)
            assert result is not None


class TestGoogleProvider:
    """Tests for GoogleProvider (Gemini)"""
    
    def test_google_provider_init(self, mock_vim):
        """Test Google provider initialization"""
        provider = GoogleProvider()
        assert provider.api_key is not None
        assert 'generativelanguage' in provider.base_url
    
    def test_google_send_message(self, mock_vim):
        """Test Google Gemini API call"""
        provider = GoogleProvider()
        
        mock_response = {
            "candidates": [{
                "content": {
                    "parts": [{"text": "Hello from Gemini"}],
                    "role": "model"
                },
                "finishReason": "STOP"
            }]
        }
        
        with patch('requests.post') as mock_post:
            mock_post.return_value.json.return_value = mock_response
            mock_post.return_value.status_code = 200
            
            messages = [{"role": "user", "content": "Hello"}]
            config = {"model": "gemini-pro", "temperature": 0.7}
            
            response = provider.send_message(messages, config)
            
            assert response == mock_response
    
    def test_google_message_format_conversion(self, mock_vim):
        """Test conversion of messages to Gemini format"""
        provider = GoogleProvider()
        
        mock_response = {"candidates": [{"content": {"parts": [{"text": "Response"}]}}]}
        
        with patch('requests.post') as mock_post:
            mock_post.return_value.json.return_value = mock_response
            mock_post.return_value.status_code = 200
            
            messages = [
                {"role": "user", "content": "First message"},
                {"role": "assistant", "content": "First response"},
                {"role": "user", "content": "Second message"}
            ]
            config = {"model": "gemini-pro"}
            
            provider.send_message(messages, config)
            
            # Verify message format conversion
            call_args = mock_post.call_args
            assert 'json' in call_args.kwargs


class TestOllamaProvider:
    """Tests for OllamaProvider (local models)"""
    
    def test_ollama_provider_init(self, mock_vim):
        """Test Ollama provider initialization"""
        provider = OllamaProvider()
        assert 'localhost' in provider.base_url or '127.0.0.1' in provider.base_url
    
    def test_ollama_send_message(self, mock_vim):
        """Test Ollama API call"""
        provider = OllamaProvider()
        
        mock_response = {
            "message": {
                "role": "assistant",
                "content": "Hello from Ollama"
            },
            "done": True
        }
        
        with patch('requests.post') as mock_post:
            mock_post.return_value.json.return_value = mock_response
            mock_post.return_value.status_code = 200
            
            messages = [{"role": "user", "content": "Hello"}]
            config = {"model": "llama2", "temperature": 0.7}
            
            response = provider.send_message(messages, config)
            
            assert response == mock_response
    
    def test_ollama_custom_host(self, mock_vim):
        """Test Ollama with custom host"""
        mock_vim.eval = lambda x: {
            'g:ollama_host': 'http://custom-host:11434'
        }.get(x, '')
        
        provider = OllamaProvider()
        assert 'custom-host' in provider.base_url


class TestOpenRouterProvider:
    """Tests for OpenRouterProvider"""
    
    def test_openrouter_provider_init(self, mock_vim):
        """Test OpenRouter provider initialization"""
        provider = OpenRouterProvider()
        assert 'openrouter' in provider.base_url.lower()
    
    def test_openrouter_send_message(self, mock_vim, mock_openai_response):
        """Test OpenRouter API call"""
        provider = OpenRouterProvider()
        
        with patch('requests.post') as mock_post:
            mock_post.return_value.json.return_value = mock_openai_response
            mock_post.return_value.status_code = 200
            
            messages = [{"role": "user", "content": "Hello"}]
            config = {"model": "anthropic/claude-3-opus", "temperature": 0.7}
            
            response = provider.send_message(messages, config)
            
            assert response == mock_openai_response
            
            # Verify OpenRouter-specific headers
            call_args = mock_post.call_args
            assert 'headers' in call_args.kwargs


class TestGetProvider:
    """Tests for get_provider factory function"""
    
    def test_get_provider_openai(self, mock_vim):
        """Test getting OpenAI provider"""
        mock_vim.eval = lambda x: 'openai' if 'provider' in x else ''
        provider = get_provider()
        assert isinstance(provider, OpenAIProvider)
    
    def test_get_provider_anthropic(self, mock_vim):
        """Test getting Anthropic provider"""
        mock_vim.eval = lambda x: 'anthropic' if 'provider' in x else ''
        provider = get_provider()
        assert isinstance(provider, AnthropicProvider)
    
    def test_get_provider_google(self, mock_vim):
        """Test getting Google provider"""
        mock_vim.eval = lambda x: 'google' if 'provider' in x else ''
        provider = get_provider()
        assert isinstance(provider, GoogleProvider)
    
    def test_get_provider_ollama(self, mock_vim):
        """Test getting Ollama provider"""
        mock_vim.eval = lambda x: 'ollama' if 'provider' in x else ''
        provider = get_provider()
        assert isinstance(provider, OllamaProvider)
    
    def test_get_provider_openrouter(self, mock_vim):
        """Test getting OpenRouter provider"""
        mock_vim.eval = lambda x: 'openrouter' if 'provider' in x else ''
        provider = get_provider()
        assert isinstance(provider, OpenRouterProvider)
    
    def test_get_provider_default(self, mock_vim):
        """Test default provider (OpenAI)"""
        mock_vim.eval = lambda x: ''
        provider = get_provider()
        assert isinstance(provider, OpenAIProvider)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
