"use client";

import { useState, useRef, useMemo } from "react";
import styles from "./page.module.css";

const CHANNELS = [
  { value: "instagram_post", label: "Instagram Post" },
  { value: "instagram_story", label: "Instagram Story" },
  { value: "instagram_reel", label: "Instagram Reel" },
  { value: "tiktok", label: "TikTok" },
  { value: "facebook_ad", label: "Facebook Ad" },
  { value: "email", label: "Email Campaign" },
  { value: "linkedin", label: "LinkedIn" },
  { value: "twitter", label: "Twitter / X Thread" },
];

const CONTENT_TYPES = [
  { value: "quote_card", label: "Quote Card" },
  { value: "destigmatisation", label: "Destigmatisation" },
  { value: "testimonial", label: "Client Testimonial / Social Proof" },
  { value: "intercultural", label: "Intercultural Couples" },
  { value: "christian", label: "Christian Couples" },
  { value: "educational", label: "Educational / Thought Leadership" },
  { value: "reluctant_partner", label: "The Reluctant Partner" },
  { value: "authority", label: "Authority / Media Feature" },
  { value: "parenting", label: "Parenting & Couples" },
];

const GRADIENTS = [
  "linear-gradient(135deg, #b37d00 0%, #d1b147 100%)",
  "linear-gradient(135deg, #d1b147 0%, #e8b788 100%)",
  "linear-gradient(135deg, #b37d00 0%, #e8b788 100%)",
  "linear-gradient(135deg, #9a6c00 0%, #b37d00 60%, #d1b147 100%)",
  "linear-gradient(135deg, #131313 0%, #b37d00 100%)",
];

const QUOTE_GRADIENTS = [
  "linear-gradient(135deg, #b37d00 0%, #d1b147 100%)",
  "linear-gradient(135deg, #9a6c00 0%, #b37d00 100%)",
  "linear-gradient(135deg, #d1b147 0%, #e8b788 100%)",
  "linear-gradient(160deg, #131313 0%, #b37d00 100%)",
  "linear-gradient(135deg, #b37d00 0%, #ccaed0 100%)",
];

function extractHookLine(text: string): string {
  const lines = text.split("\n").filter((l) => l.trim());
  for (const line of lines) {
    const clean = line.replace(/^[\s*#>-]+/, "").trim();
    if (clean.length > 10 && clean.length < 120 && !clean.startsWith("[")) {
      return clean;
    }
  }
  return "Reconnect. Rebuild. Thrive.";
}

function extractCaption(text: string): string {
  const lines = text.split("\n");
  const captionLines: string[] = [];
  let started = false;

  for (const line of lines) {
    const trimmed = line.trim();
    if (!started && trimmed.length > 20 && !trimmed.startsWith("#") && !trimmed.startsWith("---")) {
      started = true;
    }
    if (started) {
      if (trimmed.startsWith("---")) break;
      captionLines.push(line);
    }
  }

  return captionLines.join("\n").trim().slice(0, 600);
}

function extractHashtags(text: string): string {
  const match = text.match(/(#\w+[\s]*){2,}/);
  return match ? match[0].trim() : "";
}

function extractQuote(text: string): { quote: string; attribution: string } {
  const lines = text.split("\n").filter((l) => l.trim());
  let quote = "";
  let attribution = "Jill Dzadey — Freedom Couple Counselling";

  for (const line of lines) {
    const clean = line.replace(/^[\s*#>-]+/, "").trim();
    // Look for quoted text
    const quoteMatch = clean.match(/^[""\u201C](.+?)[""\u201D]$/);
    if (quoteMatch && !quote) {
      quote = quoteMatch[1];
      continue;
    }
    // Look for attribution line
    if (quote && (clean.startsWith("—") || clean.startsWith("-") || clean.startsWith("~"))) {
      attribution = clean.replace(/^[—\-~]\s*/, "");
      break;
    }
    // If no quoted text found, grab first substantial line as the quote
    if (!quote && clean.length > 15 && clean.length < 150 && !clean.startsWith("[") && !clean.startsWith("QUOTE") && !clean.includes("IMAGE PROMPT")) {
      quote = clean;
    }
  }

  if (!quote) quote = "Every couple deserves a fulfilling, connected, and thriving relationship.";
  return { quote, attribution };
}

export default function Home() {
  const [channel, setChannel] = useState("instagram_post");
  const [contentType, setContentType] = useState("quote_card");
  const [customContext, setCustomContext] = useState("");
  const [output, setOutput] = useState("");
  const [loading, setLoading] = useState(false);
  const [copied, setCopied] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  async function generate() {
    if (loading) return;
    setOutput("");
    setLoading(true);
    setCopied(false);

    abortRef.current = new AbortController();

    try {
      const res = await fetch("/api/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ channel, contentType, customContext }),
        signal: abortRef.current.signal,
      });

      if (!res.ok || !res.body) {
        setOutput("[Error: Failed to reach API]");
        setLoading(false);
        return;
      }

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let result = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        const chunk = decoder.decode(value, { stream: true });
        result += chunk;
        setOutput(result);
      }
    } catch (err) {
      if ((err as Error).name !== "AbortError") {
        setOutput("[Error: Request failed]");
      }
    } finally {
      setLoading(false);
    }
  }

  function stop() {
    abortRef.current?.abort();
    setLoading(false);
  }

  const [copySection, setCopySection] = useState<"copy" | "image" | null>(null);

  async function copySectionText(section: "copy" | "image") {
    const parts = output.split("--- IMAGE PROMPT ---");
    const text = section === "copy" ? parts[0]?.trim() : parts[1]?.trim();
    if (!text) return;
    await navigator.clipboard.writeText(text);
    setCopySection(section);
    setTimeout(() => setCopySection(null), 2000);
  }

  async function copyOutput() {
    if (!output) return;
    await navigator.clipboard.writeText(output);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  const [quoteCardCopied, setQuoteCardCopied] = useState(false);
  async function copyQuoteText() {
    const { quote, attribution } = extractQuote(copyPart);
    const text = `"${quote}"\n— ${attribution}`;
    await navigator.clipboard.writeText(text);
    setQuoteCardCopied(true);
    setTimeout(() => setQuoteCardCopied(false), 2000);
  }

  const hasSections = output.includes("--- IMAGE PROMPT ---");
  const copyPart = hasSections ? output.split("--- IMAGE PROMPT ---")[0]?.trim() : output;
  const imagePart = hasSections ? output.split("--- IMAGE PROMPT ---")[1]?.trim() : "";

  const isInstagramPost = channel === "instagram_post";
  const isQuoteCard = contentType === "quote_card";
  const gradientIndex = useMemo(
    () => Math.floor(Math.random() * GRADIENTS.length),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [output]
  );

  const channelLabel = CHANNELS.find((c) => c.value === channel)?.label ?? "Content";

  return (
    <main className={styles.main}>
      {/* Header */}
      <header className={styles.header}>
        <div className={styles.headerInner}>
          <div className={styles.logo}>
            <div className={styles.logoMark}>🌿</div>
            <div>
              <div className={styles.logoTitle}>Marketing Generator</div>
              <div className={styles.logoSub}>Freedom Couple Counselling — Jill Dzadey</div>
            </div>
          </div>
          <div className={styles.headerMeta}>
            <span className={styles.pill}>Melbourne</span>
            <span className={styles.pill}>Carlton &amp; Online</span>
          </div>
        </div>
      </header>

      <div className={styles.layout}>
        {/* Sidebar / Controls */}
        <aside className={styles.sidebar}>
          <h2 className={styles.sidebarTitle}>Generate Content</h2>

          <div className={styles.field}>
            <label className={styles.label}>Channel</label>
            <div className={styles.segmentGrid}>
              {CHANNELS.map((c) => (
                <button
                  key={c.value}
                  className={`${styles.segment} ${channel === c.value ? styles.segmentActive : ""}`}
                  onClick={() => setChannel(c.value)}
                >
                  {c.label}
                </button>
              ))}
            </div>
          </div>

          <div className={styles.field}>
            <label className={styles.label}>Content Type</label>
            <div className={styles.segmentGrid}>
              {CONTENT_TYPES.map((ct) => (
                <button
                  key={ct.value}
                  className={`${styles.segment} ${contentType === ct.value ? styles.segmentActive : ""}`}
                  onClick={() => setContentType(ct.value)}
                >
                  {ct.label}
                </button>
              ))}
            </div>
          </div>

          <div className={styles.field}>
            <label className={styles.label}>
              Additional Context <span className={styles.optional}>(optional)</span>
            </label>
            <textarea
              className={styles.textarea}
              rows={4}
              placeholder="E.g. Focus on the reluctant husband. Mention the Carlton clinic. Target intercultural couples specifically."
              value={customContext}
              onChange={(e) => setCustomContext(e.target.value)}
            />
          </div>

          <div className={styles.actions}>
            {!loading ? (
              <button className={styles.btnPrimary} onClick={generate}>
                Generate Content
              </button>
            ) : (
              <button className={styles.btnStop} onClick={stop}>
                Stop Generating
              </button>
            )}
          </div>

          <div className={styles.hint}>
            Powered by AI with extended thinking. Copy is generated fresh each time — regenerate for variations.
          </div>
        </aside>

        {/* Output */}
        <section className={styles.outputSection}>
          {!output && !loading && (
            <div className={styles.emptyState}>
              <div className={styles.emptyIcon}>🌿</div>
              <h3>Ready to create</h3>
              <p>Select a channel and content type, then click Generate Content.</p>
              <p className={styles.emptyNote}>
                Each generation includes platform-optimised copy and an AI image prompt.
              </p>
            </div>
          )}

          {(output || loading) && (
            <>
              {/* Quote Card preview */}
              {isQuoteCard && hasSections && (
                <div className={styles.quoteCard}>
                  <div
                    className={styles.quoteCardInner}
                    style={{ background: QUOTE_GRADIENTS[gradientIndex] }}
                  >
                    <div className={styles.quoteCardMark}>&ldquo;</div>
                    <div className={styles.quoteCardText}>
                      {extractQuote(copyPart).quote}
                    </div>
                    <div className={styles.quoteCardDivider} />
                    <div className={styles.quoteCardAttrib}>
                      {extractQuote(copyPart).attribution}
                    </div>
                    <div className={styles.quoteCardBrand}>
                      freedomcouplecounselling.com
                    </div>
                  </div>
                  <div className={styles.quoteCardCopyBar}>
                    <button
                      className={styles.quoteCardCopyBtn}
                      onClick={copyQuoteText}
                    >
                      {quoteCardCopied ? "Copied!" : "Copy Quote"}
                    </button>
                    {imagePart && (
                      <button
                        className={styles.quoteCardCopyBtn}
                        onClick={() => copySectionText("image")}
                      >
                        {copySection === "image" ? "Copied!" : "Copy Image Prompt"}
                      </button>
                    )}
                  </div>
                </div>
              )}

              {/* Instagram Post content card */}
              {isInstagramPost && !isQuoteCard && hasSections && (
                <div className={styles.contentCard}>
                  <div className={styles.contentCardHeader}>
                    <div className={styles.contentCardAvatar}>🌿</div>
                    <div>
                      <div className={styles.contentCardUsername}>freedomcouplecounselling</div>
                      <div className={styles.contentCardChannel}>Melbourne, Victoria</div>
                    </div>
                    <div className={styles.contentCardMore}>···</div>
                  </div>
                  <div
                    className={styles.contentCardImage}
                    style={{ background: GRADIENTS[gradientIndex] }}
                  >
                    <div>
                      <div className={styles.contentCardImageText}>
                        {extractHookLine(copyPart)}
                      </div>
                      <div className={styles.contentCardImageSub}>
                        Freedom Couple Counselling
                      </div>
                    </div>
                  </div>
                  <div className={styles.contentCardActions}>
                    <span className={styles.contentCardAction}>🤍</span>
                    <span className={styles.contentCardAction}>💬</span>
                    <span className={styles.contentCardAction}>✈️</span>
                    <span className={`${styles.contentCardAction} ${styles.contentCardSave}`}>🔖</span>
                  </div>
                  <div className={styles.contentCardBody}>
                    <div className={styles.contentCardCaption}>
                      <span style={{ fontWeight: 700 }}>freedomcouplecounselling</span>{" "}
                      {extractCaption(copyPart)}
                    </div>
                  </div>
                  {extractHashtags(copyPart) && (
                    <div className={styles.contentCardHashtags}>
                      {extractHashtags(copyPart)}
                    </div>
                  )}
                  <div className={styles.contentCardCopyBar}>
                    <button
                      className={styles.contentCardCopyBtn}
                      onClick={() => copySectionText("copy")}
                    >
                      {copySection === "copy" ? "Copied!" : "Copy Caption"}
                    </button>
                    {imagePart && (
                      <button
                        className={styles.contentCardCopyBtn}
                        onClick={() => copySectionText("image")}
                      >
                        {copySection === "image" ? "Copied!" : "Copy Image Prompt"}
                      </button>
                    )}
                  </div>
                </div>
              )}

              {/* Raw output blocks */}
              {hasSections ? (
                <>
                  <div className={styles.outputBlock}>
                    <div className={styles.outputBlockHeader}>
                      <span className={styles.outputBlockLabel}>
                        {isQuoteCard ? "Quote Copy" : isInstagramPost ? "Full Caption" : "Marketing Copy"}
                      </span>
                      <button
                        className={styles.copyBtn}
                        onClick={() => copySectionText("copy")}
                      >
                        {copySection === "copy" ? "Copied!" : "Copy"}
                      </button>
                    </div>
                    <pre className={styles.outputText}>{copyPart}</pre>
                  </div>

                  {imagePart && (
                    <div className={`${styles.outputBlock} ${styles.outputBlockImage}`}>
                      <div className={styles.outputBlockHeader}>
                        <span className={styles.outputBlockLabel}>Image Prompt</span>
                        <button
                          className={styles.copyBtn}
                          onClick={() => copySectionText("image")}
                        >
                          {copySection === "image" ? "Copied!" : "Copy"}
                        </button>
                      </div>
                      <pre className={styles.outputText}>{imagePart}</pre>
                    </div>
                  )}
                </>
              ) : (
                <div className={styles.outputBlock}>
                  <div className={styles.outputBlockHeader}>
                    <span className={styles.outputBlockLabel}>
                      {loading ? "Generating..." : channelLabel}
                    </span>
                    {output && (
                      <button className={styles.copyBtn} onClick={copyOutput}>
                        {copied ? "Copied!" : "Copy All"}
                      </button>
                    )}
                  </div>
                  <pre className={styles.outputText}>{output}</pre>
                  {loading && <span className={styles.cursor} />}
                </div>
              )}

              {!loading && output && (
                <div className={styles.regenBar}>
                  <button className={styles.btnSecondary} onClick={generate}>
                    Regenerate Variation
                  </button>
                </div>
              )}
            </>
          )}
        </section>
      </div>
    </main>
  );
}
