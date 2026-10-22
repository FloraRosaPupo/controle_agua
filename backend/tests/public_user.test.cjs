const test = require('node:test');
const assert = require('node:assert/strict');
const { publicUser } = require('../dist/public_user.js');
test('registration response omits password hashes without mutating the database record', () => {
  const record={id:'1',name:'Flora',email:'test@example.com',password:'stored-hash',dailyGoal:2000};
  assert.deepEqual(publicUser(record),{id:'1',name:'Flora',email:'test@example.com',dailyGoal:2000});
  assert.equal(record.password,'stored-hash');
});
