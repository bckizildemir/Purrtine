# Add a cat

A user adds another cat after onboarding. The cat appears in More → My Cats and can be picked as a
task's cat. Proved on 2026-10-14 (iPhone 12, iOS 26.5, English) and again on 2026-10-15 (iPhone 12, iOS 27.0, English,
`~/verify-evidence/purrtine/2026-10-15-014147-3a31/`): save from My Cats and the cancel path.

## Sub-features

- `cat-add-home` opens the Add New Cat sheet from the Home tab "+" menu.
- `cat-add-cats` opens it from More → My Cats → "+".
- `cat-save` saves a named cat; Save stays disabled while the name is empty (after trimming spaces).
- `cat-cancel` closes the sheet without a new cat; with a changed field it asks to discard first.

## How to get to it (user POV)

- Home tab → "+" (Add | Ekle) in the top bar → "Add Cat | Kedi Ekle".
- More | Daha Fazla tab → "My Cats | Kedilerim" card → "+" in the top bar.
- My Cats while no cat exists → the empty-state button `cats.empty.addButton`.
- Tasks | Görevler tab, only while no cat exists → "Add Your First Cat | İlk Kedini Ekle" (no identifier).

## Driving it with axe

Preconditions:

- Onboarding is done and the Home tab shows (`home.view` in the tree).
- No cat named `Milo` exists.

- **Open My Cats.** `vp tap --label More --element-type RadioButton` (Turkish: `Daha Fazla`), then
  `vp tap --id settings.shortcut.cats`. The tree holds `cats.view` and `cats.card.Miso`.
- **Open the sheet.** `vp tap --id cats.addButton --element-type Button` (a `Group` and a `Button` share
  the id; without the type axe taps nothing). The heading reads "Add New Cat | Yeni Kedi Ekle";
  `catForm.saveButton` (label `Done` on iOS 26) is disabled, and `catForm.nameField` shows the
  placeholder `Fluffy`.
- **Enter the name.** `vp tap --id catForm.nameField`, then `axe type 'Milo' --udid $UDID`.
  `catForm.saveButton` becomes enabled.
- **Save.** `vp shot cat-form-filled`, then `vp tap --once --id catForm.saveButton`. The sheet closes.
- **Proof.** The My Cats list holds `cats.card.Milo` (`Milo, Unknown`) and `cats.card.Miso`.
  `vp shot cats-list` and `vp tree cats-list`.
- **Cancel path.** Open the sheet again, type `Discard`, `vp tap --id catForm.cancelButton` (label `Close`
  on iOS 26). A sheet asks "Are you sure you want to discard your changes?";
  `vp tap --label 'Discard Changes' --element-type Button`. The list has no new card.
- **Record.** `echo "feature=add-cat entry=more-my-cats result=pass" >> <evidence>/run.txt`.

## Gotchas

- Type a real dictionary word as the name (`Milo`, `Luna`). The name field keeps the keyboard's
  autocorrect, and the save takes its suggestion: on 2026-10-14 `Tarcin` showed the suggestion `Tar in`
  above the keyboard (`vp ui` lists it as a `GenericElement`), and a save stored `Tar in`
  (`~/verify-evidence/purrtine/2026-10-14-215623-2414/19-cats-list.json`). axe cannot
  type `ç`/`ı` ("No keycode found"). Whether cat names should skip autocorrect is a product question,
  not a skill fix.
- The toolbar labels `Done`/`Close` come from the iOS 26 and 27 system button roles; iOS 18 shows `Save`/`Close`.
  Use the identifiers.
- The Home "+" menu has no identifier, only the label "Add | Ekle": `vp tap --label Add --element-type Button`
  on the Home tab (the Tasks tab "+" has the same label, so be on Home).
- The More tab keeps its navigation stack: after this feature it reopens on `cats.view`. Another feature
  that starts from a More shortcut taps `BackButton` first.
- "Add Photo" opens the system photo picker, which runs out of process: axe and `snapshot_ui` see none
  of its cells. Do not try to pick a photo; say in the report that the photo path was not checked.
- The camera choice asks for camera permission; the simulator has no camera. Skip it.
