from langchain.embeddings import OpenAIEmbeddings

query_embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
doc_embeddings = OpenAIEmbeddings(model="text-embedding-ada-002")
query_vec = query_embeddings.embed_query(text)
doc_vec = doc_embeddings.embed_documents(docs)
