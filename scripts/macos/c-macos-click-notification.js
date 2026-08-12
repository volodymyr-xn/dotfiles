#!/usr/bin/env osascript -l JavaScript

// Activate the topmost macOS notification via the Accessibility API.
// No argument        -> perform its default "open" action (same as clicking the body).
// Argument (string)  -> perform the action whose description contains that text
//                       (e.g. "Join", "Reply", "Mark as Read"), case-insensitive.
function run(argv) {
  const wanted = (argv && argv[0]) ? String(argv[0]).toLowerCase() : null;

  const nc = Application('System Events').processes.byName('NotificationCenter');
  if (nc.windows.length === 0) return;

  const SUBROLES = ['AXNotificationCenterAlert', 'AXNotificationCenterAlertStack'];
  const alerts = [];
  (function find(els) {
    for (const el of els) try {
      if (SUBROLES.includes(el.subrole())) alerts.push(el);
      else if (el.uiElements.length) find(el.uiElements());
    } catch (e) {}
  })(nc.windows[0].uiElements[0].uiElements[0].uiElements());

  if (alerts.length === 0) return;

  // Prefer an individual banner over a collapsed stack for activation.
  const alert = alerts.find(a => {
    try { return a.subrole() === 'AXNotificationCenterAlert'; } catch (e) { return false; }
  }) || alerts[0];

  const acts = alert.actions();

  // Safe accessor for an action's description.
  const desc = (a) => {
    try { return (a.description() || '').toLowerCase(); } catch (e) { return ''; }
  };

  let target;
  if (wanted) {
    target = acts.find(a => desc(a).includes(wanted));
  } else {
    // Default activation: explicit "show"/"open", else AXPress,
    // else the first action that is not a dismiss/secondary control.
    target =
      acts.find(a => desc(a) === 'show' || desc(a) === 'open') ||
      acts.find(a => { try { return a.name() === 'AXPress'; } catch (e) { return false; } }) ||
      acts.find(a => {
        const d = desc(a);
        return d !== 'close' && d !== 'clear all' && d !== 'options';
      });
  }

  if (target) target.perform();
}
