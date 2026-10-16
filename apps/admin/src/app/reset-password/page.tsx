"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { CheckCircle2, KeyRound } from "lucide-react";
import { api } from "@/lib/api";
import styles from "../../components/admin-app.module.css";

export default function ResetPasswordPage() {
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [done, setDone] = useState(false);
  const [loading, setLoading] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    const token = new URLSearchParams(window.location.search).get("token");
    if (!token) { setMessage("Liên kết không chứa mã đặt lại mật khẩu."); return; }
    setLoading(true);
    try { await api.resetPassword(token, password); setDone(true); }
    catch (error) { setMessage(error instanceof Error ? error.message : "Không thể đặt lại mật khẩu"); }
    finally { setLoading(false); }
  }

  return <main className={styles.resetPage}><form className={styles.resetCard} onSubmit={submit}>
    <div className={styles.loginMark}>{done ? <CheckCircle2 /> : <KeyRound />}</div>
    <p className={styles.eyebrow}>ANZEN TRADING SECURITY</p>
    <h1>{done ? "Mật khẩu đã cập nhật." : "Tạo mật khẩu mới."}</h1>
    <p>{done ? "Bạn có thể quay lại trang quản trị và đăng nhập bằng mật khẩu mới." : "Mật khẩu cần có ít nhất 8 ký tự."}</p>
    {!done && <><label>Mật khẩu mới<input type="password" minLength={8} value={password} onChange={(event) => setPassword(event.target.value)} required /></label>{message && <div className={styles.formMessage}>{message}</div>}<button className={styles.primaryButton} disabled={loading}>{loading ? "Đang cập nhật..." : "Đặt lại mật khẩu"}</button></>}
    {done && <Link className={styles.primaryButton} href="/">Về trang đăng nhập</Link>}
  </form></main>;
}
