// ===== EMBEDDED RATE DATA - April 2026 =====
// Sources: Canstar, Finder, Money.com.au, Savings.com.au, InfoChoice, RatePilot

const DATA = {
  cashRate: 4.10,
  updated: "14 Apr 2026",
  cashHistory: [
    {d:"Jan 24",r:4.35},{d:"Dec 24",r:4.35},{d:"Feb 25",r:4.10},
    {d:"May 25",r:3.85},{d:"Aug 25",r:3.60},{d:"Feb 26",r:3.85},{d:"Mar 26",r:4.10}
  ],

  // ========== TERM DEPOSITS ==========
  td: {
    terms: ["3m","6m","12m","24m","36m","60m"],
    termLabels: {"3m":"3 Months","6m":"6 Months","12m":"12 Months","24m":"24 Months","36m":"3 Years","60m":"5 Years"},
    banks: [
      {n:"Bank First",t:"Mutual",hl:true,min:500,r:{"3m":4.50,"6m":4.75,"12m":4.85,"24m":4.90,"36m":4.95,"60m":5.00}},
      // Big 4
      {n:"CommBank",t:"Big 4",hl:false,min:5000,r:{"3m":4.25,"6m":4.55,"12m":5.10,"24m":4.60,"36m":4.50,"60m":4.40}},
      {n:"ANZ",t:"Big 4",hl:false,min:5000,r:{"3m":4.15,"6m":4.50,"12m":5.00,"24m":4.55,"36m":4.40,"60m":4.30}},
      {n:"NAB",t:"Big 4",hl:false,min:5000,r:{"3m":4.20,"6m":4.55,"12m":4.80,"24m":4.55,"36m":4.45,"60m":4.35}},
      {n:"Westpac",t:"Big 4",hl:false,min:5000,r:{"3m":4.15,"6m":4.50,"12m":4.75,"24m":4.80,"36m":4.45,"60m":4.35}},
      // Challengers
      {n:"Judo Bank",t:"Challenger",hl:false,min:1000,r:{"3m":4.60,"6m":5.00,"12m":5.35,"24m":5.40,"36m":5.20,"60m":5.10}},
      {n:"Macquarie",t:"Challenger",hl:false,min:10000,r:{"3m":4.50,"6m":4.70,"12m":4.85,"24m":4.80,"36m":4.70,"60m":4.55}},
      {n:"ING",t:"Challenger",hl:false,min:10000,r:{"3m":4.30,"6m":4.60,"12m":4.80,"24m":4.70,"36m":4.55,"60m":4.40}},
      {n:"Rabobank",t:"Challenger",hl:false,min:20000,r:{"3m":4.55,"6m":4.85,"12m":5.10,"24m":5.25,"36m":5.40,"60m":5.70}},
      {n:"ME Bank",t:"Challenger",hl:false,min:1000,r:{"3m":4.80,"6m":4.70,"12m":4.80,"24m":4.75,"36m":4.60,"60m":4.50}},
      {n:"AMP",t:"Challenger",hl:false,min:5000,r:{"3m":4.45,"6m":4.75,"12m":4.90,"24m":4.85,"36m":4.70,"60m":4.55}},
      {n:"UBank",t:"Neobank",hl:false,min:1000,r:{"3m":4.40,"6m":4.65,"12m":4.85,"24m":4.80,"36m":4.65,"60m":4.50}},
      // Mutuals & Regionals
      {n:"Great Southern",t:"Mutual",hl:false,min:5000,r:{"3m":4.50,"6m":4.85,"12m":5.20,"24m":5.35,"36m":5.45,"60m":5.60}},
      {n:"Bank Australia",t:"Mutual",hl:false,min:5000,r:{"3m":4.70,"6m":5.05,"12m":4.95,"24m":4.85,"36m":4.70,"60m":4.55}},
      {n:"Heritage Bank",t:"Mutual",hl:false,min:2000,r:{"3m":4.40,"6m":4.65,"12m":4.85,"24m":4.80,"36m":4.65,"60m":4.50}},
      {n:"Gateway Bank",t:"Mutual",hl:false,min:5000,r:{"3m":4.55,"6m":4.90,"12m":5.45,"24m":5.20,"36m":5.00,"60m":4.85}},
      {n:"Community First",t:"Credit Union",hl:false,min:5000,r:{"3m":4.50,"6m":4.85,"12m":5.40,"24m":5.15,"36m":4.95,"60m":4.80}},
      {n:"Bendigo Bank",t:"Regional",hl:false,min:1000,r:{"3m":4.25,"6m":4.55,"12m":4.75,"24m":4.70,"36m":4.55,"60m":4.40}},
      {n:"BOQ",t:"Regional",hl:false,min:2000,r:{"3m":4.30,"6m":4.60,"12m":4.80,"24m":4.75,"36m":4.60,"60m":4.45}},
      {n:"Suncorp",t:"Regional",hl:false,min:5000,r:{"3m":4.35,"6m":4.60,"12m":4.85,"24m":4.75,"36m":4.60,"60m":4.45}},
    ]
  },

  // ========== HOME LOANS (Owner Occ, P&I, <80% LVR) ==========
  hl: {
    terms: ["var","1y","2y","3y","5y"],
    termLabels: {"var":"Variable","1y":"1 Yr Fixed","2y":"2 Yr Fixed","3y":"3 Yr Fixed","5y":"5 Yr Fixed"},
    banks: [
      {n:"Bank First",t:"Mutual",hl:true,r:{"var":5.89,"1y":5.79,"2y":5.69,"3y":5.74,"5y":5.89}},
      // Big 4
      {n:"CommBank",t:"Big 4",hl:false,r:{"var":6.34,"1y":5.89,"2y":5.89,"3y":5.99,"5y":6.24}},
      {n:"ANZ",t:"Big 4",hl:false,r:{"var":6.29,"1y":5.84,"2y":5.84,"3y":5.94,"5y":6.19}},
      {n:"NAB",t:"Big 4",hl:false,r:{"var":6.24,"1y":5.74,"2y":5.84,"3y":5.94,"5y":6.24}},
      {n:"Westpac",t:"Big 4",hl:false,r:{"var":5.49,"1y":5.79,"2y":5.89,"3y":5.99,"5y":6.29}},
      // Challengers / Tier 2
      {n:"Judo Bank",t:"Challenger",hl:false,r:{"var":5.69,"1y":5.59,"2y":5.64,"3y":5.74,"5y":5.99}},
      {n:"Macquarie",t:"Challenger",hl:false,r:{"var":5.75,"1y":5.69,"2y":5.74,"3y":5.79,"5y":6.09}},
      {n:"ING",t:"Challenger",hl:false,r:{"var":5.69,"1y":5.74,"2y":5.79,"3y":5.84,"5y":6.14}},
      {n:"ME Bank",t:"Challenger",hl:false,r:{"var":5.79,"1y":5.69,"2y":5.74,"3y":5.84,"5y":6.09}},
      {n:"AMP",t:"Challenger",hl:false,r:{"var":5.74,"1y":5.69,"2y":5.74,"3y":5.84,"5y":6.09}},
      {n:"UBank",t:"Neobank",hl:false,r:{"var":5.59,"1y":5.64,"2y":5.69,"3y":5.79,"5y":6.04}},
      {n:"Athena",t:"Neobank",hl:false,r:{"var":5.48,"1y":null,"2y":null,"3y":null,"5y":null}},
      {n:"loans.com.au",t:"Neobank",hl:false,r:{"var":5.49,"1y":5.59,"2y":5.64,"3y":5.74,"5y":5.99}},
      // Mutuals & Regionals
      {n:"Great Southern",t:"Mutual",hl:false,r:{"var":5.79,"1y":5.69,"2y":5.74,"3y":5.84,"5y":6.09}},
      {n:"Bank Australia",t:"Mutual",hl:false,r:{"var":5.84,"1y":5.74,"2y":5.79,"3y":5.89,"5y":6.14}},
      {n:"Heritage Bank",t:"Mutual",hl:false,r:{"var":5.84,"1y":5.74,"2y":5.79,"3y":5.84,"5y":6.09}},
      {n:"Bendigo Bank",t:"Regional",hl:false,r:{"var":5.99,"1y":5.79,"2y":5.84,"3y":5.94,"5y":6.19}},
      {n:"BOQ",t:"Regional",hl:false,r:{"var":5.94,"1y":5.79,"2y":5.84,"3y":5.89,"5y":6.14}},
      {n:"Suncorp",t:"Regional",hl:false,r:{"var":5.89,"1y":5.74,"2y":5.79,"3y":5.89,"5y":6.14}},
      {n:"Gateway Bank",t:"Mutual",hl:false,r:{"var":5.79,"1y":5.69,"2y":5.74,"3y":5.84,"5y":6.09}},
    ]
  },

  // ========== SAVINGS ACCOUNTS ==========
  sa: {
    terms: ["base","bonus","intro","max"],
    termLabels: {"base":"Base Rate","bonus":"Bonus Rate","intro":"Intro Rate","max":"Max Total"},
    banks: [
      {n:"Bank First",t:"Mutual",hl:true,prod:"Online Saver",cond:"$2k+ balance",r:{"base":1.50,"bonus":3.30,"intro":null,"max":4.80}},
      // Big 4
      {n:"CommBank",t:"Big 4",hl:false,prod:"NetBank Saver",cond:"Intro 5 months",r:{"base":1.95,"bonus":3.00,"intro":4.95,"max":4.95}},
      {n:"ANZ",t:"Big 4",hl:false,prod:"Plus Save",cond:"Grow $100/mo",r:{"base":0.10,"bonus":4.65,"intro":null,"max":4.75}},
      {n:"NAB",t:"Big 4",hl:false,prod:"iSaver",cond:"Intro 4 months",r:{"base":1.55,"bonus":null,"intro":4.95,"max":4.95}},
      {n:"Westpac",t:"Big 4",hl:false,prod:"Life (18-29)",cond:"Grow bal + 20 purchases",r:{"base":0.50,"bonus":5.00,"intro":null,"max":5.50}},
      // Challengers
      {n:"ING",t:"Challenger",hl:false,prod:"Savings Maximiser",cond:"Deposit $1k/mo + 5 purchases",r:{"base":0.01,"bonus":5.24,"intro":null,"max":5.25}},
      {n:"Macquarie",t:"Challenger",hl:false,prod:"Savings Account",cond:"No conditions",r:{"base":4.70,"bonus":null,"intro":null,"max":4.70}},
      {n:"Rabobank",t:"Challenger",hl:false,prod:"High Interest",cond:"Intro 4 months",r:{"base":3.95,"bonus":null,"intro":5.65,"max":5.65}},
      {n:"ME Bank",t:"Challenger",hl:false,prod:"Online Savings",cond:"Deposit $200/mo",r:{"base":1.10,"bonus":3.90,"intro":null,"max":5.00}},
      {n:"AMP",t:"Challenger",hl:false,prod:"GO Save",cond:"No conditions",r:{"base":4.85,"bonus":null,"intro":null,"max":4.85}},
      {n:"UBank",t:"Neobank",hl:false,prod:"Save",cond:"Intro 4 months",r:{"base":4.35,"bonus":null,"intro":5.60,"max":5.60}},
      {n:"Judo Bank",t:"Challenger",hl:false,prod:"Term Only",cond:"N/A",r:{"base":null,"bonus":null,"intro":null,"max":null}},
      // Mutuals & Regionals
      {n:"Great Southern",t:"Mutual",hl:false,prod:"Growth Saver",cond:"No withdrawals/mo",r:{"base":1.20,"bonus":3.60,"intro":null,"max":4.80}},
      {n:"Bank Australia",t:"Mutual",hl:false,prod:"Online Saver",cond:"No conditions",r:{"base":4.50,"bonus":null,"intro":null,"max":4.50}},
      {n:"Heritage Bank",t:"Mutual",hl:false,prod:"Online Saver",cond:"Deposit $20/mo",r:{"base":0.90,"bonus":4.00,"intro":null,"max":4.90}},
      {n:"Bendigo Bank",t:"Regional",hl:false,prod:"Reward Saver",cond:"Deposit $200/mo",r:{"base":1.25,"bonus":3.50,"intro":null,"max":4.75}},
      {n:"BOQ",t:"Regional",hl:false,prod:"Future Saver",cond:"Deposit/mo",r:{"base":1.40,"bonus":3.40,"intro":null,"max":4.80}},
      {n:"Suncorp",t:"Regional",hl:false,prod:"Growth Saver",cond:"No withdrawals",r:{"base":1.30,"bonus":3.55,"intro":null,"max":4.85}},
      {n:"Gateway Bank",t:"Mutual",hl:false,prod:"Savings Max",cond:"No conditions",r:{"base":4.55,"bonus":null,"intro":null,"max":4.55}},
      {n:"Community First",t:"Credit Union",hl:false,prod:"Growth Saver",cond:"Deposit $200/mo",r:{"base":1.10,"bonus":3.80,"intro":null,"max":4.90}},
    ]
  }
};
