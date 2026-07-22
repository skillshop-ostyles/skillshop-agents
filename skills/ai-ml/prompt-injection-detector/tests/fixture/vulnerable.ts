import OpenAI from 'openai';

const openai = new OpenAI();

// VULNERABLE: user input directly in system prompt
app.post('/chat', async (req, res) => {
  const userMessage = req.body.message;
  const response = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [
      { role: 'system', content: `You are a helpful assistant. The user says: ${userMessage}` },
      { role: 'user', content: userMessage }
    ],
  });
  res.json(response);
});

// VULNERABLE: env var in system prompt
const systemPrompt = process.env.SYSTEM_PROMPT;
const response2 = await openai.chat.completions.create({
  model: 'gpt-4',
  messages: [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: 'Hello' }
  ],
});
