from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.embeddings import OpenAIEmbeddings
from langchain.vectorstores import Chroma
from langchain.chat_models import ChatOpenAI

text_splitter2 = RecursiveCharacterTextSplitter(chunk_size=2000, chunk_overlap=200)
embeddings2 = OpenAIEmbeddings(model="text-embedding-ada-002")
llm2 = ChatOpenAI(model="gpt-4", temperature=0)
vectorstore2 = Chroma.from_documents(docs, embeddings2)
retriever2 = vectorstore2.as_retriever(search_kwargs={"k": 5})
# 2000 * 5 = 10000 tokens, gpt-4 context = 8192 — overflow!
