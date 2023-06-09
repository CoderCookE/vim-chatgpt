#!/usr/bin/env python
# ref: https://python.langchain.com/en/latest/use_cases/code/code-analysis-deeplake.html
import os
import re

from langchain.document_loaders import TextLoader
from langchain.text_splitter import CharacterTextSplitter
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.vectorstores import DeepLake
from langchain.chat_models import ChatOpenAI
from langchain.chains import ConversationalRetrievalChain

from utils import nearestAncestor, setup_openai, log


class Helper():
    def __init__(self, root_dir=None, chunk_size=4000, overwrite=False):
        self.root_markers = ['.git', '.svn', '.hg', '.project', '.root', '.venv']
        self.root_dir = root_dir
        self.dataset_dir = f"{os.environ['HOME']}/.deeplake"
        self.chunk_size=chunk_size
        self.overwrite = overwrite

    def get_qa(self, metric='cos', model='gtp-3.5-tubo', temperature=0):
        db = self.get_db()
        retriever = db.as_retriever()
        retriever.search_kwargs['distance_metric'] = metric
        retriever.search_kwargs['maximal_marginal_relevance'] = True
        model = ChatOpenAI(model_name='gpt-3.5-turbo', temperature=temperature)
        qa = ConversationalRetrievalChain.from_llm(model, retriever=retriever)
        return qa

    # TODO show progress in vim status line
    def get_docs(self):
        docs = []
        for dirpath, _, filenames in os.walk(self.root_dir):
            for file in filenames:
                if not re.match(r".*\.(py|java|txt)$", file):
                    continue
                try:
                    loader = TextLoader(os.path.join(dirpath, file), encoding='utf-8')
                    docs.extend(loader.load_and_split())
                except Exception as e:
                    log.warning(e)
        log.info(f'len(docs): {len(docs)}')
        return docs

    def get_root(self):
        if not self.root_dir:
            # TODO vim cwd
            cwd = os.getcwd()
            self.root_dir = nearestAncestor(self.root_markers, cwd)
            log.info(f"root_dir: {self.root_dir}")

    def get_db(self):
        self.get_root()
        embeddings = OpenAIEmbeddings()
        dataset_path = self.get_dataset_path()
        log.info(f"dataset_path: {dataset_path}")
        if not self.overwrite and os.path.isdir(dataset_path):
            db = DeepLake(dataset_path=dataset_path, read_only=True, embedding_function=embeddings)
            return db
        docs = self.get_docs()
        splitter = CharacterTextSplitter(chunk_size=self.chunk_size, chunk_overlap=0)
        texts = splitter.split_documents(docs)
        log.info(f"len(texts): {len(texts)}")
        embeddings = OpenAIEmbeddings()
        db = DeepLake.from_documents(texts, embeddings, dataset_path=dataset_path, overwrite=self.overwrite)
        return db

    def get_dataset_path(self):
        proj = os.path.abspath(self.root_dir).replace(os.sep, '_')
        return f"{self.dataset_dir}/{proj}"


def chat(question, qa, chat_history, max_history=10):
    answer = qa({"question": question, "chat_history": chat_history})['answer']
    log.info(f"-> **Question**: {question} \n")
    log.info(f"**Answer**: {answer} \n")
    chat_history.append((question, answer))
    log.info(f"len(chat_history): {len(chat_history)}")


def loop_qa(qa, esc='\x1b', max_history=10):
    chat_history = []
    while True:
        prompt = input('?')
        if prompt == esc:
            break
        elif not prompt:
            continue
        chat(prompt, qa, chat_history)
        chat_history = chat_history[-max_history:]


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('--root_dir', type=str, help='root_dir of data/project')
    parser.add_argument('--overwrite', action='store_true', help='overwrite vector db if exists')

    args = parser.parse_args()
    setup_openai()
    qa = Helper(args.root_dir, overwrite=args.overwrite).get_qa()
    loop_qa(qa)
