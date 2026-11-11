export const title = "Purrtine: add and manage a cat and a task";
export const state = (v) => {
  switch (v.screen) {
    case "cats": return v.cat ? "My Cats, Milo listed" : "My Cats, no Milo";
    case "catform": return v.fName ? "Add New Cat, name typed" : "Add New Cat, empty (Save off)";
    case "discard": return "Discard your changes?";
    case "tasks": return v.task ? "Tasks list, Brush coat listed" : "Tasks list, no task";
    case "taskform":
      if (v.fForm === "empty") return "Add Task, empty";
      return v.fForm === "daily" ? "Add Task, repeats daily" : "Add Task, title and cat set (Repeat Once)";
    case "taskedit": return "Edit Task";
    case "catedit": return "Edit Milo";
    case "deletealert": return "Delete this cat? alert";
  }
};
export const group = (v) =>
  ["cats", "catform", "discard", "catedit", "deletealert"].includes(v.screen) ? "Cats" : "Tasks";
export const colors = { Cats: "purple", Tasks: "teal" };
export const step = (a, f, t) => {
  switch (a) {
    case "OpenAddCat": return "you tap +";
    case "TypeCatName": return "you type a name";
    case "SaveCat": return "you tap Save";
    case "CloseCatFormClean": return "you tap Close";
    case "CloseCatFormChanged": return "you tap Close";
    case "DiscardChanges": return "you tap Discard Changes";
    case "KeepEditing": return null;
    case "GoToTasks": return "you open the Tasks tab";
    case "GoToCats": return "you open More, My Cats";
    case "OpenAddTask": return "you tap +, Custom Task";
    case "FillTitleAndCat": return "you type a title and pick the cat";
    case "SetDaily": return "you set Repeat to Daily";
    case "SaveTask": return f.fForm === "daily" ? "you tap Save (reminders are set)" : null;
    case "CancelTaskForm": return f.fForm === "empty" ? "you tap Cancel" : null;
    case "OpenEditTask": return "you tap the task";
    case "CloseEditTask": return "you tap Save or Cancel";
    case "DeleteTask": return "you swipe left, Delete";
    case "OpenEditCat": return "you tap Milo, Edit";
    case "CloseEditCat": return null;
    case "AskDeleteCat": return "you tap Delete Cat";
    case "CancelDeleteCat": return null;
    case "DeleteCat": return "you tap Delete (its tasks go too)";
  }
};
