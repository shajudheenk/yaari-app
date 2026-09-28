import { useState, type FormEvent } from 'react';
import { supabase } from '../lib/supabase';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);

    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);

    if (error) {
      setError(
        /invalid login/i.test(error.message)
          ? 'That email and password were not recognised.'
          : error.message,
      );
    }
  }

  return (
    <div className="login-wrap">
      <form className="login" onSubmit={submit}>
        <div className="mk">Y</div>
        <h1>Trust &amp; Safety console</h1>
        <p className="lede">
          Staff access only. Console accounts are separate from the customer and
          provider apps, and each one carries a role recorded in <span className="mono">admin_users</span>.
        </p>

        {error && <div className="alert bad">{error}</div>}

        <div className="field">
          <label htmlFor="email">Work email</label>
          <input
            id="email" type="email" value={email} autoComplete="username"
            onChange={(e) => setEmail(e.target.value)} required
          />
        </div>

        <div className="field">
          <label htmlFor="password">Password</label>
          <input
            id="password" type="password" value={password} autoComplete="current-password"
            onChange={(e) => setPassword(e.target.value)} required
          />
        </div>

        <button className="btn primary" type="submit" disabled={busy}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  );
}
