import OpenAI from 'openai';
const openai = new OpenAI();

const cache = new Map<string, string>();

async function classify(text: string) {
  const cached = cache.get(text);
  if (cached) return cached;

  const r = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: `Classify: ${text}` }],
    max_tokens: 50,
    temperature: 0.0,
  });
  const result = r.choices[0].message.content || '';
  cache.set(text, result);
  return result;
}

async function summarizeBulk(texts: string[]) {
  const r = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: `Summarize: ${texts.join('\n---\n')}` }],
    max_tokens: 500,
    temperature: 0.3,
  });
  return r.choices[0].message.content;
}
