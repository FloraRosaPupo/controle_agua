const test = require('node:test');
const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const jwt = require('jsonwebtoken');
const { getJwtSecret } = require('../dist/config.js');

test('missing, short and example secrets fail with no secret disclosure', () => {
  for (const secret of [undefined, '', 'short-secret', 'replace-with-a-long-random-secret', ' ' + 'a'.repeat(32)]) {
    assert.throws(() => getJwtSecret({ JWT_SECRET: secret }), error => {
      assert.match(error.message, /Configure JWT_SECRET/);
      if (secret) assert.equal(error.message.includes(secret), false);
      return true;
    });
  }
});

test('rotating the configured key invalidates tokens signed with the old key', () => {
  const oldKey = getJwtSecret({ JWT_SECRET: randomBytes(32).toString('hex') });
  const newKey = getJwtSecret({ JWT_SECRET: randomBytes(32).toString('hex') });
  const token = jwt.sign({ userId: 'test-user' }, oldKey);
  assert.equal(jwt.verify(token, oldKey).userId, 'test-user');
  assert.throws(() => jwt.verify(token, newKey), /invalid signature/);
  const newToken = jwt.sign({ userId: 'test-user' }, newKey);
  assert.equal(jwt.verify(newToken, newKey).userId, 'test-user');
});
