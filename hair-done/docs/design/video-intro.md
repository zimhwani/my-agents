# The welcome video

The first screen plays three short clips behind the wordmark, muted and looping:
someone getting their hair braided, cut to someone getting glam done, cut to
someone getting nails done. Same approach as the FarmLink welcome screen (a
full-bleed muted video with a dark gradient and the copy over it), but bundled
in the app rather than streamed, so it plays on the first launch with no signal.

## What the code does

`Features/Onboarding/IntroVideo.swift`:

- `IntroClips` lists the three slots. Each resolves to a bundled file in
  `HairDone/Resources/Intro/` first, then an optional remote URL, then nothing.
- `IntroVideoView` plays them with `AVQueuePlayer`, muted, aspect-fill, hard
  cuts, and refills the queue when the last one ends so it loops for ever.
  Audio is set to ambient so it never ducks whatever she's listening to.
- `IntroBackdrop` puts an ink gradient over the video (25% at the top, 92% at
  the bottom) so paper-coloured type reads on any footage.
- If there are no clips, or Reduce Motion or Low Power Mode is on, the screen
  shows `IntroPlaceholderView` instead: six work tiles crossfading every 3.5 s.
  Nothing breaks; it just isn't a video.

## The three clips

| File | What's in it | Feels like |
|---|---|---|
| `intro-hair.mp4` | Hands braiding or blow-drying. Knotless braids being parted, or a round brush pulling through a blow-dry. Tight on the hands and hair. | Patient, rhythmic |
| `intro-makeup.mp4` | A brush or sponge on a cheek, lashes going on, or a lip being lined. Eyes closed is fine. | Calm, a little glam |
| `intro-nails.mp4` | A brush of polish going onto a nail, or a gel lamp lighting up. The classic 💅 shot. | Precise, satisfying |

Rules, from brand.md's photography direction: real work, natural light where
possible, hands and hair rather than faces, women of different ages and skin
tones across the three, no product shots, no ring lights in frame, no logos on
kit. It should look like a friend filmed it well, not like a salon ad.

## Spec

- Portrait 1080 × 1920, H.264 in an `.mp4` container, 24 or 30 fps, no audio track.
- 4 to 6 seconds each. The loop is hair → makeup → nails → hair, so the last
  frame of nails should cut cleanly to the first frame of hair.
- Under 6 MB each. Export at a bitrate around 6 Mbps; these are behind a
  gradient so they can be softer than a hero video.
- No text, no faces looking at camera, nothing that dates it.

Trim and compress on the Mac with:

```bash
ffmpeg -i in.mov -ss 0 -t 5 -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920" \
  -c:v libx264 -b:v 6M -pix_fmt yuv420p -an -movflags +faststart intro-nails.mp4
```

## Where to get them

Best: shoot them with the first three pros you sign. Three ten-minute visits
with a phone in good light, and the footage is yours, of real work, by women
who'll be in the app. That's the version to ship.

Until then, free stock that's licensed for this (no attribution needed for the
Mixkit and Pexels licences; still check the page):

- Mixkit: search "nail polish", "manicure", "braiding hair", "makeup artist".
- Pexels: search "nail polish application", "hair braiding close up", "makeup brush".
- Pixabay: same terms. Pixabay's licence also allows it.

Pick portrait clips or ones that crop to portrait without losing the hands.
Avoid anything with a visible face looking at camera and anything with a brand.

## Adding them

1. Put the three files in `HairDone/Resources/Intro/` with the exact names above.
2. `xcodegen generate` (it picks up the whole folder as resources).
3. Run. The welcome screen plays them. Remove any one and the others still play;
   remove all three and the placeholder shows.

To stream instead of bundle, put the URLs into `IntroClips.all`'s `remote`
slots. Bundling is better: it plays offline, on first launch, and it never
changes under you.
