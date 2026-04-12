"use client";

import { useState, useRef, useMemo, useCallback } from "react";
import { toPng } from "html-to-image";
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
  { value: "destigmatisation", label: "Destigmatisation" },
  { value: "testimonial", label: "Client Testimonial / Social Proof" },
  { value: "intercultural", label: "Intercultural Couples" },
  { value: "christian", label: "Christian Couples" },
  { value: "educational", label: "Educational / Thought Leadership" },
  { value: "reluctant_partner", label: "The Reluctant Partner" },
  { value: "authority", label: "Authority / Media Feature" },
  { value: "parenting", label: "Parenting & Couples" },
];

const FORMAT_PRESETS = [
  { value: "square", label: "Square", dims: "1080\u00d71080", width: 1080, height: 1080, ratio: "1/1" },
  { value: "story", label: "Story", dims: "1080\u00d71920", width: 1080, height: 1920, ratio: "9/16" },
  { value: "portrait", label: "Portrait", dims: "1080\u00d71350", width: 1080, height: 1350, ratio: "4/5" },
  { value: "landscape", label: "Landscape", dims: "1920\u00d71080", width: 1920, height: 1080, ratio: "16/9" },
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
  // First try: find text wrapped in **bold** markers (the actual hook)
  const boldMatch = text.match(/\*\*(.{10,120}?)\*\*/);
  if (boldMatch) {
    return boldMatch[1].replace(/[""\u201C\u201D]/g, "").trim();
  }

  // Second try: find a line that looks like real copy, skipping headers/labels
  const lines = text.split("\n").filter((l) => l.trim());
  for (const line of lines) {
    const clean = line.replace(/^[\s*#>-]+/, "").trim();
    // Skip lines that look like labels (contain em dash with title case on both sides)
    if (/^[A-Z][a-z]+ (Post|Story|Reel|Ad|Campaign|Thread)\s*[—\-]/.test(clean)) continue;
    // Skip section headers
    if (/^(HEADLINE|HOOK|CAPTION|SUBJECT|PRIMARY|CTA|SCRIPT)/i.test(clean)) continue;
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
    // Skip label/header lines
    if (!started && /^(HEADLINE|HOOK|CAPTION|SUBJECT|PRIMARY|CTA|SCRIPT)/i.test(trimmed)) continue;
    if (!started && /^[A-Z][a-z]+ (Post|Story|Reel|Ad|Campaign|Thread)\s*[—\-]/.test(trimmed)) continue;
    if (!started && trimmed.length > 20 && !trimmed.startsWith("#") && !trimmed.startsWith("---")) {
      started = true;
    }
    if (started) {
      if (trimmed.startsWith("---")) break;
      captionLines.push(line);
    }
  }

  // Strip markdown bold markers
  return captionLines.join("\n").trim().replace(/\*\*/g, "").slice(0, 600);
}

function extractHashtags(text: string): string {
  const match = text.match(/(#\w+[\s]*){2,}/);
  return match ? match[0].trim() : "";
}

function getCaptureStyles(format: typeof FORMAT_PRESETS[number]) {
  const base = format.width;
  const isStory = format.value === "story";
  const isLandscape = format.value === "landscape";

  return {
    logo: { width: base * 0.06, height: base * 0.06 },
    mark: base * 0.08,
    text: isLandscape ? base * 0.032 : isStory ? base * 0.035 : base * 0.038,
    attrib: base * 0.014,
    brand: base * 0.011,
    dividerW: base * 0.05,
    dividerH: Math.max(2, base * 0.002),
    padding: isStory ? `${base * 0.12}px ${base * 0.06}px` : isLandscape ? `${base * 0.06}px ${base * 0.1}px` : `${base * 0.08}px ${base * 0.06}px`,
    brandBottom: base * 0.025,
    letterSpacing: base * 0.002,
  };
}

export default function Home() {
  const [channel, setChannel] = useState("instagram_post");
  const [contentType, setContentType] = useState("destigmatisation");
  const [customContext, setCustomContext] = useState("");
  const [output, setOutput] = useState("");
  const [loading, setLoading] = useState(false);
  const [copied, setCopied] = useState(false);
  const [selectedFormat, setSelectedFormat] = useState("square");
  const [downloading, setDownloading] = useState(false);

  // Quote card editor state
  const [showQuoteCard, setShowQuoteCard] = useState(false);
  const [editableQuote, setEditableQuote] = useState("");
  const [editableAttrib, setEditableAttrib] = useState("Jill Dzadey \u2014 Freedom Couple Counselling");

  const abortRef = useRef<AbortController | null>(null);
  const captureRef = useRef<HTMLDivElement | null>(null);

  const currentFormat = FORMAT_PRESETS.find((f) => f.value === selectedFormat) ?? FORMAT_PRESETS[0];

  async function generate() {
    if (loading) return;
    setOutput("");
    setLoading(true);
    setCopied(false);
    setShowQuoteCard(false);

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
    const text = `\u201C${editableQuote}\u201D\n\u2014 ${editableAttrib}`;
    await navigator.clipboard.writeText(text);
    setQuoteCardCopied(true);
    setTimeout(() => setQuoteCardCopied(false), 2000);
  }

  function openQuoteCardEditor() {
    const hookLine = extractHookLine(copyPart);
    setEditableQuote(hookLine);
    setEditableAttrib("Jill Dzadey \u2014 Freedom Couple Counselling");
    setShowQuoteCard(true);
  }

  const downloadQuoteCard = useCallback(async () => {
    if (!captureRef.current || downloading) return;
    setDownloading(true);
    try {
      const dataUrl = await toPng(captureRef.current, {
        width: currentFormat.width,
        height: currentFormat.height,
        pixelRatio: 1,
        cacheBust: true,
      });
      const link = document.createElement("a");
      link.download = `fcc-quote-${currentFormat.value}-${Date.now()}.png`;
      link.href = dataUrl;
      link.click();
    } catch (err) {
      console.error("Download failed:", err);
    } finally {
      setDownloading(false);
    }
  }, [currentFormat, downloading]);

  const hasSections = output.includes("--- IMAGE PROMPT ---");
  const copyPart = hasSections ? output.split("--- IMAGE PROMPT ---")[0]?.trim() : output;
  const imagePart = hasSections ? output.split("--- IMAGE PROMPT ---")[1]?.trim() : "";

  const isInstagramPost = channel === "instagram_post";
  const gradientIndex = useMemo(
    () => Math.floor(Math.random() * GRADIENTS.length),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [output]
  );

  const channelLabel = CHANNELS.find((c) => c.value === channel)?.label ?? "Content";
  const captureStyles = getCaptureStyles(currentFormat);
  const activeGradient = QUOTE_GRADIENTS[gradientIndex];

  return (
    <main className={styles.main}>
      {/* Header */}
      <header className={styles.header}>
        <div className={styles.headerInner}>
          <div className={styles.logo}>
            <div className={styles.logoMark}>
              <img src="/logo.png" alt="FCC" className={styles.logoMarkImg} />
            </div>
            <div>
              <div className={styles.logoTitle}>Marketing Generator</div>
              <div className={styles.logoSub}>Freedom Couple Counselling \u2014 Jill Dzadey</div>
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
            Powered by AI with extended thinking. Copy is generated fresh each time \u2014 regenerate for variations.
          </div>
        </aside>

        {/* Output */}
        <section className={styles.outputSection}>
          {!output && !loading && (
            <div className={styles.emptyState}>
              <div className={styles.emptyIcon}>
                <img src="/logo.png" alt="FCC" className={styles.emptyIconImg} />
              </div>
              <h3>Ready to create</h3>
              <p>Select a channel and content type, then click Generate Content.</p>
              <p className={styles.emptyNote}>
                Each generation includes platform-optimised copy and an AI image prompt.
              </p>
            </div>
          )}

          {(output || loading) && (
            <>
              {/* Wing Wave content card — branded visual */}
              {hasSections && (
                <div className={styles.waveCard}>
                  <div className={styles.waveCardTop}>
                    <div className={styles.waveCardLogo}>
                      <img src="/logo.png" alt="" className={styles.waveCardLogoImg} />
                    </div>
                    <div className={styles.waveCardHook}>
                      {extractHookLine(copyPart)}
                    </div>
                    <div className={styles.waveCardSub}>
                      Freedom Couple Counselling
                    </div>
                  </div>
                  {/* Wing wave SVG divider */}
                  <div className={styles.waveCardDivider}>
                    <svg viewBox="0 0 440 60" preserveAspectRatio="none" className={styles.waveSvg}>
                      <path d="M0,30 C80,55 160,0 220,30 C280,60 360,5 440,30 L440,60 L0,60 Z" fill="#fffff8" />
                    </svg>
                  </div>
                  <div className={styles.waveCardBottom}>
                    <div className={styles.waveCardCaption}>
                      {extractCaption(copyPart).slice(0, 200)}
                    </div>
                    <div className={styles.waveCardBrand}>
                      freedomcouplecounselling.com
                    </div>
                  </div>
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
                        {isInstagramPost ? "Full Caption" : "Marketing Copy"}
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

              {/* Create Quote Card button — appears after generation */}
              {!loading && output && !showQuoteCard && (
                <div className={styles.regenBar}>
                  <button className={styles.createQuoteBtn} onClick={openQuoteCardEditor}>
                    Create Quote Card
                  </button>
                  <button className={styles.btnSecondary} onClick={generate}>
                    Regenerate Variation
                  </button>
                </div>
              )}

              {/* Quote Card Editor — editable fields + preview + download */}
              {showQuoteCard && (
                <>
                  {/* Editable fields */}
                  <div className={styles.quoteEditor}>
                    <div className={styles.quoteEditorHeader}>
                      <div className={styles.quoteEditorTitle}>Quote Card</div>
                      <button
                        className={styles.quoteEditorClose}
                        onClick={() => setShowQuoteCard(false)}
                      >
                        &times;
                      </button>
                    </div>
                    <div className={styles.quoteEditorField}>
                      <label className={styles.quoteEditorLabel}>Quote Text</label>
                      <textarea
                        className={styles.quoteEditorTextarea}
                        rows={3}
                        value={editableQuote}
                        onChange={(e) => setEditableQuote(e.target.value)}
                      />
                    </div>
                    <div className={styles.quoteEditorField}>
                      <label className={styles.quoteEditorLabel}>Attribution</label>
                      <input
                        className={styles.quoteEditorInput}
                        type="text"
                        value={editableAttrib}
                        onChange={(e) => setEditableAttrib(e.target.value)}
                      />
                    </div>
                  </div>

                  {/* Format selector */}
                  <div className={styles.formatSelector}>
                    {FORMAT_PRESETS.map((f) => (
                      <button
                        key={f.value}
                        className={`${styles.formatBtn} ${selectedFormat === f.value ? styles.formatBtnActive : ""}`}
                        onClick={() => setSelectedFormat(f.value)}
                      >
                        {f.label}
                        <span className={styles.formatBtnDims}>{f.dims}</span>
                      </button>
                    ))}
                  </div>

                  {/* Visible preview */}
                  <div className={styles.quoteCard}>
                    <div
                      className={styles.quoteCardInner}
                      style={{
                        background: activeGradient,
                        aspectRatio: currentFormat.ratio,
                      }}
                    >
                      <div className={styles.quoteCardLogo}>
                        <img src="/logo.png" alt="" className={styles.quoteCardLogoImg} />
                      </div>
                      <div className={styles.quoteCardMark}>&ldquo;</div>
                      <div className={styles.quoteCardText} style={{
                        fontSize: currentFormat.value === "landscape" ? "clamp(16px, 3vw, 22px)" : "clamp(18px, 3.5vw, 24px)",
                      }}>
                        {editableQuote}
                      </div>
                      <div className={styles.quoteCardDivider} />
                      <div className={styles.quoteCardAttrib}>
                        {editableAttrib}
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
                      <button
                        className={styles.quoteCardDownloadBtn}
                        onClick={downloadQuoteCard}
                        disabled={downloading}
                      >
                        {downloading ? "Downloading..." : `Download PNG (${currentFormat.dims})`}
                      </button>
                    </div>
                  </div>

                  {/* Hidden high-res capture target */}
                  <div className={styles.captureTarget}>
                    <div
                      ref={captureRef}
                      className={styles.captureInner}
                      style={{
                        width: currentFormat.width,
                        height: currentFormat.height,
                        background: activeGradient,
                        padding: captureStyles.padding,
                      }}
                    >
                      <div className={styles.captureLogo} style={{
                        width: captureStyles.logo.width,
                        height: captureStyles.logo.height,
                        marginBottom: captureStyles.logo.height * 0.25,
                      }}>
                        <img src="/logo.png" alt="" className={styles.captureLogoImg} />
                      </div>
                      <div className={styles.captureMark} style={{
                        fontSize: captureStyles.mark,
                        marginBottom: captureStyles.mark * 0.12,
                      }}>
                        &ldquo;
                      </div>
                      <div className={styles.captureText} style={{
                        fontSize: captureStyles.text,
                      }}>
                        {editableQuote}
                      </div>
                      <div className={styles.captureDivider} style={{
                        width: captureStyles.dividerW,
                        height: captureStyles.dividerH,
                        margin: `${captureStyles.dividerW * 0.4}px auto`,
                      }} />
                      <div className={styles.captureAttrib} style={{
                        fontSize: captureStyles.attrib,
                        letterSpacing: captureStyles.letterSpacing,
                      }}>
                        {editableAttrib}
                      </div>
                      <div className={styles.captureBrand} style={{
                        fontSize: captureStyles.brand,
                        letterSpacing: captureStyles.letterSpacing * 1.2,
                        bottom: captureStyles.brandBottom,
                      }}>
                        freedomcouplecounselling.com
                      </div>
                    </div>
                  </div>

                  {/* Regenerate below quote card */}
                  <div className={styles.regenBar}>
                    <button className={styles.btnSecondary} onClick={generate}>
                      Regenerate Variation
                    </button>
                  </div>
                </>
              )}
            </>
          )}
        </section>
      </div>
    </main>
  );
}
