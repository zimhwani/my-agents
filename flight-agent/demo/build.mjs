// Bundles the app into demo/dist/index.html: one self-contained page that runs
// on sample fares with no server. Usage: npm run demo
import * as esbuild from "esbuild";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const outdir = path.join(here, "dist");
fs.mkdirSync(outdir, { recursive: true });

const result = await esbuild.build({
  entryPoints: [path.join(here, "entry.tsx")],
  bundle: true,
  minify: true,
  format: "iife",
  platform: "browser",
  target: ["es2020"],
  jsx: "automatic",
  tsconfig: path.join(here, "..", "tsconfig.json"),
  define: { "process.env.NODE_ENV": '"production"' },
  write: false,
  outdir,
  loader: { ".css": "css" },
});

const js = result.outputFiles.find((f) => f.path.endsWith(".js"))?.text ?? "";
const css = result.outputFiles.find((f) => f.path.endsWith(".css"))?.text ?? "";

const html = `<title>Harare Flight Agent</title>
<meta name="description" content="Voice-controlled flight tracker: Melbourne to Harare for two adults and two children, on sample fares.">
<style>${css}</style>
<div id="root"></div>
<script>${js.replace(/<\/script/g, "<\\/script")}</script>
`;
fs.writeFileSync(path.join(outdir, "index.html"), html);
console.log(`Wrote ${path.join(outdir, "index.html")} (${(html.length / 1024).toFixed(0)} kB)`);
