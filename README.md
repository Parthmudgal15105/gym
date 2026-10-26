# Gym — workout calendar and journal

I built Gym to keep my workouts, exercises, weights and reps in one local journal.

- Calendar with day-by-day workout logging
- Seven body parts, editable exercise defaults, and per-set weights and reps
- Insights for recorded workouts, sets, muscle balance and exercise history
- Local storage, JSON backup/restore, and a Swift/WebKit macOS wrapper

## Try it online

https://gym-journal-kappa.vercel.app

The hosted app saves workouts in your browser. No sign-in or cloud sync.

## Try it locally

```sh
git clone https://github.com/Parthmudgal15105/gym.git
cd gym
python3 -m http.server 8000 --directory dist
```

Open http://localhost:8000 . No account, dependency install or build step is needed for the browser version. The public version starts empty; no personal workout records or health notes are included.

## Build the Mac app

Requires macOS 14+ and Xcode Command Line Tools. From this directory:

```sh
./build.sh
```

This builds a locally ad-hoc-signed app at ~/Applications/Gym.app. It is not a notarized App Store release.

## Storage and limitations

Workout data stays in this browser/device. There is no cloud sync. Browser data can be cleared, so export backups. The Mac wrapper also keeps a local journal backup. Insights reflect the data entered, not independently verified workout performance. Decorative exercise images are AI-generated and are not coaching or technique instructions; see dist/assets/exercises/README.md.

## Source

By Parth Mudgal. Vanilla JavaScript, HTML/CSS and Swift/AppKit/WebKit. This is a sanitized distribution of my local Gym app with an empty starting journal.
