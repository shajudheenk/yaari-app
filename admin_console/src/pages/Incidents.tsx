import { useEffect, useState } from 'react';
import { supabase, type Incident } from '../lib/supabase';

const KIND_LABEL: Record<string, string> = {
  sos_customer: 'SOS — customer',
  sos_provider: 'SOS — provider',
  complaint: 'Complaint',
  no_show: 'No show',
  damage: 'Damage',
  safeguarding: 'Safeguarding',
  off_platform_payment: 'Off-platform payment',
  other: 'Other',
};

export default function Incidents() {
  const [rows, setRows] = useState<Incident[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let live = true;

    async function load() {
      const { data, error } = await supabase
        .from('incidents')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100);
      if (!live) return;
      if (error) setError(error.message);
      setRows((data as Incident[]) ?? []);
    }

    load();

    // Realtime: an SOS must surface without anyone refreshing the page.
    const channel = supabase
      .channel('incidents-live')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'incidents' }, load)
      .subscribe();

    return () => {
      live = false;
      supabase.removeChannel(channel);
    };
  }, []);

  if (error) return <div className="alert bad">{error}</div>;
  if (!rows) return <div className="loading">Loading incidents…</div>;

  const open = rows.filter((r) => r.status === 'open' || r.status === 'investigating');
  const sos = open.filter((r) => r.kind.startsWith('sos_'));
  const critical = open.filter((r) => r.severity === 'critical' || r.severity === 'high');

  return (
    <>
      <div className="head">
        <h1>Incidents</h1>
        <p>
          Two-way safety. A provider raising an SOS matters as much as a customer
          doing so — lone workers entering strangers' homes are the under-served
          risk in this category. This list updates live over Realtime.
        </p>
      </div>

      <div className="tiles">
        <div className="tile bad"><div className="v">{sos.length}</div><div className="k">Live SOS</div><div className="sub">Needs an operator now</div></div>
        <div className="tile warn"><div className="v">{critical.length}</div><div className="k">High / critical</div><div className="sub">Open and severe</div></div>
        <div className="tile"><div className="v">{open.length}</div><div className="k">Open cases</div><div className="sub">Including complaints</div></div>
        <div className="tile ok"><div className="v">{rows.length - open.length}</div><div className="k">Resolved</div><div className="sub">Last 100 records</div></div>
      </div>

      <section className="panel">
        <header>
          <h2>All incidents</h2>
          <span className="note">Newest first</span>
        </header>

        {rows.length === 0 ? (
          <div className="empty">
            No incidents recorded. Raising one from either app will appear here
            immediately, without a refresh.
          </div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Ref</th>
                <th>Type</th>
                <th>Severity</th>
                <th>Status</th>
                <th>Raised</th>
                <th>Description</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => {
                const urgent = r.kind.startsWith('sos_') && (r.status === 'open' || r.status === 'investigating');
                return (
                  <tr key={r.id} className={urgent ? 'blocked' : ''}>
                    <td className="mono" style={{ fontSize: 12.5, fontWeight: 650 }}>{r.ref}</td>
                    <td>{KIND_LABEL[r.kind] ?? r.kind}</td>
                    <td><Severity level={r.severity} /></td>
                    <td><Status status={r.status} /></td>
                    <td className="hint">{new Date(r.created_at).toLocaleString('en-GB')}</td>
                    <td className="hint" style={{ maxWidth: 320 }}>{r.description ?? '—'}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </section>
    </>
  );
}

function Severity({ level }: { level: Incident['severity'] }) {
  const map: Record<string, string> = { critical: 'bad', high: 'bad', medium: 'warn', low: 'mute' };
  return <span className={`chip ${map[level] ?? 'mute'}`}>{level}</span>;
}

function Status({ status }: { status: Incident['status'] }) {
  const map: Record<string, string> = {
    open: 'bad', investigating: 'warn', resolved: 'ok', closed: 'mute',
  };
  return <span className={`chip ${map[status] ?? 'mute'}`}>{status}</span>;
}
