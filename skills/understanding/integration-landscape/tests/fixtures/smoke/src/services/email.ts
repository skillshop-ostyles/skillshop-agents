export async function sendEmail(to: string, subject: string, body: string) {
  const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: { Authorization: `Bearer ${process.env.SENDGRID_API_KEY}` },
    body: JSON.stringify({ personalizations: [{ to: [{ email: to }] }], subject, content: [{ type: 'text/plain', value: body }] }),
  });
  if (!response.ok) throw new Error(`SendGrid error: ${response.status}`);
}
