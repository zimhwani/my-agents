# Welcome video: makeup clip candidates

Candidate replacements for the welcome-screen makeup clip. Each `candidate-N.mp4` is a 6 s preview encoded exactly to the app spec (1080x1920, 30 fps, H.264 ~6 Mb/s, yuv420p, no audio, faststart; center crop). `candidate-N.jpg` is a 540 px still at ~2 s; `contact-sheet.jpg` shows all five side by side.

## Sources searched

- **Pexels: blocked.** Every search request (`asian woman makeup artist`, `makeup artist applying`, `korean makeup`, `makeup brush face`, all with `?orientation=portrait`) returned HTTP 403 with a Cloudflare "Just a moment..." challenge page, so no Pexels clips could be reviewed from this environment.
- **Mixkit: worked.** I reviewed the `makeup` category (pages 1–2), plus `makeup-artist` and `beauty`. Every candidate page shows the **Mixkit Stock Video Free License**, which allows commercial use in apps without attribution.

All Mixkit makeup clips I found are **landscape (16:9)**. No portrait originals turned up, so every preview is a center crop.

## Candidates

| N | Source | Licence | What it shows | Original | East/SE Asian look? |
|---|--------|---------|---------------|----------|---------------------|
| 1 | https://mixkit.co/free-stock-video/a-skilled-makeup-artist-applies-makeup-base-to-a-young-52046/ | Mixkit Free | Artist presses a sponge on the model's cheek. Close-up, soft warm studio light, model looking down. | 3840x2160 landscape | Ambiguous: could read as mixed or Southeast Asian. Not clearly East Asian. |
| 2 | https://mixkit.co/free-stock-video/a-young-model-with-her-eyes-shut-gets-her-eyelid-52055/ | Mixkit Free | Same model, eyes closed, artist brushing on eyeshadow. Close-up, brush in frame after the crop. | 3840x2160 landscape | Same model as 1 (ambiguous / possibly SE Asian). |
| 3 | https://mixkit.co/free-stock-video/from-a-profile-view-a-young-woman-patiently-waits-for-52057/ | Mixkit Free | Profile extreme close-up, blush brush on cheek, artist's ringed hand in front. | 3840x2160 landscape | Same model as 1 (ambiguous). |
| 4 | https://mixkit.co/free-stock-video/bride-getting-her-makeup-and-hair-done-40592/ | Mixkit Free | Bride with short dark hair seen from the side/back, hands working on her face and hair. Face mostly hidden. | 3840x2160 landscape | Possibly East Asian (hair/profile), but the face is barely visible. |
| 5 | https://mixkit.co/free-stock-video/makeup-artist-working-in-her-beauty-salon-40540/ | Mixkit Free | Masked artist with glasses applies a brush to a client seen from behind (sleek dark bun, hoop earring). Salon setting, medium shot. | 3840x2160 landscape | Client's face isn't visible; the bun could read as East Asian. Less close-up than wanted. |

## Notes / caveats

- None is a clear match for "East/Southeast Asian woman, close-up, glam applied". 1–3 (one shoot, same model) are the closest on look, lighting and action. 2 is the strongest: eyeshadow with the brush clearly in frame.
- Center-cropping 16:9 to 9:16 keeps only the middle ~32% of the width. In 1 the sponge sits at the left edge, and in 3 the brush fills the foreground. A horizontal crop offset (e.g. `crop=1080:1920:x=...`) could reframe these from the 4K masters.
- No text or logos in any clip. In 1–4 the subject isn't looking at the camera.
- Full 4K masters (45–91 MB) were not committed. Download them from the source pages (`assets.mixkit.co/videos/<id>/<id>-2160.mp4`).
- Pexels may have better-matched portrait clips. Re-run the search from a browser or an environment that can pass the Cloudflare check.
