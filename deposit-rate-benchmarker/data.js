// ===== EMBEDDED RATE DATA - May 2026 =====
// Sources: Canstar, Finder, Money.com.au, Savings.com.au, InfoChoice, RatePilot

const DATA = {
  cashRate: 4.35,
  updated: "27 May 2026",
  cashHistory: [
    {d:"Jan 24",r:4.35},{d:"Dec 24",r:4.35},{d:"Feb 25",r:4.10},
    {d:"May 25",r:3.85},{d:"Aug 25",r:3.60},{d:"Feb 26",r:3.85},{d:"Mar 26",r:4.10},{d:"May 26",r:4.35}
  ],

  // ========== TERM DEPOSITS ==========
  td: {
    terms: ["3m","6m","12m","24m","36m","60m"],
    termLabels: {"3m":"3 Months","6m":"6 Months","12m":"12 Months","24m":"24 Months","36m":"3 Years","60m":"5 Years"},
    banks: [
      {n:"Bank First",t:"Mutual",hl:true,min:500,r:{"3m":4.75,"6m":5.00,"12m":5.10,"24m":5.15,"36m":5.15,"60m":5.15}},
      // Big 4
      {n:"CommBank",t:"Big 4",hl:false,min:5000,r:{"3m":4.50,"6m":4.80,"12m":5.35,"24m":4.80,"36m":4.65,"60m":4.55}},
      {n:"ANZ",t:"Big 4",hl:false,min:5000,r:{"3m":4.40,"6m":4.75,"12m":5.25,"24m":4.75,"36m":4.55,"60m":4.45}},
      {n:"NAB",t:"Big 4",hl:false,min:5000,r:{"3m":4.45,"6m":4.80,"12m":5.05,"24m":4.75,"36m":4.60,"60m":4.50}},
      {n:"Westpac",t:"Big 4",hl:false,min:5000,r:{"3m":4.40,"6m":4.75,"12m":5.00,"24m":5.00,"36m":4.60,"60m":4.50}},
      // Challengers
      {n:"Judo Bank",t:"Challenger",hl:false,min:1000,r:{"3m":4.85,"6m":5.25,"12m":5.55,"24m":5.60,"36m":5.35,"60m":5.25}},
      {n:"Macquarie",t:"Challenger",hl:false,min:10000,r:{"3m":4.75,"6m":4.95,"12m":5.10,"24m":5.00,"36m":4.85,"60m":4.70}},
      {n:"ING",t:"Challenger",hl:false,min:10000,r:{"3m":4.55,"6m":4.85,"12m":5.05,"24m":4.90,"36m":4.70,"60m":4.55}},
      {n:"Rabobank",t:"Challenger",hl:false,min:20000,r:{"3m":4.80,"6m":5.10,"12m":5.35,"24m":5.45,"36m":5.55,"60m":5.80}},
      {n:"ME Bank",t:"Challenger",hl:false,min:1000,r:{"3m":5.05,"6m":4.95,"12m":5.05,"24m":4.95,"36m":4.75,"60m":4.65}},
      {n:"AMP",t:"Challenger",hl:false,min:5000,r:{"3m":4.70,"6m":5.00,"12m":5.15,"24m":5.05,"36m":4.85,"60m":4.70}},
      {n:"UBank",t:"Neobank",hl:false,min:1000,r:{"3m":4.65,"6m":4.90,"12m":5.10,"24m":5.00,"36m":4.80,"60m":4.65}},
      // Mutuals & Regionals
      {n:"Great Southern",t:"Mutual",hl:false,min:5000,r:{"3m":4.75,"6m":5.10,"12m":5.45,"24m":5.55,"36m":5.60,"60m":5.70}},
      {n:"Bank Australia",t:"Mutual",hl:false,min:5000,r:{"3m":4.95,"6m":5.30,"12m":5.20,"24m":5.05,"36m":4.85,"60m":4.70}},
      {n:"Heritage Bank",t:"Mutual",hl:false,min:2000,r:{"3m":4.65,"6m":4.90,"12m":5.10,"24m":5.00,"36m":4.80,"60m":4.65}},
      {n:"Gateway Bank",t:"Mutual",hl:false,min:5000,r:{"3m":4.80,"6m":5.15,"12m":5.65,"24m":5.40,"36m":5.15,"60m":5.00}},
      {n:"Community First",t:"Credit Union",hl:false,min:5000,r:{"3m":4.75,"6m":5.10,"12m":5.60,"24m":5.35,"36m":5.10,"60m":4.95}},
      {n:"Bendigo Bank",t:"Regional",hl:false,min:1000,r:{"3m":4.50,"6m":4.80,"12m":5.00,"24m":4.90,"36m":4.70,"60m":4.55}},
      {n:"BOQ",t:"Regional",hl:false,min:2000,r:{"3m":4.55,"6m":4.85,"12m":5.05,"24m":4.95,"36m":4.75,"60m":4.60}},
      {n:"Suncorp",t:"Regional",hl:false,min:5000,r:{"3m":4.60,"6m":4.85,"12m":5.10,"24m":4.95,"36m":4.75,"60m":4.60}},
    ]
  },

  // ========== HOME LOANS (Owner Occ, P&I, <80% LVR) ==========
  hl: {
    terms: ["var","1y","2y","3y","5y"],
    termLabels: {"var":"Variable","1y":"1 Yr Fixed","2y":"2 Yr Fixed","3y":"3 Yr Fixed","5y":"5 Yr Fixed"},
    banks: [
      {n:"Bank First",t:"Mutual",hl:true,r:{"var":6.14,"1y":5.89,"2y":5.79,"3y":5.84,"5y":5.99}},
      // Big 4
      {n:"CommBank",t:"Big 4",hl:false,r:{"var":6.59,"1y":5.99,"2y":5.99,"3y":6.09,"5y":6.34}},
      {n:"ANZ",t:"Big 4",hl:false,r:{"var":6.54,"1y":5.94,"2y":5.94,"3y":6.04,"5y":6.29}},
      {n:"NAB",t:"Big 4",hl:false,r:{"var":6.49,"1y":5.84,"2y":5.94,"3y":6.04,"5y":6.34}},
      {n:"Westpac",t:"Big 4",hl:false,r:{"var":5.74,"1y":5.89,"2y":5.99,"3y":6.09,"5y":6.39}},
      // Challengers / Tier 2
      {n:"Judo Bank",t:"Challenger",hl:false,r:{"var":5.94,"1y":5.69,"2y":5.74,"3y":5.84,"5y":6.09}},
      {n:"Macquarie",t:"Challenger",hl:false,r:{"var":6.00,"1y":5.79,"2y":5.84,"3y":5.89,"5y":6.19}},
      {n:"ING",t:"Challenger",hl:false,r:{"var":5.94,"1y":5.84,"2y":5.89,"3y":5.94,"5y":6.24}},
      {n:"ME Bank",t:"Challenger",hl:false,r:{"var":6.04,"1y":5.79,"2y":5.84,"3y":5.94,"5y":6.19}},
      {n:"AMP",t:"Challenger",hl:false,r:{"var":5.99,"1y":5.79,"2y":5.84,"3y":5.94,"5y":6.19}},
      {n:"UBank",t:"Neobank",hl:false,r:{"var":5.84,"1y":5.74,"2y":5.79,"3y":5.89,"5y":6.14}},
      {n:"Athena",t:"Neobank",hl:false,r:{"var":5.73,"1y":null,"2y":null,"3y":null,"5y":null}},
      {n:"loans.com.au",t:"Neobank",hl:false,r:{"var":5.74,"1y":5.69,"2y":5.74,"3y":5.84,"5y":6.09}},
      // Mutuals & Regionals
      {n:"Great Southern",t:"Mutual",hl:false,r:{"var":6.04,"1y":5.79,"2y":5.84,"3y":5.94,"5y":6.19}},
      {n:"Bank Australia",t:"Mutual",hl:false,r:{"var":6.09,"1y":5.84,"2y":5.89,"3y":5.99,"5y":6.24}},
      {n:"Heritage Bank",t:"Mutual",hl:false,r:{"var":6.09,"1y":5.84,"2y":5.89,"3y":5.94,"5y":6.19}},
      {n:"Bendigo Bank",t:"Regional",hl:false,r:{"var":6.24,"1y":5.89,"2y":5.94,"3y":6.04,"5y":6.29}},
      {n:"BOQ",t:"Regional",hl:false,r:{"var":6.19,"1y":5.89,"2y":5.94,"3y":5.99,"5y":6.24}},
      {n:"Suncorp",t:"Regional",hl:false,r:{"var":6.14,"1y":5.84,"2y":5.89,"3y":5.99,"5y":6.24}},
      {n:"Gateway Bank",t:"Mutual",hl:false,r:{"var":6.04,"1y":5.79,"2y":5.84,"3y":5.94,"5y":6.19}},
    ]
  },

  // ========== SAVINGS ACCOUNTS ==========
  sa: {
    terms: ["base","bonus","intro","max"],
    termLabels: {"base":"Base Rate","bonus":"Bonus Rate","intro":"Intro Rate","max":"Max Total"},
    banks: [
      {n:"Bank First",t:"Mutual",hl:true,prod:"Online Saver",cond:"$2k+ balance",r:{"base":1.75,"bonus":3.30,"intro":null,"max":5.05}},
      // Big 4
      {n:"CommBank",t:"Big 4",hl:false,prod:"NetBank Saver",cond:"Intro 5 months",r:{"base":2.20,"bonus":3.00,"intro":5.20,"max":5.20}},
      {n:"ANZ",t:"Big 4",hl:false,prod:"Plus Save",cond:"Grow $100/mo",r:{"base":0.10,"bonus":4.90,"intro":null,"max":5.00}},
      {n:"NAB",t:"Big 4",hl:false,prod:"iSaver",cond:"Intro 4 months",r:{"base":1.80,"bonus":null,"intro":5.20,"max":5.20}},
      {n:"Westpac",t:"Big 4",hl:false,prod:"Life (18-29)",cond:"Grow bal + 20 purchases",r:{"base":0.75,"bonus":5.00,"intro":null,"max":5.75}},
      // Challengers
      {n:"ING",t:"Challenger",hl:false,prod:"Savings Maximiser",cond:"Deposit $1k/mo + 5 purchases",r:{"base":0.01,"bonus":5.49,"intro":null,"max":5.50}},
      {n:"Macquarie",t:"Challenger",hl:false,prod:"Savings Account",cond:"No conditions",r:{"base":4.95,"bonus":null,"intro":null,"max":4.95}},
      {n:"Rabobank",t:"Challenger",hl:false,prod:"High Interest",cond:"Intro 4 months",r:{"base":4.20,"bonus":null,"intro":5.90,"max":5.90}},
      {n:"ME Bank",t:"Challenger",hl:false,prod:"Online Savings",cond:"Deposit $200/mo",r:{"base":1.35,"bonus":3.90,"intro":null,"max":5.25}},
      {n:"AMP",t:"Challenger",hl:false,prod:"GO Save",cond:"No conditions",r:{"base":5.10,"bonus":null,"intro":null,"max":5.10}},
      {n:"UBank",t:"Neobank",hl:false,prod:"Save",cond:"Intro 4 months",r:{"base":4.60,"bonus":null,"intro":5.85,"max":5.85}},
      {n:"Judo Bank",t:"Challenger",hl:false,prod:"Term Only",cond:"N/A",r:{"base":null,"bonus":null,"intro":null,"max":null}},
      // Mutuals & Regionals
      {n:"Great Southern",t:"Mutual",hl:false,prod:"Growth Saver",cond:"No withdrawals/mo",r:{"base":1.45,"bonus":3.60,"intro":null,"max":5.05}},
      {n:"Bank Australia",t:"Mutual",hl:false,prod:"Online Saver",cond:"No conditions",r:{"base":4.75,"bonus":null,"intro":null,"max":4.75}},
      {n:"Heritage Bank",t:"Mutual",hl:false,prod:"Online Saver",cond:"Deposit $20/mo",r:{"base":1.15,"bonus":4.00,"intro":null,"max":5.15}},
      {n:"Bendigo Bank",t:"Regional",hl:false,prod:"Reward Saver",cond:"Deposit $200/mo",r:{"base":1.50,"bonus":3.50,"intro":null,"max":5.00}},
      {n:"BOQ",t:"Regional",hl:false,prod:"Future Saver",cond:"Deposit/mo",r:{"base":1.65,"bonus":3.40,"intro":null,"max":5.05}},
      {n:"Suncorp",t:"Regional",hl:false,prod:"Growth Saver",cond:"No withdrawals",r:{"base":1.55,"bonus":3.55,"intro":null,"max":5.10}},
      {n:"Gateway Bank",t:"Mutual",hl:false,prod:"Savings Max",cond:"No conditions",r:{"base":4.80,"bonus":null,"intro":null,"max":4.80}},
      {n:"Community First",t:"Credit Union",hl:false,prod:"Growth Saver",cond:"Deposit $200/mo",r:{"base":1.35,"bonus":3.80,"intro":null,"max":5.15}},
    ]
  }
};
