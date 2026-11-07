# Cat photo

A user adds or changes a cat's photo with the real system photo picker (Photos library), crops nothing,
and sees the photo on the cat's screens. The picker runs out of process, so axe cannot read its cells:
this recipe puts known pictures into the simulator's library, takes a screenshot, finds the cell in the
screenshot, and taps it by coordinates. Not yet proved (written from source 2026-11-07).

## Sub-features

- `photo-edit-pick` Edit Cat → photo circle → "Photo Library | Fotoğraf Arşivi" → pick → Save.
- `photo-add-pick` Add New Cat with a picked photo (a new cat with a photo from the first save).
- `photo-change` pick a second picture over the first.
- `photo-remove` "Remove Photo | Fotoğrafı Kaldır" → Save: the photo is gone.
- `photo-camera` "Camera | Kamera" shows only when a camera exists; the simulator has none, so the item
  is absent. Report it as not available.

## How to get to it (user POV)

- More | Daha Fazla → My Cats (`settings.shortcut.cats`) → a cat card (`cats.card.<name>`) → the cat's
  screen → "Edit | Düzenle" (`catDetail.editButton`) → "Edit Cat | Kedi Düzenle" sheet.
- The same sheet from a cat card's context menu → "Edit | Düzenle"; the cat screen also has an "Add photo |
  Fotoğraf ekle" chip while the cat has no photo.
- Add New Cat: Home "+" → Add Cat, or My Cats "+" (`cats.addButton`), see `add-cat.md`.
- In both forms the photo circle is one control: `catForm.photoMenu`, label "Add Photo | Fotoğraf Ekle"
  while there is no photo and "Edit Photo | Fotoğrafı Düzenle" once there is one. It opens a menu.

## Driving it with axe

Preconditions:

- Onboarding is done with the cat `Miso`, no photo. Data only from user screens.
- Two pictures with clearly different colours in the device's library. Make them outside the repo and add
  them with simctl (the slim profile keeps the `photos` service). Solid colours let you tell the cells and
  the result apart:

  ```bash
  UDID=$(cat /tmp/verify-purrtine.lock/udid)
  mkdir -p /tmp/vp-photos
  /usr/bin/python3 -I -c '
  import zlib, struct, sys
  def png(path, rgb, n=600):
      raw = b"".join(b"\x00" + bytes(rgb) * n for _ in range(n))
      def chunk(t, d):
          c = struct.pack(">I", len(d)) + t + d
          return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
      open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 2, 0, 0, 0))
          + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
  png("/tmp/vp-photos/red.png", (220, 30, 30)); png("/tmp/vp-photos/blue.png", (30, 60, 220))'
  xcrun simctl addmedia "$UDID" /tmp/vp-photos/red.png
  xcrun simctl addmedia "$UDID" /tmp/vp-photos/blue.png
  ```
  `vp.sh` has no helper for this; the commands above are the helper. Add `blue.png` after `red.png`, so
  blue is the newest picture. Not proved: that the library accepts them while the app runs (it should).

Steps:

- **Open the edit sheet.** `vp tap --label More --element-type RadioButton`, (`BackButton` until
  `settings.view` shows), `vp tap --id settings.shortcut.cats`, `vp tap --id cats.card.Miso`. The cat
  screen's avatar has the label "No photo | Fotoğraf yok" (record it: this is the "before").
  `vp shot cat-before`. Then `vp tap --id catDetail.editButton`. The sheet shows `catForm.photoMenu`
  with label "Add Photo", `catForm.saveButton` is `[disabled]` (edit mode saves only after a change).
- **Open the picker.** `vp tap --id catForm.photoMenu`. A menu shows. `vp ui` lists the menu items Camera, Photo Library
  | Fotoğraf Arşivi and (with a photo) Remove Photo. The Camera item IS present (measured 2026-11-07). `vp tap --label "Photo Library"` (Turkish
  `Fotoğraf Arşivi`). The system picker slides up in a different process.
- **See the picker.** Wait about 2 s, `vp ui` (it may hold only the app's own elements or a few picker
  elements; if it lists the picture cells with labels, tap those by label and skip the coordinates). Then
  `vp shot picker`; open the PNG (Read tool) and look at it.
- **Find the cell from the screenshot, do not hard-code.** In the PNG, find the red tile (and later the
  blue one). Take its centre in pixels (px, py). Convert to points: `scale = PNG width in pixels / screen
  width in points`. The pixel width: `sips -g pixelWidth <png>`; the point width: the width of the first
  (Application) frame in `vp ui` (390 on an iPhone 12, so scale 3 and the PNG is 1170 wide). Then
  `axe tap -x $((px/scale)) -y $((py/scale)) --tap-style physical --udid $UDID` (use real division; the
  values are integers or decimals, both work). Measured 2026-11-07: the picker lists the NEWEST picture first (blue top left, red next; iPhone 12 centres
  about red (196,362), blue (64,362) points). Read the shot anyway, do not store these.
  Tap each picture only once.
- **After the tap.** A single-pick picker dismisses itself on one tap and the form returns (measured: no "Add" step). If the picker is still up
  (an "Add" button at the top right, a check on the cell), `vp shot picker-selected`, find "Add" in the shot
  and tap its centre the same way. Then wait: a progress circle shows over the photo for a moment
  (label "Loading photo | Fotoğraf yükleniyor"). Poll `vp ui` until it is gone; Save is `[disabled]` while
  it loads.
- **Assert in the form.** `catForm.photoMenu` now has the label "Edit Photo | Fotoğrafı Düzenle";
  `catForm.saveButton` is enabled; no `catForm.photoProblem.tryAgainButton`. `vp shot photo-picked` shows
  the red photo in the circle (open it and check the colour). `vp tree photo-picked`.
- **Save and prove from a second view.** `vp tap --once --id catForm.saveButton`. The sheet closes. On the
  cat screen the avatar label is now "Tap to view photo | Fotoğrafı görüntülemek için dokunun" (was "No
  photo"), and the avatar shows red: `vp shot cat-after`, `vp tree cat-after`. Second and third views:
  back to My Cats, the `cats.card.Miso` card shows a red circle (`vp shot cats-list`); Home's cat card shows
  it too (`vp shot home-after`). Reopen Edit Cat: the photo circle reads "Edit Photo" and holds the red
  photo, loaded from the saved file (this is the proof the photo persisted, not only the form state).
- **Change.** In the sheet, `vp tap --id catForm.photoMenu`, "Photo Library", read the picker shot, tap the
  blue cell, Save with `vp tap --once`. The avatar turns blue in `cat-after-change`.
- **Remove.** `vp tap --id catForm.photoMenu`, the menu now also holds "Remove Photo | Fotoğrafı Kaldır"
  (destructive): `vp tap --label "Remove Photo"`. The circle shows the placeholder and the label becomes
  "Add Photo". Save: the cat screen's avatar label is "No photo" again.
- **Add-cat variant.** Per `add-cat.md` open Add New Cat, type a name (`Luna`), pick the photo the same
  way, Save (enabled once the name is valid and the load ended), then check the cat screen label and the
  My Cats card.
- **Record.** `echo "feature=cat-photo entry=edit-cat-photo-library result=pass" >> <evidence>/run.txt`
  and name the real picker in the report: this recipe is the proof that a photo pick was checked by hand.

## Gotchas

- This is the only recipe that uses a coordinate tap on purpose. The coordinates are read per run from
  `vp shot`, never stored; a different device, language or iOS version moves the picker.
- Never launch with `-inject-test-photo`: it needs `-ui-testing`, which the skill never uses. This recipe
  replaces it by driving the real picker.
- The picker needs no photo permission (it runs out of process); the app asks for none. A permission
  alert here would be unexpected: report it.
- If the picker shows no cells, the library is empty: check `xcrun simctl addmedia` printed no error and
  that the `photos` service is on (`simslim verify` in `vp doctor`). Slim devices keep it by profile.
- The picker may open at the "Albums" or "Photos" page; the cells you need are on "Photos" (the first
  segment). If the screenshot shows albums, tap "Photos" (read the shot) and shoot again.
- Cropping is not part of the pick: the form shows the photo as picked (`PhotoCropView` is another flow).
- A failed load shows "Couldn't load this photo… | Bu fotoğraf yüklenemedi…" with Try Again and Choose
  Another (`catForm.photoProblem.tryAgainButton`, `catForm.photoProblem.chooseAnotherButton`); a photo
  that cannot be used shows "This photo can't be used. | Bu fotoğraf kullanılamıyor."
- Autocorrect applies to the Add-cat name field too; type a real word.
- Measured 2026-11-07: while the picker is up, `vp ui` shows the edit form's tree behind it, not the picker's cells.
