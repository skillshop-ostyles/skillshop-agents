from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.embeddings import OpenAIEmbeddings

# GOOD: Consistent embedding config with chunking + overlap
text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,
    chunk_overlap=50
)
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
documents = text_splitter.split_documents(raw_docs)
vectorstore = Chroma.from_documents(documents, embeddings)

# BAD: Embedding model mismatch — different models for query and doc
query_embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
doc_embeddings = OpenAIEmbeddings(model="text-embedding-ada-002")

# BAD: No chunking at all (raw documents directly to vector store)
raw_vectors = Chroma.from_documents(raw_docs, embeddings)  # No splitter
