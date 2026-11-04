'use strict';

// M420 candidate. This is a SERVER-ONLY OpenRouter adapter, not a public
// callable route and not connected to production. All outputs are suggestions.
// NEVER put the OpenRouter key in Flutter, APK, CI or device preferences.
const ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions';
const DIRECTIONS = ['income', 'expense', 'transfer', 'card_settlement', 'uncertain'];
const SMS_SCHEMA = {
  name: 'waffra_sms_facts_v1',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    properties: {
      kind: {type: 'string', enum: DIRECTIONS},
      amount: {type: ['number', 'null']},
      currency: {type: ['string', 'null']},
      merchant: {type: ['string', 'null']},
      fee: {type: ['number', 'null']},
      accountLast4: {type: ['string', 'null']},
      transactionDate: {type: ['string', 'null']},
      requiresReview: {type: 'boolean'},
    },
    required: ['kind', 'amount', 'currency', 'merchant', 'fee',
      'accountLast4', 'transactionDate', 'requiresReview'],
  },
};

function validateCloudRequest(data) {
  if (!data || data.cloudConsent !== true ||
    typeof data.redactedSms !== 'string') throw new Error('NO_CLOUD_CONSENT');
  const message = data.redactedSms.trim();
  if (message.length < 18 || message.length > 1600) throw new Error('INVALID_SMS');
  if (/\b(?:OTP|one.time.pass|verification.code|password|security.code)\b/i.test(message) ||
      /رمز\s*(?:التحقق|التفعيل|الدخول|المرور)/u.test(message)) {
    throw new Error('SENSITIVE_SMS');
  }
  // Reject cleartext phone numbers, PANs, IBANs, and raw references; the
  // caller is responsible for *local* redaction. Do not log rejected text.
  if (/\b(?:\+?\d[\d -]{8,}\d)\b/.test(message) ||
      /\b[A-Z]{2}\d{2}[A-Z0-9]{10,}\b/i.test(message)) {
    throw new Error('UNREDACTED_IDENTIFIER');
  }
  if (!/(?:SAR|SR|AED|JOD|EGP|ريال|جنيه|درهم|دينار)/i.test(message) ||
      !/(?:purchase|debited|credited|transfer|refund|salary|withdraw|deposit|payment|شراء|خصم|حوالة|تحويل|راتب|سحب|إيداع)/i.test(message)) {
    throw new Error('NOT_FINANCIAL_SMS');
  }
  return message;
}

function makeOpenRouterBody(message, model) {
  if (typeof model !== 'string' || !/^[a-z0-9][a-z0-9_-]*\/[a-zA-Z0-9._:-]+$/.test(model)) {
    throw new Error('MODEL_NOT_CONFIGURED');
  }
  return {
    model,
    temperature: 0,
    max_tokens: 350,
    provider: {zdr: true, data_collection: 'deny', require_parameters: true},
    response_format: {type: 'json_schema', json_schema: SMS_SCHEMA},
    messages: [
      {role: 'system', content: 'Extract Saudi bank SMS facts only. No account creation, no direct financial writes, no guesses. If the amount, direction or status is uncertain, set requiresReview true. Transfers and card settlements must not be converted into purchases.'},
      {role: 'user', content: message},
    ],
  };
}

function validateSuggestion(suggestion) {
  if (!suggestion || typeof suggestion !== 'object' || Array.isArray(suggestion)) {
    throw new Error('BAD_LLM_RESPONSE');
  }
  if (!DIRECTIONS.includes(suggestion.kind) ||
    typeof suggestion.requiresReview !== 'boolean') throw new Error('BAD_LLM_RESPONSE');
  const moneyOk = (n) => n === null || (typeof n === 'number' && Number.isFinite(n) &&
      n >= 0 && n < 100000000 && Math.abs(n * 100 - Math.round(n * 100)) < 0.00001);
  if (!moneyOk(suggestion.amount) || !moneyOk(suggestion.fee)) {
    throw new Error('BAD_LLM_AMOUNT');
  }
  if (suggestion.currency !== null &&
    (typeof suggestion.currency !== 'string' ||
      !/^[A-Z]{3}$/.test(suggestion.currency))) throw new Error('BAD_LLM_CURRENCY');
  if (suggestion.accountLast4 !== null &&
      (typeof suggestion.accountLast4 !== 'string' ||
       !/^\d{4}$/.test(suggestion.accountLast4))) throw new Error('BAD_LLM_ACCOUNT');
  if (suggestion.merchant !== null &&
      (typeof suggestion.merchant !== 'string' || suggestion.merchant.length > 90)) {
    throw new Error('BAD_LLM_MERCHANT');
  }
  if (suggestion.transactionDate !== null &&
      (typeof suggestion.transactionDate !== 'string' ||
       suggestion.transactionDate.length > 40)) throw new Error('BAD_LLM_DATE');
  // The model does not get bank ownership proof. All account movements need
  // reconciliation before they may affect the balance sheet.
  const requiresReview = suggestion.requiresReview ||
    !Number.isFinite(suggestion.amount) || suggestion.amount <= 0 ||
    suggestion.kind === 'transfer' || suggestion.kind === 'card_settlement' ||
    suggestion.kind === 'uncertain';
  return {
    kind: suggestion.kind,
    amount: suggestion.amount,
    currency: suggestion.currency,
    merchant: suggestion.merchant,
    fee: suggestion.fee,
    accountLast4: suggestion.accountLast4,
    transactionDate: suggestion.transactionDate,
    requiresReview: !!requiresReview,
    // Explicitly prohibit ledger use without separate local source matching.
    verifiedForPosting: false,
  };
}

async function suggestFromBankSms({
  data, model, apiKey, enabled = false, fetchFn = globalThis.fetch,
}) {
  if (!enabled) throw new Error('CLOUD_SMS_DISABLED');
  if (!apiKey || typeof apiKey !== 'string') throw new Error('MISSING_SERVER_SECRET');
  const text = validateCloudRequest(data);
  const payload = makeOpenRouterBody(text, model);
  if (typeof fetchFn !== 'function') throw new Error('NO_FETCH');
  let response;
  try {
    response = await fetchFn(ENDPOINT, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + apiKey,
        'Content-Type': 'application/json',
        'X-Title': 'Waffra Secure SMS Extraction',
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(12000),
    });
  } catch (_) { throw new Error('MODEL_UNAVAILABLE'); }
  if (!response || !response.ok) throw new Error('MODEL_UNAVAILABLE');
  let suggestion;
  try {
    const parsed = await response.json();
    const raw = parsed.choices?.[0]?.message?.content;
    if (typeof raw !== 'string' || raw.length > 12000) throw new Error('BAD_LLM_RESPONSE');
    suggestion = JSON.parse(raw);
  } catch (_) { throw new Error('BAD_LLM_RESPONSE'); }
  return validateSuggestion(suggestion);
}

module.exports = {
  SMS_SCHEMA, validateCloudRequest, makeOpenRouterBody,
  validateSuggestion, suggestFromBankSms,
};
