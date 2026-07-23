// Fixture for third-party-trust.
// Mock outbound-call code: stripe (trusted), supabase (trusted),
// custom webhook receiver (signature verification missing),
// user-controlled URL fetch (SSRF risk).

import express from 'express';
import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';

// 1. Trusted: Stripe API.
const stripe = new Stripe(process.env.STRIPE_API_KEY);
export async function charge(token: string) {
    await stripe.charges.create({ amount: 9900, currency: 'usd', source: token });
}

// 2. Trusted: Supabase with explicit auth header.
export async function fetchProfile(userId: string) {
    const supabase = createClient(
        'https://abcdefgh.supabase.co',
        process.env.SUPABASE_KEY ?? '',
        { headers: { Authorization: `Bearer ${process.env.SUPABASE_KEY}` } }
    );
    return await supabase.from('users').select('*').eq('id', userId).single();
}

// 3. User-controlled URL fetch (SSRF risk).
export async function imageProxy(req: express.Request) {
    const url = (req.query.url as string) || '';       // user-controlled
    const res = await fetch(url);                          // no validation
    return res.blob();
}

// 4. Webhook receiver LACKING signature verification.
export async function stripeWebhook(req: express.Request) {
    const event = req.body;
    // No stripe.webhooks.constructEvent check.
    if (event.type === 'payment_intent.succeeded') {
        await processCharge(event.data);
    }
}

// 5. Internal service-to-service URL hardcoded.
const AUTH_HEADER = 'Bearer ' + (process.env.UPSTREAM_TOKEN || '');
async function streamLogs() {
    const r = await fetch('https://logs.internal.acme.corp/v1/stream', {
        headers: { Authorization: AUTH_HEADER }
    });
    return r.text();
}
