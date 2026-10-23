import Image from "next/image";
import Link from "next/link";
import { ArrowRight, ArrowUpRight, Mail } from "lucide-react";
import styles from "../oauth-page.module.css";

export const supportEmail = "ndkvip@gmail.com";

const navItems = [
  { href: "/oauth", label: "Tổng quan", key: "home" },
  { href: "/oauth/privacy", label: "Quyền riêng tư", key: "privacy" },
  { href: "/oauth/terms", label: "Điều khoản", key: "terms" },
  { href: "/oauth/support", label: "Hỗ trợ", key: "support" },
] as const;

type ActivePage = (typeof navItems)[number]["key"];

export function OAuthHeader({ active = "home" }: { active?: ActivePage }) {
  return (
    <header className={styles.header}>
      <Link className={styles.brand} href="/oauth" aria-label="ANZEN TRADING trang chủ">
        <Image
          src="/branding/anzen-trading-mark.png"
          alt=""
          width={44}
          height={44}
          loading="eager"
        />
        <span className={styles.brandText}>
          <strong>ANZEN TRADING</strong>
          <small>Trading education</small>
        </span>
      </Link>

      <nav className={styles.nav} aria-label="Điều hướng website">
        {navItems.map((item) => (
          <Link
            key={item.key}
            className={item.key === active ? styles.navLinkActive : styles.navLink}
            href={item.href}
            aria-current={item.key === active ? "page" : undefined}
          >
            {item.label}
          </Link>
        ))}
      </nav>

      <a className={styles.headerCta} href={`mailto:${supportEmail}`}>
        <Mail size={15} strokeWidth={2.2} aria-hidden="true" />
        Liên hệ
      </a>
    </header>
  );
}

export function OAuthFooter() {
  return (
    <footer className={styles.footer}>
      <div className={styles.footerBrand}>
        <Image src="/branding/anzen-trading-mark.png" alt="" width={28} height={28} />
        <span>ANZEN TRADING</span>
      </div>
      <p>© {new Date().getFullYear()} ANZEN TRADING. Công cụ học tập và ghi chép giao dịch.</p>
      <nav className={styles.footerNav} aria-label="Liên kết cuối trang">
        <Link href="/oauth/privacy">Quyền riêng tư</Link>
        <Link href="/oauth/terms">Điều khoản</Link>
        <Link href="/oauth/support">Hỗ trợ</Link>
      </nav>
    </footer>
  );
}

export function Eyebrow({ children }: { children: React.ReactNode }) {
  return <p className={styles.eyebrow}>{children}</p>;
}

export function PhoneShot({
  src,
  alt,
  label,
  className = "",
  eager = false,
}: {
  src: string;
  alt: string;
  label?: string;
  className?: string;
  eager?: boolean;
}) {
  return (
    <figure className={`${styles.phoneFigure} ${className}`}>
      <div className={styles.phoneFrame}>
        <div className={styles.phoneSpeaker} aria-hidden="true" />
        <Image
          src={src}
          alt={alt}
          fill
          sizes="(max-width: 760px) 70vw, 300px"
          loading={eager ? "eager" : "lazy"}
          fetchPriority={eager ? "high" : undefined}
        />
      </div>
      {label ? <figcaption>{label}</figcaption> : null}
    </figure>
  );
}

export function PageHeading({
  eyebrow,
  title,
  description,
  active,
}: {
  eyebrow: string;
  title: string;
  description: string;
  active: ActivePage;
}) {
  return (
    <>
      <OAuthHeader active={active} />
      <section className={styles.pageHeading}>
        <Eyebrow>{eyebrow}</Eyebrow>
        <h1>{title}</h1>
        <p>{description}</p>
      </section>
    </>
  );
}

export function MoreLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link className={styles.moreLink} href={href}>
      {children}
      <ArrowRight size={16} strokeWidth={2.2} aria-hidden="true" />
    </Link>
  );
}

export function ExternalMailLink({ subject, children }: { subject: string; children: React.ReactNode }) {
  return (
    <a className={styles.moreLink} href={`mailto:${supportEmail}?subject=${encodeURIComponent(subject)}`}>
      {children}
      <ArrowUpRight size={16} strokeWidth={2.2} aria-hidden="true" />
    </a>
  );
}
