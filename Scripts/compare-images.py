#!/usr/bin/env python3
"""Compare rendered field crops. Requires Pillow and NumPy; ignores UI/status-bar pixels."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("reference", type=Path)
parser.add_argument("candidates", type=Path, nargs="+")
parser.add_argument("--crop", type=int, nargs=4, required=True,
                    metavar=("LEFT", "TOP", "RIGHT", "BOTTOM"))
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
full_reference = Image.open(args.reference).convert("RGB")
left, top, right, bottom = args.crop
assert 0 <= left < right <= full_reference.width and 0 <= top < bottom <= full_reference.height, "Crop outside image bounds"
reference_image = full_reference.crop(args.crop)
reference = np.asarray(reference_image).astype(np.int16)
rows = []
for path in args.candidates:
    full_candidate = Image.open(path).convert("RGB")
    assert full_candidate.size == full_reference.size, "Mismatched screenshot dimensions"
    image = full_candidate.crop(args.crop)
    candidate = np.asarray(image).astype(np.int16)
    assert candidate.shape == reference.shape, "Mismatched image sizes"
    delta = np.abs(candidate - reference)
    rows.append({"candidate": path.name, "meanAbsoluteChannelError": float(delta.mean()),
                 "maxAbsoluteChannelError": int(delta.max()),
                 "p99AbsoluteChannelError": float(np.percentile(delta, 99)),
                 "changedPixelFraction": float(np.any(delta > 0, axis=2).mean())})
result = {"reference": args.reference.name, "crop": args.crop,
          "size": list(reference_image.size), "channelRange": "0–255 encoded RGB",
          "notes": "Static 100K field on the same simulator. Crops exclude changing UI. "
                   "Pixel differences are reported, not a universal perceptual-equivalence score.",
          "comparisons": rows}
args.output.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
