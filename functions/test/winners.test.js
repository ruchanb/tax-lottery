const test = require('node:test');
const assert = require('node:assert/strict');
const { hashCoupon, normalizeCoupon, parseWinners } = require('../lib/winners');

test('normalizes coupon values consistently', () => {
  assert.equal(normalizeCoupon(' ab १२-3 '), 'AB१२-3');
  assert.equal(hashCoupon(' abc '), hashCoupon('ABC'));
});

test('parses nested winner API payload variants', () => {
  const winners = parseWinners({ data: { results: [{ coupon_number: 'IRD-42', prize_amount: 1000000, draw_date: '2026-08-16' }] } });
  assert.equal(winners.length, 1);
  assert.equal(winners[0].coupon, 'IRD-42');
  assert.equal(winners[0].prizeAmount, '1000000');
});
