# Usage: python3 Scripts/make_mascot_lids.py . App/Assets.xcassets-staging
# Re-run after changing an open-eye mascot pose, then copy each mascot_<pose>_lids.png into its
# App/Assets.xcassets/mascot_<pose>_lids.imageset and paste the printed eye boxes into
# MascotExpression.eyes (App/Design/Mascot.swift). Needs opencv-python-headless and numpy.
# Builds, per open-eye mascot pose, a full-canvas "skin" layer: the eyes painted over with Lockie's
# own surrounding orange (OpenCV inpainting), alpha only around the eyes. Prints each eye's box.
import cv2, numpy as np, os, json, sys
root, outdir = sys.argv[1], sys.argv[2]
poses = ['wave','worried','sad','thinking','clipboard','pointing']
boxes = {}
# pupil boxes (x, y, w, h) measured from the art's two dark, round eye blobs
SEEDS = {'wave': [(266,305,67,85),(432,332,69,87)], 'worried': [(253,321,63,80),(404,338,66,84)],
         'sad': [(223,403,82,66),(377,411,85,74)], 'thinking': [(233,299,75,75),(386,343,81,70)],
         'clipboard': [(244,316,70,88),(401,343,72,88)], 'pointing': [(274,306,65,81),(440,345,67,84)]}
for n in poses:
    d = f'{root}/App/Assets.xcassets/mascot_{n}.imageset'
    f = [x for x in os.listdir(d) if x.endswith('.png')][0]
    rgba = cv2.imread(f'{d}/{f}', cv2.IMREAD_UNCHANGED)
    bgr, a = rgba[:, :, :3], rgba[:, :, 3]
    H, W = a.shape
    b, g, r = [bgr[:, :, i].astype(int) for i in range(3)]
    lum = (r * 299 + g * 587 + b * 114) // 1000
    dark = (lum < 115) & (a > 200)
    whiteish = (r > 165) & (g > 160) & (b > 155) & ((np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)) < 70) & (a > 200)
    cand = (dark | whiteish).astype(np.uint8)
    # the two largest round dark blobs = the pupils
    nl, lab, st, _ = cv2.connectedComponentsWithStats(dark.astype(np.uint8), 8)
    # pupils: the dark blob under each measured pupil centre
    seeds = SEEDS[n]
    blobs = [(0, lab[y + h // 2, x + w // 2]) for (x, y, w, h) in seeds]
    assert all(i > 0 for _, i in blobs), n
    mask = np.zeros_like(a, np.uint8)
    nl2, lab2, st2, _ = cv2.connectedComponentsWithStats(cand, 8)
    eyes = []
    for _, i in blobs:
        x, y, w, h = st[i, :4]
        ys, xs = np.where(lab == i)
        # the dark + white component containing this pupil, limited to a padded box around it
        comp_ids = set(lab2[ys, xs].tolist())
        pad = 30
        x0, y0, x1, y1 = max(0, x - pad), max(0, y - pad), min(W, x + w + pad), min(H, y + h + pad)
        m = np.isin(lab2[y0:y1, x0:x1], list(comp_ids)).astype(np.uint8)
        # fill holes (highlights), then grow over the anti-aliased rim
        cnts, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
        m2 = np.zeros_like(m); cv2.drawContours(m2, cnts, -1, 1, -1)
        m2 = cv2.dilate(m2, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
        mask[y0:y1, x0:x1] |= m2
        ey, ex = np.where(m2)
        eyes.append([int(ex.min() + x0), int(ey.min() + y0), int(ex.max() - ex.min() + 1), int(ey.max() - ey.min() + 1)])
    eyes.sort()
    # Fill each eye with Lockie's own skin shading: fit a smooth quadratic (per colour channel) to the
    # orange skin pixels in a ring around the eye, ignoring cheeks, brows, mouth and highlights.
    skin = bgr.astype(np.float64).copy()
    orange = (r > 190) & (g > 50) & (g < 160) & (b < 110) & ((r - g) > 75) & (a > 250)
    nm, mlab = cv2.connectedComponents(mask)
    for k in range(1, nm):
        eye = (mlab == k).astype(np.uint8)
        ring = cv2.dilate(eye, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (61, 61))) & (1 - cv2.dilate(eye, np.ones((7, 7), np.uint8)))
        ys, xs = np.where((ring > 0) & orange)
        cy, cx = ys.mean(), xs.mean()
        def feats(yy, xx):
            u, v = (xx - cx) / 50.0, (yy - cy) / 50.0
            return np.stack([np.ones_like(u), u, v, u * u, u * v, v * v], 1)
        A = feats(ys.astype(float), xs.astype(float))
        ey, ex = np.where(cv2.dilate(eye, np.ones((5, 5), np.uint8)) > 0)
        F = feats(ey.astype(float), ex.astype(float))
        for ch in range(3):
            coef, *_ = np.linalg.lstsq(A, bgr[ys, xs, ch].astype(float), rcond=None)
            skin[ey, ex, ch] = F @ coef
    skin = np.clip(skin, 0, 255)
    alpha = cv2.GaussianBlur(cv2.dilate(mask, np.ones((3, 3), np.uint8)) * 255, (0, 0), 1.2)
    out = np.dstack([skin.astype(np.uint8), alpha])
    out[alpha == 0] = 0
    cv2.imwrite(f'{outdir}/mascot_{n}_lids.png', out, [cv2.IMWRITE_PNG_COMPRESSION, 9])
    boxes[n] = {'W': W, 'H': H, 'eyes': eyes}
print(json.dumps(boxes))
