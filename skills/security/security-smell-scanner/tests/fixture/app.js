const express = require('express');
const crypto = require('crypto');
const app = express();

// Hardcoded credential
const DB_PASSWORD = "super_secret_1";
const API_KEY = "sk-live-abc123def456";
const SECRET = "my_secret_token_value";

function getConfig() {
  return {
    password: DB_PASSWORD,
    token: SECRET
  };
}

// Insecure default
const tlsConfig = {
  rejectUnauthorized: false,
  secure: false
};

// Open redirect
app.get('/logout', (req, res) => {
  const next = req.query.redirectUrl;
  res.redirect(next);
});

app.get('/goto', (req, res) => {
  res.redirect(req.query.url);
});

app.get('/login', (req, res) => {
  res.redirect('/dashboard');
});

// ORM false positive (should NOT be flagged as SQL injection)
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function findUsers(city) {
  return await prisma.user.findMany({
    where: { city: city }
  });
}

module.exports = { getConfig, tlsConfig, app };
