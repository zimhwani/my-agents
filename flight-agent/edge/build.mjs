// Builds the hosted bundle: edge/dist/page.html (the app) and edge/dist/index.js
// (a Deno server that serves the page and the API). Usage: npm run build:edge
import * as esbuild from "esbuild";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
// Where the "remote" server build fetches the page from (override at runtime with PAGE_URL).
const pageUrlArg = process.argv.find((a) => a.startsWith("--page-url="))?.slice("--page-url=".length);
const branch = pageUrlArg ? null : (process.env.PAGE_BRANCH ?? "main");
const DEFAULT_PAGE_URL = pageUrlArg ?? `https://raw.githubusercontent.com/zimhwani/my-agents/${branch}/flight-agent/edge/dist/page.html`;
const root = path.join(here, "..");
const dist = path.join(here, "dist");
fs.mkdirSync(dist, { recursive: true });

// 1. The page.
const page = await esbuild.build({
  entryPoints: [path.join(here, "page.tsx")],
  bundle: true, minify: true, format: "iife", platform: "browser", target: ["es2020"], jsx: "automatic",
  tsconfig: path.join(root, "tsconfig.json"),
  define: { "process.env.NODE_ENV": '"production"' },
  write: false, outdir: dist, loader: { ".css": "css" },
});
const js = page.outputFiles.find((f) => f.path.endsWith(".js"))?.text ?? "";
const css = page.outputFiles.find((f) => f.path.endsWith(".css"))?.text ?? "";
const html = `<!doctype html>
<html lang="en-AU">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Harare Flight Agent</title>
<meta name="description" content="Voice-controlled flight tracker: Melbourne to Harare for two adults and two children.">
<style>${css}</style>
</head>
<body>
<div id="root"></div>
<script>${js.replace(/<\/script/g, "<\\/script")}</script>
</body>
</html>
`;
fs.writeFileSync(path.join(dist, "page.html"), html);

// 2. The server. npm packages stay external as Deno "npm:" specifiers.
const pkg = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
const pin = (name) => {
  const v = fs.readFileSync(path.join(root, "node_modules", name, "package.json"), "utf8");
  return JSON.parse(v).version;
};
const versions = { "@anthropic-ai/sdk": pin("@anthropic-ai/sdk"), zod: pin("zod") };
const denoNpm = {
  name: "deno-npm-specifiers",
  setup(build) {
    build.onResolve({ filter: /^(@anthropic-ai\/sdk|zod)(\/.*)?$/ }, (args) => {
      const m = /^(@anthropic-ai\/sdk|zod)(\/.*)?$/.exec(args.path);
      return { path: `npm:${m[1]}@${versions[m[1]]}${m[2] ?? ""}`, external: true };
    });
  },
};
// "remote" build: the page is not inlined; the function fetches it from PAGE_URL.
const stubPage = {
  name: "stub-page",
  setup(build) {
    build.onResolve({ filter: /dist\/page\.html$/ }, (args) => ({ path: args.path, namespace: "stub" }));
    build.onLoad({ filter: /.*/, namespace: "stub" }, () => ({ contents: 'export default "";', loader: "js" }));
  },
};
for (const [outfile, plugins] of [["index.js", [denoNpm]], ["index-remote.js", [stubPage, denoNpm]]]) {
  await esbuild.build({
    entryPoints: [path.join(here, "server.ts")],
    bundle: true, minify: outfile !== "index.js", format: "esm", platform: "neutral", target: ["es2022"],
    tsconfig: path.join(root, "tsconfig.json"),
    define: { "process.env.NODE_ENV": '"production"', "process.env": "globalThis.__ENV__", DEFAULT_PAGE_URL: JSON.stringify(DEFAULT_PAGE_URL) },
    loader: { ".html": "text" },
    plugins,
    outfile: path.join(dist, outfile),
    banner: { js: "globalThis.__ENV__ = globalThis.Deno ? Deno.env.toObject() : {};" },
  });
  console.log(`Wrote edge/dist/${outfile} (${(fs.statSync(path.join(dist, outfile)).size / 1024).toFixed(0)} kB)`);
}
console.log(`Wrote edge/dist/page.html (${(html.length / 1024).toFixed(0)} kB) for ${pkg.name}; remote build fetches ${DEFAULT_PAGE_URL}`);
