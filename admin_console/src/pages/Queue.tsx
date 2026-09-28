import { useEffect, useState } from 'react';
import { supabase, DOC_LABEL, type ProviderDocument, type DocType } from '../lib/supabase';

type Row = ProviderDocument & { provider_name?: string; provider_phone?: string };

export default function Queue() {
  const [rows, setRows] = useState<Row[] | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);

  async function load() {
    const { data, error } = await supabase
      .from('provider_documents')
      .select('*, app_users:provider_id (full_name, phone)')
      .eq('status', 'pending')
      .order('created_at', { ascending: true });

    if (error) { setError(error.message); return; }

    setRows(
      (data ?? []).map((d: Record<string, unknown>) => {
        const u = d.app_users as { full_name?: string; phone?: string } | null;
        return { ...(d as unknown as ProviderDocument), provider_name: u?.full_name, provider_phone: u?.phone };
      }),
    );
  }

  useEffect(() => { load(); }, []);

  async function decide(id: string, status: 'verified' | 'rejected') {
    setBusy(id);
    setError(null);
    setNote(null);

    const patch: Record<string, unknown> = { status };
    if (status === 'verified') patch.verified_at = new Date().toISOString();
    else patch.rejection_reason = 'Rejected in console';

    const { error } = await supabase.from('provider_documents').update(patch).eq('id', id);
    setBusy(null);

    if (error) {
      setError(
        error.message.match(/row-level security|permission/i)
          ? 'Your console account is not a safety officer, so it cannot verify documents. Ask an admin to raise your role in admin_users.'
          : error.message,
      );
      return;
    }
    setNote(
      status === 'verified'
        ? 'Verified. The provider becomes bookable the moment every required credential is in place.'
        : 'Rejected. The provider stays blocked until they supply a valid document.',
    );
    load();
  }

  if (error && !rows) return <div className="alert bad">{error}</div>;
  if (!rows) return <div className="loading">Loading queue…</div>;

  return (
    <>
      <div className="head">
        <h1>Verification queue</h1>
        <p>
          Documents submitted but not yet checked. Every decision is written to an
          append-only audit trail with the operator who made it and what they saw —
          that record is what an insurer or endorsing body will ask for.
        </p>
      </div>

      {error && <div className="alert bad">{error}</div>}
      {note && <div className="alert info">{note}</div>}

      <section className="panel">
        <header>
          <h2>Awaiting verification</h2>
          <span className="note">{rows.length} document{rows.length === 1 ? '' : 's'}</span>
        </header>

        {rows.length === 0 ? (
          <div className="empty">Queue is clear.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Provider</th>
                <th>Credential</th>
                <th>Reference</th>
                <th>Expires</th>
                <th>Submitted</th>
                <th style={{ textAlign: 'right' }}>Decision</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((d) => (
                <tr key={d.id}>
                  <td className="who-cell">
                    <div className="n">{d.provider_name ?? '—'}</div>
                    <div className="m mono">{d.provider_phone ?? ''}</div>
                  </td>
                  <td>{DOC_LABEL[d.doc_type as DocType] ?? d.doc_type}</td>
                  <td className="mono" style={{ fontSize: 12 }}>{d.reference ?? '—'}</td>
                  <td className="mono" style={{ fontSize: 12.5 }}>{d.expires_on ?? 'No expiry'}</td>
                  <td className="hint">{new Date(d.created_at).toLocaleDateString('en-GB')}</td>
                  <td>
                    <div className="row-actions">
                      <button className="btn bad" disabled={busy === d.id} onClick={() => decide(d.id, 'rejected')}>
                        Reject
                      </button>
                      <button className="btn ok" disabled={busy === d.id} onClick={() => decide(d.id, 'verified')}>
                        {busy === d.id ? 'Saving…' : 'Verify'}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <p className="hint" style={{ maxWidth: '74ch' }}>
        Only <strong>basic</strong> DBS checks are recorded here. Enhanced DBS
        eligibility is restricted by statute and general home-services work very
        likely does not qualify — do not record or advertise enhanced checks
        without confirming eligibility with an umbrella body first.
      </p>
    </>
  );
}
