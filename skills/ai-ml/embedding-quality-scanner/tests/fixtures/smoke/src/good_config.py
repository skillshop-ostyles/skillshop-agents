from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.embeddings import OpenAIEmbeddings

text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,
    chunk_overlap=50
)
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
documents = text_splitter.split_documents(raw_docs)
vectorstore = Chroma.from_documents(documents, embeddings)
