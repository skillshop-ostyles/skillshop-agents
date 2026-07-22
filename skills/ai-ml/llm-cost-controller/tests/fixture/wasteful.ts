import OpenAI from 'openai';
const openai = new OpenAI();

// ANTI-PATTERN 1: expensive model for simple task
async function classify(text: string) {
  const r = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [{ role: 'user', content: `Classify this: ${text}` }],
  });
  return r.choices[0].message.content;
}

// ANTI-PATTERN 2: no max_tokens limit
async function summarize(text: string) {
  const r = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: `Summarize: ${text}` }],
  });
  return r.choices[0].message.content;
}

// ANTI-PATTERN 3: high temperature
async function generate(text: string) {
  const r = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: `Write: ${text}` }],
    temperature: 1.5,
    max_tokens: 1000,
  });
  return r.choices[0].message.content;
}
