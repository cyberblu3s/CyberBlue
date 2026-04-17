/* status.js — bootstrap fallback.
 *
 * This file is regenerated every 30 seconds by the systemd timer
 * cbsoc-status.timer (service: cbsoc-status.service, script:
 * /usr/local/bin/cbsoc-status-refresh). The generator walks `docker ps`,
 * resolves container health, and writes a fresh window.STATUS object.
 *
 * The copy shipped in the repo is a placeholder so the page still renders
 * before the first generator run.
 */
window.STATUS = {
  host: (typeof location !== 'undefined' && location.hostname) || 'localhost',
  ts:   0,
  containers: {},
};
