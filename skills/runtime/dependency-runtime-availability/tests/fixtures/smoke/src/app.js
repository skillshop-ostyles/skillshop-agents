const express = require('express');
const app = express();

// WILL-FAIL: Dynamic config require — staging.json might not exist
const config = require('./config/' + process.env.NODE_ENV + '.json');

// MIGHT-FAIL: Native module, may not install on all platforms
const sharp = require('sharp');

// SAFE: Bundled file read with deterministic path
const fs = require('fs');
const schema = fs.readFileSync('./data/schema.graphql', 'utf-8');

// WILL-FAIL: DevDependency used at runtime
const debugTool = require('pkg-in-dev-deps');

// SAFE: Deterministic require
const db = require('./db');

app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.listen(3000);
