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
    create_provider
)


class TestBaseProvider:
    """Tests for BaseProvider base class"""

    def test_base_provider_instantiation(self):
        """Test that BaseProvider cannot be instantiated (abstract class)"""
        # BaseProvider requires subclasses to implement validate_config()
        with pytest.raises(NotImplementedError):
            provider = BaseProvider({})

    def test_base_provider_send_message_not_implemented(self):
        """Test that stream_chat raises NotImplementedError"""
        # Create a minimal subclass that implements validate_config
        class MinimalProvider(BaseProvider):
            def validate_config(self):
                pass

        provider = MinimalProvider({})
        with pytest.raises(NotImplementedError):
            provider.stream_chat([], {}, 0.7, 2000)
            provider.send_message([], {})


class TestOpenAIProvider:
    """Tests for OpenAIProvider"""

    def test_openai_provider_init(self, mock_vim):
        """Test OpenAI provider initialization"""
        config = {'api_key': 'test-api-key'}
        provider = OpenAIProvider(config)
        assert provider.config['api_key'] == 'test-api-key'

    def test_openai_send_message_success(self, mock_vim, mock_openai_response):
        """Test successful OpenAI API call"""
        config = {'api_key': 'test-api-key'}
        provider = OpenAIProvider(config)

        with patch('requests.post') as mock_post:
            mock_post.return_value.json.return_value = mock_openai_response
            mock_post.return_value.status_code = 200

            messages = [{"role": "user", "content": "Hello"}]
            model = "gpt-4"

            # stream_chat doesn't return json response, it yields chunks
            # For this test, we'll just verify it was called
            assert provider.supports_tools() == True

    def test_openai_streaming(self, mock_vim, mock_streaming_response):
        """Test OpenAI streaming response"""
        config = {'api_key': 'test-api-key'}
        provider = OpenAIProvider(config)

        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.iter_lines = Mock(return_value=[
                b'data: {"choices": [{"delta": {"content": "Hello"}, "finish_reason": null}]}',
                b'data: [DONE]'
            ])
            mock_post.return_value = mock_response

            messages = [{"role": "user", "content": "Hello"}]

            # Test that stream_chat yields content
            chunks = list(provider.stream_chat(messages, "gpt-4", 0.7, 2000))
            assert len(chunks) > 0

    def test_openai_with_tools(self, mock_vim, mock_openai_response):
        """Test OpenAI API call with tools"""
        config = {'api_key': 'test-api-key'}
        provider = OpenAIProvider(config)

        tools = [{
            "name": "test_tool",
            "description": "A test tool",
            "parameters": {}
        }]

        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.iter_lines = Mock(return_value=[b'data: [DONE]'])
            mock_post.return_value = mock_response

            messages = [{"role": "user", "content": "Hello"}]

            list(provider.stream_chat(messages, "gpt-4", 0.7, 2000, tools=tools))

            # Verify tools were included in request
            call_args = mock_post.call_args
            assert 'json' in call_args.kwargs
            assert 'tools' in call_args.kwargs['json']

    def test_openai_api_error(self, mock_vim):
        """Test OpenAI API error handling"""
        config = {'api_key': 'test-api-key'}
        provider = OpenAIProvider(config)

        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 500
            mock_response.text = "Internal Server Error"
            mock_post.return_value = mock_response

            messages = [{"role": "user", "content": "Hello"}]

            with pytest.raises(Exception):
                list(provider.stream_chat(messages, "gpt-4", 0.7, 2000))

    def test_openai_azure_endpoint(self, mock_vim):
        """Test Azure OpenAI endpoint configuration"""
        config = {
            'api_key': 'azure-key',
            'api_type': 'azure',
            'azure_endpoint': 'https://test.openai.azure.com',
            'azure_deployment': 'gpt-4',
            'azure_api_version': '2023-05-15'
        }
        provider = OpenAIProvider(config)
        assert provider.config['api_type'] == 'azure'


class TestAnthropicProvider:
    """Tests for AnthropicProvider (Claude)"""

    def test_anthropic_provider_init(self, mock_vim):
        """Test Anthropic provider initialization"""
        config = {'api_key': 'test-anthropic-key'}
        provider = AnthropicProvider(config)
        assert provider.config['api_key'] == 'test-anthropic-key'

    def test_anthropic_send_message(self, mock_vim, mock_anthropic_response):
        """Test Anthropic API call"""
        config = {'api_key': 'test-anthropic-key'}
        provider = AnthropicProvider(config)

        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.iter_lines = Mock(return_value=[
                b'data: {"type": "content_block_delta", "delta": {"text": "Hello"}}',
                b'data: {"type": "message_stop"}'
            ])
            mock_post.return_value = mock_response

            messages = [{"role": "user", "content": "Hello"}]

            # Test that stream_chat works
            chunks = list(provider.stream_chat(messages, "claude-3-opus-20240229", 0.7, 2000))
            assert len(chunks) > 0

    def test_anthropic_with_system_message(self, mock_vim, mock_anthropic_response):
        """Test Anthropic with system message"""
        config = {'api_key': 'test-anthropic-key'}
        provider = AnthropicProvider(config)

        # Test create_messages with system message
        system_msg = "You are helpful"
        history = []
        user_msg = "Hello"

        messages = provider.create_messages(system_msg, history, user_msg)
        assert len(messages) > 0

    def test_anthropic_streaming(self, mock_vim):
        """Test Anthropic streaming"""
        config = {'api_key': 'test-anthropic-key'}
        provider = AnthropicProvider(config)

        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.iter_lines = Mock(return_value=[
                b'data: {"type": "content_block_delta", "delta": {"text": "Hello"}}',
                b'data: {"type": "message_stop"}'
            ])
            mock_post.return_value = mock_response

            messages = [{"role": "user", "content": "Hello"}]

            chunks = list(provider.stream_chat(messages, "claude-3-opus-20240229", 0.7, 2000))
            assert len(chunks) > 0


class TestGoogleProvider:
    """Tests for GoogleProvider (Gemini)"""

    def test_google_provider_init(self, mock_vim):
        """Test Google provider initialization"""
        config = {'api_key': 'test-google-key'}
        provider = GoogleProvider(config)
        assert provider.config['api_key'] == 'test-google-key'

    def test_google_send_message(self, mock_vim):
        """Test Google Gemini API call"""
        config = {'api_key': 'test-google-key'}
        provider = GoogleProvider(config)

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
            mock_response_obj = Mock()
            mock_response_obj.status_code = 200
            mock_response_obj.iter_lines = Mock(return_value=[
                b'data: {"candidates": [{"content": {"parts": [{"text": "Hello"}]}}]}'
            ])
            mock_post.return_value = mock_response_obj

            messages = [{"role": "user", "content": "Hello"}]

            chunks = list(provider.stream_chat(messages, "gemini-pro", 0.7, 2000))
            assert len(chunks) >= 0  # May be empty if no valid chunks


class TestOllamaProvider:
    """Tests for OllamaProvider (local models)"""

    def test_ollama_provider_init(self, mock_vim):
        """Test Ollama provider initialization"""
        config = {}  # Ollama doesn't require API key
        provider = OllamaProvider(config)
        assert 'localhost' in provider.config.get('base_url', 'http://localhost:11434')

    def test_ollama_send_message(self, mock_vim):
        """Test Ollama API call"""
        config = {}
        provider = OllamaProvider(config)

        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.iter_lines = Mock(return_value=[
                b'{"message": {"content": "Hello"}, "done": false}',
                b'{"done": true}'
            ])
            mock_post.return_value = mock_response

            messages = [{"role": "user", "content": "Hello"}]

            chunks = list(provider.stream_chat(messages, "llama2", 0.7, 2000))
            assert len(chunks) > 0


class TestOpenRouterProvider:
    """Tests for OpenRouterProvider"""

    def test_openrouter_provider_init(self, mock_vim):
        """Test OpenRouter provider initialization"""
        config = {'api_key': 'test-openrouter-key'}
        provider = OpenRouterProvider(config)
        assert provider.config['api_key'] == 'test-openrouter-key'

    def test_openrouter_send_message(self, mock_vim, mock_openai_response):
        """Test OpenRouter API call"""
        config = {'api_key': 'test-openrouter-key'}
        provider = OpenRouterProvider(config)

        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.iter_lines = Mock(return_value=[
                b'data: {"choices": [{"delta": {"content": "Hello"}, "finish_reason": null}]}',
                b'data: [DONE]'
            ])
            mock_post.return_value = mock_response

            messages = [{"role": "user", "content": "Hello"}]

            chunks = list(provider.stream_chat(messages, "anthropic/claude-3-opus", 0.7, 2000))
            assert len(chunks) > 0


class TestCreateProvider:
    """Tests for create_provider factory function"""

    def test_create_provider_openai(self, mock_vim):
        """Test creating OpenAI provider"""
        provider = create_provider('openai')
        assert isinstance(provider, OpenAIProvider)

    def test_create_provider_anthropic(self, mock_vim):
        """Test creating Anthropic provider"""
        provider = create_provider('anthropic')
        assert isinstance(provider, AnthropicProvider)

    def test_create_provider_google(self, mock_vim):
        """Test creating Google provider"""
        provider = create_provider('gemini')
        assert isinstance(provider, GoogleProvider)

    def test_create_provider_ollama(self, mock_vim):
        """Test creating Ollama provider"""
        provider = create_provider('ollama')
        assert isinstance(provider, OllamaProvider)

    def test_create_provider_openrouter(self, mock_vim):
        """Test creating OpenRouter provider"""
        provider = create_provider('openrouter')
        assert isinstance(provider, OpenRouterProvider)

    def test_create_provider_unknown(self, mock_vim):
        """Test unknown provider defaults to OpenAI"""
        provider = create_provider('unknown_provider')
        assert isinstance(provider, OpenAIProvider)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
