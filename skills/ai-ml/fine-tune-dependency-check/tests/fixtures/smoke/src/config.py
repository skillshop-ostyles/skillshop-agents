# BAD: deprecated base model - gpt-3.5-turbo-0301 is EOL
model = "ft:gpt-3.5-turbo-0301:my-org:old-model-2023"

# GOOD: current fine-tune
model_v2 = "ft:gpt-4o:my-org:current-2025"

# RISKY: unknown model - not in reference data
custom_model = "my-user/custom-fine-tune"
