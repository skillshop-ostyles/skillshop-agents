const express = require('express');
const app = express();
const OpenAI = require('openai');
const openai = new OpenAI();

// DANGEROUS: Model output used in JSON.parse without validation
app.post('/parse', async (req, res) => {
  const completion = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [{ role: 'user', content: req.body.text }]
  });
  const result = JSON.parse(completion.choices[0].message.content); // Crash if malformed!
  res.json(result);
});

// DANGEROUS: Model output used for financial decision without guardrails
app.post('/decide', async (req, res) => {
  const result = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [{ role: 'user', content: 'Approve or deny: ' + req.body.application }]
  });
  const decision = result.choices[0].message.content;
  if (decision.includes('APPROVE')) {
    await db.update('SET approved = true'); // No validation, no bounds check
  }
});

// SAFE: Output validated through Zod schema
const { z } = require('zod');
const SummarySchema = z.object({ title: z.string(), key_points: z.array(z.string()) });

app.post('/summarize', async (req, res) => {
  const completion = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [{ role: 'user', content: 'Summarize: ' + req.body.text }]
  });
  const parsed = SummarySchema.parse(JSON.parse(completion.choices[0].message.content));
  res.json(parsed);
});

// RISKY: Display without validation but bounded by try/catch
app.post('/chat', async (req, res) => {
  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-3.5-turbo',
      messages: [{ role: 'user', content: req.body.message }]
    });
    res.json({ reply: completion.choices[0].message.content }); // Display only
  } catch (e) {
    res.status(500).json({ error: 'Generation failed' });
  }
});

app.listen(3000);