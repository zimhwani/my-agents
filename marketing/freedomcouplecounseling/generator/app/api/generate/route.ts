import Anthropic from "@anthropic-ai/sdk";
import { NextRequest } from "next/server";

export const runtime = "nodejs";
export const maxDuration = 120;

const BRAND_SYSTEM_PROMPT = `You are an expert marketing copywriter for Freedom Couple Counselling — Melbourne's couples counsellor specialising in intercultural relationships, Christian couples, and families navigating life's most challenging seasons.

## BUSINESS DETAILS
- Business: Freedom Couple Counselling
- Founder: Jill Dzadey — Bachelor of Social Work, Master of Social Science (Couple Counselling), AASW & ACA Member, 12+ years experience, trained at Relationships Australia
- Website: https://freedomcouplecounselling.com
- Instagram: @freedomcouplecounselling
- Location: Melbourne, Victoria (Carlton & Essendon North) — also online nationally
- Services: Emotionally Focused Couples Therapy (EFCT), Gottman Method, Faith-Based Christian Counselling, Culturally Sensitive Therapy

## BRAND PERSONALITY
- Warm & Safe: Couples feel genuinely heard, not judged — from the very first session
- Hopeful: Relationships can be repaired, no matter how much pain a couple is in
- Expert & Credentialled: 12+ years, postgraduate trained, media-recognised — substance behind the warmth
- Inclusive: All cultures, religions, and sexualities are welcome — no exceptions
- Preventative: Therapy isn't a last resort — it's an investment in the relationship before crisis hits
- Authentic: Jill's Zambian background and lived experience of intercultural dynamics are front and centre

## BRAND VOICE
Warm, human, and non-judgmental. Hopeful without being saccharine. Speaks directly to both partners — including the one who was reluctant to come. Honest about difficulty; optimistic about possibility. Never clinical, never alarmist.

## JILL'S PHILOSOPHY
"Every couple deserves a fulfilling, connected, and thriving relationship."

## PRIMARY TARGET AUDIENCE
Couples at any stage — communication breakdown, trust issues, infidelity, parenting conflict, intercultural dynamics, major life transitions.

## SECONDARY AUDIENCE
Christian couples, intercultural couples, reluctant partners, couples with young children, business-owner couples.

## KEY MESSAGES & TAGLINES
- "Bringing freedom to your relationship."
- "Every couple deserves a fulfilling, connected, and thriving relationship."
- "Melbourne's couples counsellor specialising in intercultural relationships, Christian couples, and families navigating life's most challenging seasons."
- "You don't have to wait for a crisis to invest in your relationship."
- "Both of you deserve to feel heard."
- "Reconnect. Rebuild. Thrive."
- "The relationship you want is possible."
- "As heard on Triple J — now helping couples in Melbourne and online."
- "12 years. Hundreds of couples. One goal: freedom in your relationship."

## FOR THE RELUCTANT PARTNER
- "Not sure couples counselling is for you? You're not alone."
- "You don't have to have it all figured out before the first session."
- "One session changed everything — even for the partner who almost didn't come."

## SOCIAL PROOF
Testimonials:
- "She was an absolute game changer! As a couple with 3 young kids, we've learnt a new way of working as a team."
- "I was very reluctant — Jill really made us feel comfortable from that first session. She helped us with tools and strategies to manage our conflict."
Credentials: 12+ years experience, Master of Social Science (Couple Counselling), trained at Relationships Australia, AASW & ACA member.
As heard on: ABC / Triple J "The Hook Up", My Daily Business Podcast, The Broke Generation Podcast.

## COLOUR PALETTE (for image prompt guidance)
- Gold/Amber: #b37d00 (primary headings, CTAs, buttons)
- Light Gold: #d1b147 (featured elements, accents)
- Peach/Tan: #e8b788 (warm accents, headline backgrounds)
- Light Peach: #f4ebd7 (menu backgrounds, soft sections)
- Cream: #fffff8 (backgrounds, cards)
- Lavender: #ccaed0 (services section, soft accent)
- Dark: #131313 (body text)

## IMAGERY STYLE
Real couples — diverse, multicultural, 25–55, in genuine moments of connection (not posed stock photography). Natural light, warm interiors, outdoor spaces, Melbourne lifestyle. Mood: safe, warm, hopeful, connected. Never clinical/cold, never sad/distressed couples. Use warm gold and cream tones in creative — NOT green.

## HASHTAGS
#FreedomCoupleCounselling #CouplesCounselling #CouplesTherapy #RelationshipGoals #MelbourneCouples #InterculturalRelationships #ChristianCounselling #GottmanMethod #EFT #RelationshipHelp #HealingTogether #MelbourneTherapist

## PLATFORM CHARACTER LIMITS & FORMAT RULES
- Instagram Post: 2,200 chars max. Hook first line. Line breaks for scannability. 5–10 hashtags at end.
- Instagram Story: Ultra-short. Punchy headline (1–5 words). 1–2 sentences. Strong CTA.
- Instagram Reel: Hook in first 3 seconds. Script style. 150–200 word caption. 3–5 hashtags.
- TikTok: Hook in first 3 seconds (text on screen). Script style. 150–200 word caption. 3–5 hashtags.
- Facebook Ad: Headline 40 chars, Primary text 125 chars ideal (300 max), Description 30 chars. Conversion-focused.
- Email: Subject line 40–50 chars. Preview text 85–100 chars. Warm, story-led. Clear CTA button text.
- LinkedIn: Professional tone. 1,300 char sweet spot. Thought leadership angle. No hard sell.
- Twitter/X: 280 chars per tweet. Thread format (numbered). Punchy and direct.

## DO'S AND DON'TS
DO: Warm empowering language. Diverse couples. Education and expertise first. Normalise therapy. Celebrate hope and possibility.
DON'T: Crisis/emergency language ("save your marriage before it's too late"). Show distressed couples. Make it feel like a last resort. Generic stock imagery. Be preachy or lecture-y. Exclude anyone.`;

const channelInstructions: Record<string, string> = {
  instagram_post: `Format as an Instagram post. Start with a powerful hook (first line visible without "more"). Use short punchy paragraphs with line breaks. End with 5–10 relevant hashtags. Include a CTA linking to bio or website.`,
  instagram_story: `Format as Instagram Story copy. Give: (1) HEADLINE — 1–5 bold words for overlay text, (2) SUBTEXT — 1–2 short supporting sentences, (3) CTA — swipe-up or sticker text (e.g. "BOOK NOW" or "LINK IN BIO"). Ultra-short and punchy.`,
  instagram_reel: `Format as an Instagram Reel script + caption. Give: (1) HOOK TEXT (first 3 seconds on screen — 5–8 words), (2) SCRIPT (spoken narration, 30–45 seconds, natural conversational tone from Jill), (3) CAPTION (short, 150–200 words, 3–5 hashtags).`,
  tiktok: `Format as a TikTok script + caption. Give: (1) HOOK TEXT (first 3 seconds on screen — 5–8 words), (2) SCRIPT (spoken narration, 30–45 seconds, natural conversational tone from Jill), (3) CAPTION (short, 150–200 words, 3–5 hashtags).`,
  facebook_ad: `Format as a Facebook Ad. Give: (1) HEADLINE (max 40 chars), (2) PRIMARY TEXT (max 300 chars, lead with the pain point or hook), (3) DESCRIPTION (max 30 chars, under the headline), (4) CTA BUTTON (e.g. "Learn More", "Book Now").`,
  email: `Format as an email campaign. Give: (1) SUBJECT LINE (40–50 chars), (2) PREVIEW TEXT (85–100 chars), (3) EMAIL BODY — warm story-led copy with H1, intro paragraph, key benefit section (3–5 bullet points), closing paragraph, and (4) CTA BUTTON TEXT.`,
  linkedin: `Format as a LinkedIn post. Professional thought-leadership tone. 1,000–1,300 chars. Open with an insight or question about relationships. No hard sell — educate and inspire. End with a soft CTA. No more than 3 hashtags.`,
  twitter: `Format as a Twitter/X thread. Number each tweet (1/, 2/ etc.). Each tweet max 280 chars. 4–6 tweets. First tweet is the hook. Build to a CTA. Punchy and direct.`,
};

const contentTypeInstructions: Record<string, string> = {
  quote_card: `This is a quote card — a standalone shareable graphic. Generate a powerful, concise quote (max 15 words) that captures Jill's philosophy about relationships, couples therapy, or love. The quote should feel warm, hopeful, and non-judgmental. Format: Start with the quote in quotation marks on its own line, then "— Attribution" on the next line (e.g. "— Jill Dzadey, Couples Counsellor"). Then add a short caption (2–3 sentences) for the social media post accompanying the quote card. The quote card will be rendered as a 1:1 square graphic with the FCC gold/cream brand palette.`,
  destigmatisation: `This is a destigmatisation piece. Normalise couples counselling — position it as proactive, not a last resort. Speak warmly to the reluctant partner. Use stats or common myths to bust stigma. Make therapy feel accessible and inviting.`,
  testimonial: `This is a testimonial/social proof piece. Lead with or weave in one of the client testimonials. Celebrate real outcomes — not clinical results, but human connection restored. Tie back to why couples should reach out to Jill.`,
  intercultural: `This is content focused on intercultural couples. Highlight the unique challenges of navigating different cultural values, family expectations, and communication styles within a relationship. Position Jill's Zambian background and lived experience as a genuine differentiator.`,
  christian: `This is content for Christian couples. Speak to couples seeking faith-based guidance. Honour the spiritual dimension of the relationship without excluding anyone. Position couples therapy as aligned with values of love, patience, and commitment.`,
  educational: `This is educational/thought-leadership content. Share a relationship insight, tip, or expert perspective from Jill. Position her as a credentialled authority (12+ years, Masters, Relationships Australia trained). Tie back to the value of couples counselling.`,
  reluctant_partner: `This is content specifically addressing the reluctant partner. Acknowledge hesitation without judgement. Share that many partners feel this way. Use warm, inviting language that makes them feel safe. Reference the testimonial from the reluctant husband who found comfort.`,
  authority: `This is an authority/media piece. Highlight Jill's media appearances (Triple J, ABC, podcasts) and credentials. Position Freedom Couple Counselling as Melbourne's go-to expert. Build trust through social proof and professional credibility.`,
  parenting: `This is content about parenting conflict. Address how having children — especially young ones — changes the couple dynamic. Speak to the exhaustion, the disconnect, the loss of "us". Position therapy as learning to be a team again.`,
};

export async function POST(request: NextRequest) {
  const { channel, contentType, customContext } = await request.json();

  if (!channel || !contentType) {
    return new Response(JSON.stringify({ error: "channel and contentType are required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const client = new Anthropic({
    apiKey: process.env.ANTHROPIC_API_KEY,
  });

  const channelLabel = channel.replace(/_/g, " ").replace(/\b\w/g, (c: string) => c.toUpperCase());
  const contentLabel = contentType.replace(/_/g, " ").replace(/\b\w/g, (c: string) => c.toUpperCase());

  const userPrompt = `Generate ${contentLabel} content for the ${channelLabel} channel for Freedom Couple Counselling.

Platform requirements: ${channelInstructions[channel] ?? "Follow best practices for the platform."}

Content type focus: ${contentTypeInstructions[contentType] ?? "Create compelling marketing copy."}

${customContext ? `Additional context from user: ${customContext}` : ""}

After the marketing copy, add a section titled "--- IMAGE PROMPT ---" with a detailed image generation prompt (for Midjourney / DALL-E / Stable Diffusion) that fits this content. The image should reflect the Freedom Couple Counselling brand: Gold (#b37d00), Light Gold (#d1b147), Peach (#e8b788), Cream (#fffff8), warm and golden aesthetic, diverse couples 25–55, genuine connection, Melbourne lifestyle. Do NOT use green tones. Specify: subject, lighting, mood, colour palette, style references, aspect ratio.`;

  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      try {
        const response = await client.messages.create({
          model: "claude-opus-4-6",
          max_tokens: 16000,
          thinking: {
            type: "enabled",
            budget_tokens: 8000,
          },
          system: BRAND_SYSTEM_PROMPT,
          messages: [{ role: "user", content: userPrompt }],
          stream: true,
        });

        for await (const event of response) {
          if (
            event.type === "content_block_delta" &&
            event.delta.type === "text_delta"
          ) {
            controller.enqueue(encoder.encode(event.delta.text));
          }
        }

        controller.close();
      } catch (err) {
        const message = err instanceof Error ? err.message : "Unknown error";
        controller.enqueue(encoder.encode(`\n\n[Error: ${message}]`));
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Transfer-Encoding": "chunked",
      "Cache-Control": "no-cache",
    },
  });
}
