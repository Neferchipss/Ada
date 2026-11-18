---
name: seedream-prompting
description: >
  Seedream (ByteDance Seed image model, 4.x / 5.x) prompt-writing for game character production: reference views, turnarounds, A-pose sheets, prop removal, fur-only / hairless base bodies, and multi-image material combines. Use whenever a prompt is going to Seedream (Higgsfield seedream_*, ElevenLabs Image & Video "Seedream 5.5", BytePlus ModelArk), or when the user asks how to prompt Seedream. Do NOT reuse long ChatGPT-style prompts here.
---

# Seedream prompting (game production)

Source: official BytePlus ModelArk "Seedream 4.0-4.5 prompt guide"
(https://docs.byteplus.com/en/docs/ModelArk/seedream-4-0-5-0-prompt-guide), plus what held up in real character work.

## The official rules

1. **Short and precise.** Seedream 4.x/5.x understands more from less text. Stacked adjectives, repeats and long lists dilute the instruction. Aim for 2-5 plain sentences.
2. **Natural language, not tags.** Subject + action + environment as sentences. "A yak-headed brute standing in A-pose", not "yak, brute, A-pose, 8k".
3. **Say what the image is for.** "A character turnaround reference for 3D modelling" steers layout and lighting better than describing the lighting alone.
4. **Reference images: name the target.** Say what to KEEP from the reference (body shape, proportions, horns, skin) and then what to GENERATE (the new view or scene).
5. **Edits: one clear instruction + what stays unchanged.** No vague pronouns ("him", "that one"); name the thing.
6. **Several inputs: give each image one job.** "Keep the shape of Image 1, the face of Image 2, the material of Image 3."
7. **Consistent series: ask for "a set of N".** "Generate a set of 3 images ..." makes images that share one character and style. Use it for turnarounds.
8. **Hard regions:** draw an arrow, box or scribble on the input image and refer to it ("the area marked in red").
9. Text inside the image goes in "double quotes".

## Game-pipeline rules on top

- Production references are not film stills: flat even neutral light, no cast shadow, plain light-grey background, hair at rest (no wind), no VFX.
- Hands break often. Add one short clause: "each hand has five fingers, one thumb and four fingers". In an A-pose, palms face the thighs and thumbs point forward. Count the fingers first when reviewing.
- When asking for space between arm and body, say the arm length stays as in the reference, or the model stretches the arms.
- When removing hair or props, say the body mass stays the same, or the model slims the character down.
- The inner/hidden body may be simplified for the next steps (smooth groin, clear armpits, a neck under a hump). Say so in the prompt as a base-mesh purpose.
- One output per run unless variants are wanted. Many front-ends default to 4.

## Templates

**New view from a front reference**
> Character turnaround reference for 3D modelling. Keep the character from the reference image exactly: body shape, proportions, skin and horns. Show him in strict side profile, his left side toward the camera, facing the left edge of the frame. Flat neutral light, plain light-grey background.

**Turnaround set (preferred for views)**
> Generate a set of 3 images: a character turnaround of the creature in the reference image for 3D modelling. Image 1: left side profile, facing left. Image 2: back view. Image 3: right side profile, facing right. Keep the body shape, proportions, skin, horns and A-pose identical in all three. Flat neutral light, plain light-grey background.

**Remove props, keep fur**
> Remove all armour, cloth, chains, jewellery and other props from the creature in the reference image. Keep his fur, body shape, proportions, pose, horns and camera exactly the same. Flat neutral light, plain light-grey background.

**Hairless base body**
> Remove all hair and fur from the creature in the reference image to show the bare body for a game base mesh. Keep his full body mass, proportions, pose, horns and face shape exactly the same. Smooth simplified groin. Flat neutral light, plain light-grey background.

**Multi-image combine (clay + face + materials)**
> Game production character reference for 3D modelling and texturing. Keep the exact shape and pose of Image 1. Use the face of Image 2. Use Image 3 for the hair, Image 4 for the armour plates, Image 5 for the brass fittings. Front view, flat neutral light, plain light-grey background.

## Review checklist

1. Is the angle right? A true profile shows one eye and one horn, and the chest is seen edge-on. A 3/4 view means the prompt was too soft; ask again more briefly, or use the "set of N" template.
2. Count the fingers on each hand.
3. Did the mass hold (hump, belly, limb thickness)?
4. Any leftovers: props, wind, cast shadow, scene background?
A broken result is a fresh generation with a clearer prompt, not a pile of edits.
