#!/usr/bin/env node
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const installScript = path.join(__dirname, '..', 'install.sh');

if (fs.existsSync(installScript)) {
  try {
    execFileSync('bash', [installScript], { stdio: 'inherit' });
  } catch (e) {
    console.error('Post-install setup failed. Run manually: bash install.sh');
  }
}
