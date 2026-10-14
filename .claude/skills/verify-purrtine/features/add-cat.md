# Add a cat

A user adds another cat after onboarding. The cat appears in More → My Cats and can be picked as a
task's cat. Partly driven 2026-10-14, see the open notes under Gotchas; the next full run corrects this file.

## Sub-features

- `cat-add-home` opens the Add New Cat sheet from the Home tab "+" menu.
- `cat-add-cats` opens it from More → My Cats → "+".
- `cat-save` saves a named cat; Save stays disabled while the name is empty.
- `cat-cancel` closes the sheet without a new cat.

## How to get to it (user POV)

- Home tab → "+" (Add | Ekle) in the top bar → "Add Cat | Kedi Ekle".
- More | Daha Fazla tab → "My Cats | Kedilerim" card → "+" in the top bar.
- Tasks | Görevler tab, only while no cat exists → "Add Your First Cat | İlk Kedini Ekle".

## Driving it with axe

Preconditions:

- Onboarding is done and the Home tab shows (`home.view` in the tree).
- No cat named `Tarcin` exists.

- **Open My Cats.** `vp tap --label More --element-type RadioButton`
  (Turkish: `Daha Fazla`), then `vp tap --id settings.shortcut.cats`.
  The tree holds `cats.view`, and the onboarding cat shows in the list.
- **Open the sheet.** `vp tap --id cats.addButton --element-type Button` (two elements share the id; without the type axe taps nothing). The sheet title
  reads "Add New Cat | Yeni Kedi Ekle"; `catForm.saveButton` (label `Done`) is disabled.
- **Enter the name.** `vp tap --id catForm.nameField`, then `axe type 'Tarcin' --udid $UDID` (axe cannot type `ç`/`ı`: "No keycode found").
  `catForm.saveButton` becomes enabled.
- **Save.** `vp shot cat-form-filled`, then `vp tap --id catForm.saveButton`. The sheet
  closes.
- **Proof.** The My Cats list holds both cats. `vp shot cats-list` and `vp tree cats-list`; the tree
  has a label with the typed name (`Tarcin`; see the open note about autocorrect).
- **Cancel path.** Open the sheet again, type `Discard`, tap `catForm.cancelButton` (label `Close`). A sheet asks
  "Are you sure you want to discard your changes?"; tap `Discard Changes`. The list has no `Discard` card.

## Gotchas

- Open question from the 2026-10-14 partial drive: the field held `Tarcin` but the saved card read
  `Tar in` (autocorrect on save is the suspect). Drive again with a name that autocorrect leaves alone
  and note the result here before dropping the draft mark.

- The Home "+" menu has no identifier, only the label "Add | Ekle": `vp tap --label Add --element-type Button`
  on the Home tab (the Tasks tab "+" has the same label, so be on Home).
- "Add Photo" opens the system photo picker, which runs out of process: axe and `snapshot_ui` see none
  of its cells. Do not try to pick a photo; say in the report that the photo path was not checked.
- The camera choice asks for camera permission; the simulator has no camera. Skip it.
