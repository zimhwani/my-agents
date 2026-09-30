// The Gasguys WhatsApp bot: a small state machine over GasguysService. The WhatsApp webhook
// (supabase/functions/whatsapp-webhook) and the in-browser simulator both call `handleInbound`,
// so what you test in the simulator is what ships.

import { t, type StringKey } from "./i18n/index.ts";
import { formatKg, formatMoney, gramsFor, PRESETS_USD } from "./pricing.ts";
import type { OutMessage } from "./providers.ts";
import { formatMeterId, formatPhone, normalizeMeterId, normalizePhone, type GasguysService } from "./service.ts";
import type { Currency, Customer, Lang, PayMethod } from "./types.ts";

export type Inbound =
  | { type: "text"; text: string; profileName?: string }
  | { type: "button"; id: string; title?: string; profileName?: string };

type Draft = { meterId?: string; amount?: number; currency?: Currency; method?: PayMethod; payPhone?: string; gift?: boolean };

type Step =
  | "lang"
  | "menu"
  | "link_meter"
  | "buy_meter"
  | "buy_amount"
  | "buy_amount_other"
  | "buy_method"
  | "buy_confirm"
  | "buy_other_number"
  | "gift_meter"
  | "gift_confirm"
  | "refill_slot";

export type BotSession = { step: Step; draft: Draft };

const ZWG_PRESETS = [30, 60, 150];
const GREETINGS = /^(hi|hey|hello|menu|start|mhoro|makadii|sawubona|salibonani|0)$/i;

export async function handleInbound(svc: GasguysService, phone: string, msg: Inbound): Promise<OutMessage[]> {
  const store = svc.store;
  const session = ((await store.botSession(phone)) as BotSession | null) ?? { step: "menu", draft: {} };
  let customer = await store.customerByPhone(phone);
  const out: OutMessage[] = [];
  const save = (s: BotSession) => store.saveBotSession(phone, s);

  // First contact: language first, in all three languages at once.
  if (!customer) {
    if (msg.type === "button" && msg.id.startsWith("lang:")) {
      customer = await svc.ensureCustomer(phone, msg.id.slice(5) as Lang, msg.profileName ?? "");
      const tr = trFor(customer.lang);
      await save({ step: "link_meter", draft: {} });
      return [{ kind: "text", text: `${tr("welcome_title")} ✨\n${tr("welcome_body")}\n\n${tr("bot_link_prompt")}` }];
    }
    await save({ step: "lang", draft: {} });
    return [langPicker(`🔥 Gasguys\n${t("en", "welcome_body")}\n\n${t("en", "choose_language")} / ${t("sn", "choose_language")} / ${t("nd", "choose_language")}`)];
  }

  const tr = trFor(customer.lang);
  const id = msg.type === "button" ? msg.id : "";
  const text = msg.type === "text" ? msg.text.trim() : "";

  // Commands that work from anywhere in a conversation.
  if (GREETINGS.test(text) || id === "menu") return reply(await menu(svc, customer), { step: "menu", draft: {} });
  if (id.startsWith("lang:")) {
    customer = await svc.updateCustomer(customer, { lang: id.slice(5) as Lang });
    return reply(await menu(svc, customer), { step: "menu", draft: {} });
  }
  if (id === "language" || /^(language|mutauro|ulimi)$/i.test(text)) return reply([langPicker(tr("choose_language"))], session);
  if (id === "balance" || /^(balance|bal|gasi|igesi)$/i.test(text)) return reply(await balance(svc, customer), { step: "menu", draft: {} });
  if (id === "buy" || /^(buy|tenga|thenga)$/i.test(text)) return startBuy(svc, customer, save);
  if (id.startsWith("buy:")) {
    const meters = await store.metersFor(customer.id);
    if (!meters[0]) return reply([{ kind: "text", text: tr("bot_no_meter") + "\n" + tr("bot_link_prompt") }], { step: "link_meter", draft: {} });
    return reply([methodPicker(tr)], { step: "buy_method", draft: { meterId: meters[0].id, amount: Number(id.slice(4)), currency: "USD" } });
  }
  if (id === "gift" || /^(gift|chipo|isipho)$/i.test(text))
    return reply([{ kind: "text", text: `🎁 ${tr("gift_title")}\n${tr("gift_body")}\n\n${tr("recipient_meter")}:` }], { step: "gift_meter", draft: { gift: true } });
  if (id === "refill") return reply([slotPicker(tr)], { step: "refill_slot", draft: {} });
  if (id === "history") return reply(await history(svc, customer), { step: "menu", draft: {} });
  if (id === "agent") return reply([{ kind: "text", text: tr("bot_agent_soon") }], { step: "menu", draft: {} });
  if (id === "safe") return reply([{ kind: "text", text: `🙏 ${tr("bot_safe_thanks")}` }], { step: "menu", draft: {} });
  if (id === "cancel") return reply(await menu(svc, customer), { step: "menu", draft: {} });

  const d = session.draft;
  switch (session.step) {
    case "link_meter": {
      const meterId = normalizeMeterId(text);
      if (meterId.length !== 11) return reply([{ kind: "text", text: tr("bot_link_prompt") }], session);
      const res = await svc.linkMeter(customer.id, meterId);
      if (!res.ok) return reply([{ kind: "text", text: `${tr(res.error === "meter_taken" ? "meter_taken" : "meter_not_found")}\n${tr("bot_link_prompt")}` }], session);
      out.push({ kind: "text", text: `✅ ${tr("meter_linked", { meter: formatMeterId(meterId) })}` });
      out.push(...(await balance(svc, customer)));
      return reply(out, { step: "menu", draft: {} });
    }
    case "buy_meter": {
      if (!id.startsWith("meter:")) break;
      return reply([amountPicker(svc, tr)], { step: "buy_amount", draft: { ...d, meterId: id.slice(6) } });
    }
    case "buy_amount": {
      if (id === "amt:other") return reply([{ kind: "text", text: tr("bot_type_amount") }], { ...session, step: "buy_amount_other" });
      const m = /^amt:(USD|ZWG):([\d.]+)$/.exec(id);
      if (!m) break;
      return reply([methodPicker(tr)], { step: "buy_method", draft: { ...d, currency: m[1] as Currency, amount: Number(m[2]) } });
    }
    case "buy_amount_other": {
      const m = /^(zig|zwg)?\s*\$?\s*([\d.]+)\s*(zig|zwg)?$/i.exec(text);
      if (!m) return reply([{ kind: "text", text: tr("bot_type_amount") }], session);
      const currency: Currency = m[1] || m[3] ? "ZWG" : "USD";
      return reply([methodPicker(tr)], { step: "buy_method", draft: { ...d, currency, amount: Number(m[2]) } });
    }
    case "buy_method": {
      if (!id.startsWith("pay:")) break;
      const method = id.slice(4) as PayMethod;
      const draft = { ...d, method, payPhone: phone };
      if (method !== "ecocash") return reply(await pay(svc, customer, phone, draft), { step: "menu", draft: {} });
      const amount = formatMoney(draft.amount!, draft.currency!);
      return reply(
        [
          {
            kind: "buttons",
            text: `${tr("review_title")}\n${tr("review_summary", { amount, meter: formatMeterId(draft.meterId!) })}\n${tr("pay_number")}: ${formatPhone(phone)}\n${tr("fee_none")} ✓`,
            buttons: [
              { id: "confirm", title: tr("btn_confirm") },
              { id: "other_number", title: short(tr("pay_number")) },
              { id: "cancel", title: tr("btn_cancel") },
            ],
          },
        ],
        { step: "buy_confirm", draft },
      );
    }
    case "buy_confirm": {
      if (id === "other_number") return reply([{ kind: "text", text: `${tr("pay_number")}? (${tr("phone_hint")})` }], { ...session, step: "buy_other_number" });
      if (id !== "confirm") break;
      return reply(await pay(svc, customer, d.payPhone ?? phone, d), { step: "menu", draft: {} });
    }
    case "buy_other_number": {
      const p = normalizePhone(text);
      if (!p) return reply([{ kind: "text", text: tr("err_invalid_phone") }], session);
      return reply(await pay(svc, customer, p, d), { step: "menu", draft: {} });
    }
    case "gift_meter": {
      const meterId = normalizeMeterId(text);
      const found = meterId.length === 11 ? await svc.giftLookup(meterId) : null;
      if (!found) return reply([{ kind: "text", text: `${tr("meter_not_found")}\n${tr("recipient_meter")}:` }], session);
      return reply(
        [
          {
            kind: "buttons",
            text: `${tr("recipient_name_check", { name: `${found.name} (${found.suburb})` })}`,
            buttons: [
              { id: "yes", title: tr("yes") },
              { id: "no", title: tr("no") },
            ],
          },
        ],
        { step: "gift_confirm", draft: { ...d, meterId: found.meterId, gift: true } },
      );
    }
    case "gift_confirm": {
      if (id === "no") return reply([{ kind: "text", text: `${tr("recipient_meter")}:` }], { ...session, step: "gift_meter" });
      if (id !== "yes") break;
      return reply([amountPicker(svc, tr)], { ...session, step: "buy_amount" });
    }
    case "refill_slot": {
      if (!id.startsWith("slot:")) break;
      const meters = await store.metersFor(customer.id);
      if (!meters[0]) return reply([{ kind: "text", text: tr("bot_no_meter") }], { step: "menu", draft: {} });
      await svc.requestRefill(meters[0].id, tr(id.slice(5) as StringKey));
      return reply(
        [{ kind: "buttons", text: `🛢️ ${tr("refill_requested", { phone: formatPhone(phone) })}`, buttons: [{ id: "menu", title: tr("bot_menu_button") }] }],
        { step: "menu", draft: {} },
      );
    }
  }

  // Nothing matched: say so, and put the menu back in reach.
  return reply([{ kind: "text", text: tr("bot_didnt_understand") }, ...(await menu(svc, customer))], { step: "menu", draft: {} });

  async function reply(messages: OutMessage[], next: BotSession) {
    await save(next);
    return messages;
  }
}

// ── Screens ─────────────────────────────────────────────────────────────────────────────────────

type Tr = (k: StringKey, v?: Record<string, string | number>) => string;
const trFor = (lang: Lang): Tr => (k, v) => t(lang, k, v);
const short = (s: string) => (s.length <= 20 ? s : s.slice(0, 19) + "…");

function langPicker(text: string): OutMessage {
  return {
    kind: "buttons",
    text,
    buttons: [
      { id: "lang:en", title: "English" },
      { id: "lang:sn", title: "chiShona" },
      { id: "lang:nd", title: "isiNdebele" },
    ],
  };
}

async function menu(svc: GasguysService, c: Customer): Promise<OutMessage[]> {
  const tr = trFor(c.lang);
  const meters = await svc.store.metersFor(c.id);
  const head = meters[0]
    ? `${tr("greeting", { name: c.name || "" }).trim()} 👋\n🔥 ${tr("gas_remaining")}: ${formatKg(Math.min(meters[0].creditGrams, meters[0].gasGrams))} · ${tr("days_left", { days: svc.daysLeft(meters[0]) })}`
    : `${tr("greeting", { name: c.name || "" }).trim()} 👋`;
  return [
    {
      kind: "list",
      text: `${head}\n\n${tr("bot_menu_prompt")}`,
      button: tr("bot_menu_button"),
      rows: [
        { id: "balance", title: short(tr("bot_check_balance")) },
        { id: "buy", title: short(tr("bot_buy")) },
        { id: "gift", title: short(tr("nav_gift")), description: short(tr("gift_title")) },
        { id: "refill", title: short(tr("refill_title")) },
        { id: "history", title: short(tr("nav_history")) },
        { id: "language", title: short(tr("language")) },
        { id: "agent", title: short(tr("bot_talk_agent")) },
      ],
    },
  ];
}

async function balance(svc: GasguysService, c: Customer): Promise<OutMessage[]> {
  const tr = trFor(c.lang);
  const meters = await svc.store.metersFor(c.id);
  if (!meters.length) return [{ kind: "text", text: tr("bot_no_meter") + "\n" + tr("bot_link_prompt") }];
  return meters.map((m) => ({
    kind: "buttons" as const,
    text: [
      `🏠 ${tr("meter_label")} ${formatMeterId(m.id)} · ${m.suburb}`,
      `${tr("credit_balance")}: ${formatKg(m.creditGrams)}`,
      `${tr("gas_remaining")}: ${formatKg(m.gasGrams)} / ${m.cylinderKg} kg`,
      svc.daysLeft(m) === 1 ? tr("days_left_one") : tr("days_left", { days: svc.daysLeft(m) }),
      m.leak ? `⚠️ ${tr("leak_title")}` : m.valve === "open" ? `🟢 ${tr("valve_open")}` : `⚪ ${tr("valve_closed_no_credit")}`,
    ].join("\n"),
    buttons: [
      { id: "buy", title: short(tr("bot_buy")) },
      { id: "refill", title: short(tr("refill_title")) },
      { id: "menu", title: short(tr("bot_menu_button")) },
    ],
  }));
}

async function history(svc: GasguysService, c: Customer): Promise<OutMessage[]> {
  const tr = trFor(c.lang);
  const list = (await svc.store.paymentsFor({ customerId: c.id, limit: 5 })).filter((p) => p.status === "paid");
  if (!list.length) return [{ kind: "text", text: tr("history_empty") }];
  const lines = list.map((p) => {
    const day = p.createdAt.slice(0, 10);
    return `• ${day} ${tr("history_purchase", { kg: (p.grams / 1000).toFixed(2), amount: formatMoney(p.amount, p.currency) })} · ${p.reference}`;
  });
  return [{ kind: "text", text: `🧾 ${tr("history_title")}\n${lines.join("\n")}` }];
}

async function startBuy(svc: GasguysService, c: Customer, save: (s: BotSession) => Promise<void>): Promise<OutMessage[]> {
  const tr = trFor(c.lang);
  const meters = await svc.store.metersFor(c.id);
  if (!meters.length) {
    await save({ step: "link_meter", draft: {} });
    return [{ kind: "text", text: tr("bot_no_meter") + "\n" + tr("bot_link_prompt") }];
  }
  if (meters.length > 1) {
    await save({ step: "buy_meter", draft: {} });
    return [
      {
        kind: "list",
        text: tr("bot_choose_meter"),
        button: tr("bot_choose_meter"),
        rows: meters.slice(0, 10).map((m) => ({ id: `meter:${m.id}`, title: formatMeterId(m.id), description: m.suburb })),
      },
    ];
  }
  await save({ step: "buy_amount", draft: { meterId: meters[0].id } });
  return [amountPicker(svc, tr)];
}

function amountPicker(svc: GasguysService, tr: Tr): OutMessage {
  const rows = [
    ...PRESETS_USD.map((a) => ({ id: `amt:USD:${a}`, title: formatMoney(a, "USD"), description: `≈ ${formatKg(gramsFor(a, "USD", svc.tariff))}` })),
    ...ZWG_PRESETS.map((a) => ({ id: `amt:ZWG:${a}`, title: formatMoney(a, "ZWG"), description: `≈ ${formatKg(gramsFor(a, "ZWG", svc.tariff))}` })),
    { id: "amt:other", title: short(tr("amount_other")) },
  ];
  return { kind: "list", text: `🔥 ${tr("buy_title")}\n${tr("fee_none")}`, button: short(tr("amount")), rows };
}

function methodPicker(tr: Tr): OutMessage {
  return {
    kind: "buttons",
    text: tr("pay_with"),
    buttons: [
      { id: "pay:ecocash", title: "EcoCash" },
      { id: "pay:innbucks", title: "InnBucks" },
      { id: "pay:card", title: "Card / Kadhi" },
    ],
  };
}

function slotPicker(tr: Tr): OutMessage {
  return {
    kind: "buttons",
    text: `🛢️ ${tr("refill_title")}\n${tr("refill_when")}`,
    buttons: [
      { id: "slot:refill_slot_today_pm", title: short(tr("refill_slot_today_pm")) },
      { id: "slot:refill_slot_tomorrow_am", title: short(tr("refill_slot_tomorrow_am")) },
      { id: "slot:refill_slot_tomorrow_pm", title: short(tr("refill_slot_tomorrow_pm")) },
    ],
  };
}

async function pay(svc: GasguysService, c: Customer, payPhone: string, d: Draft): Promise<OutMessage[]> {
  const tr = trFor(c.lang);
  const res = await svc.startPurchase({
    meterId: d.meterId!,
    amount: d.amount!,
    currency: d.currency ?? "USD",
    method: d.method ?? "ecocash",
    payerPhone: payPhone,
    payerName: c.name,
    payerCustomerId: c.id,
    channel: "whatsapp",
  });
  if (!res.ok) {
    const key: StringKey = res.error === "amount_too_small" ? "err_amount_min" : res.error === "meter_not_found" ? "meter_not_found" : "err_generic";
    return [{ kind: "text", text: tr(key, { amount: formatMoney(svc.tariff.minUsd, "USD") }) }];
  }
  const ins = res.instruction;
  const kg = formatKg(res.payment.grams);
  const head = `${tr("review_summary", { amount: formatMoney(res.payment.amount, res.payment.currency), meter: formatMeterId(res.payment.meterId) })} (≈ ${kg})`;
  if (ins.kind === "ussd_push") return [{ kind: "text", text: `${head}\n📲 ${tr("confirm_on_phone")}\n${tr("receipt_ref", { ref: res.payment.reference })}` }];
  if (ins.kind === "code") return [{ kind: "text", text: `${head}\n${tr("innbucks_code", { code: ins.code })}` }];
  return [{ kind: "text", text: `${head}\n💳 ${tr("bot_card_link", { url: ins.url })}` }];
}
