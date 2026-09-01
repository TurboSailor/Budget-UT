// Convert a Budget.realm backup (iOS Budget App) into budget-bundle.json.
//
// Usage: node export.js [Budget.realm] [out.json]
// The realm npm package only ships prebuilds for desktop platforms, so this runs
// on the host (macOS/Linux), not on the phone. The resulting JSON bundle is what
// the Ubuntu Touch app imports (and re-exports losslessly for everything it uses).
//
// Node keeps native handles open after realm.close(); the process is killed by
// the parent (|| true) — the file is written and flushed before that.
const Realm = require('realm');
const fs = require('fs');

const src = process.argv[2] || 'Budget.realm';
const dst = process.argv[3] || 'budget-bundle.json';

const b64 = (v) => (v == null ? null : Buffer.from(v).toString('base64'));
const d2s = (v) => (v == null ? null : v.toISOString());

(async () => {
  const realm = await Realm.open({ path: src, readOnly: true });
  const skip = new Set(['SyncInfo', 'ZoneToken', 'CloudDatabase']); // CloudKit plumbing, not app data
  const pkOf = (schema, o) => o[schema.primaryKey];
  const out = { format: 'budget-ut/bundle1', exportedAt: new Date().toISOString(), source: 'Budget.realm', objects: {} };

  for (const schema of realm.schema) {
    if (skip.has(schema.name)) continue;
    const props = Array.isArray(schema.properties)
      ? schema.properties
      : Object.entries(schema.properties).map(([name, p]) => ({ name, ...p }));
    const rows = [];
    for (const o of realm.objects(schema.name)) {
      const r = {};
      for (const p of props) {
        const v = o[p.name];
        if (v === undefined) continue;
        if (v === null) { r[p.name] = null; continue; }
        if (p.type === 'data') r[p.name] = b64(v);
        else if (p.type === 'date') r[p.name] = d2s(v);
        else if (p.type === 'object') {
          // store both the target pk and its plain id: importer needs id mapping
          const t = realm.schema.find((s) => s.name === p.objectType);
          r[p.name] = v ? pkOf(t, v) : null;
        } else if (p.type === 'list') r[p.name] = Array.from(v);
        else r[p.name] = v;
      }
      rows.push(r);
    }
    out.objects[schema.name] = rows;
  }
  fs.writeFileSync(dst, JSON.stringify(out));
  console.error(`wrote ${dst}`);
  for (const [k, v] of Object.entries(out.objects)) console.error(`  ${k}: ${v.length}`);
  realm.close();
})().catch((e) => { console.error(e); process.exit(1); });
