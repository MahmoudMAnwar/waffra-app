'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {
  validateCloudRequest, makeOpenRouterBody,
  validateSuggestion, suggestFromBankSms,
} = require('../openrouter_sms_extractor.cjs');

const clean = 'Card Purchase Amount: SAR 75.00 at TEST FUEL';
const consent = {cloudConsent: true, redactedSms: clean};
const valid = {
  kind: 'expense', amount: 75, currency: 'SAR', merchant: 'TEST FUEL',
  fee: null, accountLast4: null, transactionDate: null, requiresReview: false,
};

test('M420: separate explicit cloud permission is mandatory', () => {
  assert.throws(() => validateCloudRequest({redactedSms: clean}), /NO_CLOUD_CONSENT/);
  assert.throws(() => validateCloudRequest({cloudConsent: false, redactedSms: clean}), /NO_CLOUD_CONSENT/);
  assert.equal(validateCloudRequest(consent), clean);
});

test('M420: unredacted identifiers and OTPs fail before remote transport', () => {
  for (const redactedSms of [
    'OTP 1234: Card Purchase Amount SAR 75.00',
    'Card Purchase Amount SAR 75.00 card 1234567812345678',
    'Card Purchase Amount SAR 75.00 from SA0380000000608010167519',
    'Your verification code for transfer is 123456',
  ]) assert.throws(
    () => validateCloudRequest({cloudConsent: true, redactedSms}),
  );
});

test('M420: request is JSON schema, ZDR, no data collection', () => {
  const body = makeOpenRouterBody(clean, 'test/structured-model-v1');
  assert.equal(body.provider.zdr, true);
  assert.equal(body.provider.data_collection, 'deny');
  assert.equal(body.provider.require_parameters, true);
  assert.equal(body.response_format.type, 'json_schema');
  assert.equal(body.response_format.json_schema.strict, true);
  assert.equal(body.messages.length, 2);
  assert.throws(() => makeOpenRouterBody(clean, '../invalid'));
});

test('M420: disabled service is fail closed and does not call provider', async () => {
  let called = 0;
  await assert.rejects(suggestFromBankSms({
    data: consent, apiKey: 'dummy', model: 'test/structured-model-v1',
    fetchFn: async () => {called++; throw new Error('should-not-run');},
  }), /CLOUD_SMS_DISABLED/);
  assert.equal(called, 0);
});

test('M420: mocked OpenRouter response is a suggestion, never a ledger write', async () => {
  let calls = 0;
  const suggestion = await suggestFromBankSms({
    data: consent, apiKey: 'dummy', model: 'test/structured-model-v1',
    enabled: true,
    fetchFn: async (_url, config) => {
      calls++;
      assert.match(config.headers.Authorization, /^Bearer /);
      assert.equal(JSON.parse(config.body).messages[1].content, clean);
      return {
        ok: true,
        json: async () => ({
          choices: [{message: {content: JSON.stringify(valid)}}],
        }),
      };
    },
  });
  assert.equal(calls, 1);
  assert.equal(suggestion.kind, 'expense');
  assert.equal(suggestion.amount, 75);
  assert.equal(suggestion.verifiedForPosting, false);
});

test('M420: transfers, card settlements and uncertain cannot be posted', () => {
  for (const kind of ['transfer', 'card_settlement', 'uncertain']) {
    const result = validateSuggestion({...valid, kind});
    assert.equal(result.requiresReview, true);
    assert.equal(result.verifiedForPosting, false);
  }
  assert.throws(() => validateSuggestion({...valid, amount: -75}));
  assert.throws(() => validateSuggestion({...valid, accountLast4: '12345678'}));
});

test('M420: network/model failures do not return invented transactions', async () => {
  await assert.rejects(suggestFromBankSms({
    data: consent, enabled: true, apiKey: 'dummy', model: 'test/structured-model-v1',
    fetchFn: async () => {throw new Error('external-secret');},
  }), /MODEL_UNAVAILABLE/);
});
