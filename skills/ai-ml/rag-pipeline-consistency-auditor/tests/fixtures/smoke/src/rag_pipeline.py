from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.embeddings import OpenAIEmbeddings
from langchain.vectorstores import Chroma
from langchain.chat_models import ChatOpenAI

# GOOD: consistent config — retrieved fits in context window
text_splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
llm = ChatOpenAI(model="gpt-4o", temperature=0)
vectorstore = Chroma.from_documents(docs, embeddings)
retriever = vectorstore.as_retriever(search_kwargs={"k": 3})
# Retrieved: 500 * 3 = 1500 tokens, context: 128000 — fits

# BAD: overflow risk — chunk_size=2000, top_k=5 = 10k tokens, but gpt-4 has 8192 context
text_splitter2 = RecursiveCharacterTextSplitter(chunk_size=2000, chunk_overlap=200)
embeddings2 = OpenAIEmbeddings(model="text-embedding-ada-002")
llm2 = ChatOpenAI(model="gpt-4", temperature=0)
vectorstore2 = Chroma.from_documents(docs, embeddings2)
retriever2 = vectorstore2.as_retriever(search_kwargs={"k": 5})
# Retrieved: 2000 * 5 = 10000 tokens, context: 8192 — overflow!
