import openai

# GOOD: well-structured prompt with appropriate max_tokens
response = openai.chat.completions.create(
    model="gpt-4o",
    messages=[
        {"role": "system", "content": "Classify the sentiment of the text as positive, negative, or neutral."},
        {"role": "user", "content": "This product is amazing!"},
    ],
    max_tokens=10
)

# BAD: excessive context injection — full document in system prompt
full_doc = open("document.txt").read()
response = openai.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=[
        {"role": "system", "content": "Summarize this document: " + full_doc},
    ],
    max_tokens=500
)

# BAD: max_tokens exceeds context window
response = openai.chat.completions.create(
    model="gpt-3.5-turbo-16k",
    messages=[
        {"role": "system", "content": "Write a very long response."},
        {"role": "user", "content": "Tell me everything."},
    ],
    max_tokens=50000  # Exceeds 16k context
)
