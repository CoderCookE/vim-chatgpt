#!/usr/bin/env python
import logging
import asyncio
import os
import traceback


def loop_qa(fn, callback, esc='\x1b', **kwargs):
    @try_fn
    def call_fn(prompt, **kwargs):
        return callback(fn(prompt, prior_qa, **kwargs))

    prior_qa = {}
    while True:
        prompt = input('?')
        if prompt == esc:
            break
        elif not prompt:
            continue
        res = call_fn(prompt)
        prior_qa = {'user': prompt, 'assistant': res}


def try_fn(f):

    async def awrapper(*args, **kwargs):
        try:
            return await f(*args, **kwargs)
        except Exception as e:
            log.warning(traceback.format_exc())
            log.warning(f"An exception occurred: {e}")

    def wrapper(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except Exception as e:
            log.warning(traceback.format_exc())
            log.warning(f"An exception occurred: {e}")

    wrapper = asyncio.iscoroutinefunction(f) and awrapper or wrapper
    return wrapper


def setup_openai():
    import openai
    openai.api_key = os.getenv("OPENAI_API_KEY")
    openai.proxy = os.getenv("OPENAI_PROXY")
    assert openai.api_key


def nearestAncestor(markers, path):
    """
    return the nearest ancestor path(including itself) of `path` that contains
    one of files or directories in `markers`.
    `markers` is a list of file or directory names.
    """
    if os.name == 'nt':
        # e.g. C:\\
        root = os.path.splitdrive(os.path.abspath(path))[0] + os.sep
    else:
        root = '/'

    path = os.path.abspath(path)
    while path != root:
        for name in markers:
            if os.path.exists(os.path.join(path, name)):
                return path
        path = os.path.abspath(os.path.join(path, ".."))

    for name in markers:
        if os.path.exists(os.path.join(path, name)):
            return path

    return ""


logging.basicConfig(
    format="[%(asctime)s] [%(levelname)s] [%(pathname)s:%(lineno)d] %(message)s",
    datefmt='%Y-%m-%d %H:%M:%S',
    level=logging.INFO)

log = logging.getLogger()
