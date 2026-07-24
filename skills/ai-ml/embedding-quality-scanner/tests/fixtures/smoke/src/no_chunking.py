from langchain.embeddings import OpenAIEmbeddings

embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
raw_vectors = Chroma.from_documents(raw_docs, embeddings)
