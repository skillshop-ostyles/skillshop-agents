import logging

logger = logging.getLogger(__name__)

# GOOD: auditable - logged with context and human review
features = extract_features(user_data)
score = model.predict(features)
logger.info('Loan decision', {
    'features': features,
    'confidence': score,
    'model_version': 'v2.1',
    'reviewed_by': 'manual'
})
if score > 0.5:
    approve_loan()

# BAD: black-box - no logging at all
if sentiment_classifier(text) == 'negative':
    route_to_complaints()

# BAD: partially logged - sentiment score but no input
sentiment = sentiment_classifier(text)
logger.info('Sentiment: %s', sentiment)
if sentiment == 'negative':
    escalate_ticket()
