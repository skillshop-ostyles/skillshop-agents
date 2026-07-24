from openai import OpenAI
client = OpenAI()

# GOOD: System prompt with output format spec + safety instructions
response = client.chat.completions.create(
    model="gpt-4",
    messages=[
        {"role": "system", "content": "You are a helpful assistant. Always respond in JSON format with keys: summary, sentiment, confidence. Never generate harmful content."},
        {"role": "user", "content": f"Analyze this text: {user_text}"}
    ]
)

# DANGEROUS: Direct user input injection without sanitization
response = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": user_input}  # No sanitization - injection susceptible
    ]
)

# RISKY: Open-ended prompt without any constraints
response = client.chat.completions.create(
    model="gpt-4",
    messages=[
        {"role": "user", "content": "Tell me about " + topic}
    ]
)

# SAFE: Structured with format spec via output parser
from langchain.prompts import ChatPromptTemplate
template = ChatPromptTemplate.from_messages([
    ("system", "You are a classification expert. Output only a single word: positive, negative, or neutral."),
    ("human", "{input}")
])
