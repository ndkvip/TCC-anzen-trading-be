import type { Metadata } from "next";
import Link from "next/link";
import { ArrowDownRight, ArrowRight, CloudOff, FileText, Maximize2, ShieldCheck, Sparkles } from "lucide-react";
import { Eyebrow, MoreLink, OAuthFooter, OAuthHeader, PhoneShot } from "./components/oauth-shared";
import styles from "./oauth-page.module.css";

export const metadata: Metadata = {
  title: "ANZEN TRADING | Học có hệ thống, giao dịch có kỷ luật",
  description:
    "ANZEN TRADING là không gian di động để học kiến thức, lập kế hoạch và ghi nhật ký giao dịch.",
};

const screenshots = [
  {
    src: "/app-screens/home.webp",
    alt: "Màn hình Trang chủ của ứng dụng ANZEN TRADING",
    label: "Trang chủ",
    text: "Bắt đầu mỗi ngày với một không gian rõ ràng để học và quan sát chính mình.",
  },
  {
    src: "/app-screens/knowledge.webp",
    alt: "Màn hình Kiến thức của ứng dụng ANZEN TRADING",
    label: "Kiến thức",
    text: "Theo dõi bài học, flashcard và tiến độ theo từng chủ đề.",
  },
  {
    src: "/app-screens/journal.webp",
    alt: "Màn hình Nhật ký của ứng dụng ANZEN TRADING",
    label: "Nhật ký",
    text: "Ghi lại bối cảnh, kết quả và cảm nhận sau mỗi phiên giao dịch.",
  },
  {
    src: "/app-screens/plan.webp",
    alt: "Màn hình Plan của ứng dụng ANZEN TRADING",
    label: "Plan",
    text: "Đặt kế hoạch theo ngày, tuần hoặc tháng trước khi hành động.",
  },
  {
    src: "/app-screens/profile.webp",
    alt: "Màn hình Cá nhân của ứng dụng ANZEN TRADING",
    label: "Cá nhân",
    text: "Quản lý tài khoản, dữ liệu và các thiết lập của bạn.",
  },
];

export default function OAuthInformationPage() {
  return (
    <main className={styles.page}>
      <div className={styles.backgroundOrb} aria-hidden="true" />
      <OAuthHeader />

      <section className={styles.hero} id="top">
        <div className={styles.heroCopy}>
          <Eyebrow>ANZEN TRADING MOBILE APP</Eyebrow>
          <h1><span>Học có hệ thống.</span> <span>Giao dịch có kỷ luật.</span></h1>
          <p className={styles.heroLead}>
            Một workspace di động để học kiến thức, lập plan, ghi nhật ký và quan sát quá trình của chính bạn —
            gọn gàng, có cấu trúc, đúng với nhịp làm việc mỗi ngày.
          </p>
          <div className={styles.heroActions}>
            <Link className={styles.primaryButton} href="#screenshots">
              Xem app thực tế <ArrowDownRight size={17} strokeWidth={2.4} aria-hidden="true" />
            </Link>
            <Link className={styles.secondaryButton} href="/oauth/support">
              Cần hỗ trợ <ArrowRight size={16} strokeWidth={2.3} aria-hidden="true" />
            </Link>
          </div>
          <div className={styles.heroMeta}>
            <span><i className={styles.metaDot} />Kiến thức · Plan · Nhật ký</span>
            <span><i className={styles.metaDot} />Hỗ trợ lưu dữ liệu offline</span>
          </div>
        </div>

        <div className={styles.heroVisual}>
          <div className={styles.heroStamp}>
            <Sparkles size={16} aria-hidden="true" />
            <span>HỌC · PLAN · NHẬT KÝ</span>
          </div>
          <PhoneShot
            src="/app-screens/home.webp"
            alt="Ảnh chụp màn hình thật của Trang chủ ANZEN TRADING"
            label="Ảnh chụp từ ứng dụng ANZEN TRADING"
            className={styles.heroPhone}
            eager
          />
          <div className={styles.heroNote}>
            <span className={styles.noteNumber}>MỖI NGÀY, MỘT BƯỚC</span>
            <span>Chuẩn bị trước phiên. Ghi chép sau phiên. Nhìn lại để hiểu mình hơn.</span>
          </div>
        </div>
      </section>

      <section className={styles.introBand}>
        <div className={styles.sectionLabel}>
          <span>01</span>
          <span>Vì sao ANZEN TRADING</span>
        </div>
        <div className={styles.introContent}>
          <h2>Biến thói quen rời rạc thành một quy trình có thể nhìn lại.</h2>
          <p>
            Mỗi phần trong app phục vụ một bước: nạp kiến thức, chuẩn bị kế hoạch, thực hiện, rồi ghi lại điều đã xảy ra.
            Bạn không cần mở nhiều công cụ để nhìn thấy toàn bộ quá trình.
          </p>
        </div>
      </section>

      <section className={styles.featureGrid} aria-label="Tính năng chính">
        <article className={`${styles.featureCard} ${styles.featureCardLarge}`}>
          <div className={styles.featureIcon}><FileText size={21} aria-hidden="true" /></div>
          <span className={styles.featureIndex}>01 / KNOWLEDGE</span>
          <h3>Học theo lộ trình, nhớ bằng thực hành.</h3>
          <p>Bài học, flashcard, bài tập và điểm số được gom về một nơi để bạn biết mình đang ở đâu.</p>
          <Link href="#knowledge" className={styles.featureLink}>Xem màn hình Kiến thức <ArrowRight size={15} aria-hidden="true" /></Link>
        </article>
        <article className={styles.featureCard}>
          <div className={`${styles.featureIcon} ${styles.featureIconLime}`}><ShieldCheck size={21} aria-hidden="true" /></div>
          <span className={styles.featureIndex}>02 / PLAN</span>
          <h3>Chuẩn bị trước khi thị trường mở.</h3>
          <p>Viết plan theo ngày, tuần hoặc tháng với những gì thực sự cần cho quyết định của bạn.</p>
        </article>
        <article className={styles.featureCard}>
          <div className={`${styles.featureIcon} ${styles.featureIconCoral}`}><CloudOff size={21} aria-hidden="true" /></div>
          <span className={styles.featureIndex}>03 / OFFLINE</span>
          <h3>Tiếp tục khi mạng không ổn định.</h3>
          <p>Dữ liệu có thể được lưu cục bộ để bạn tiếp tục thao tác; khi có mạng, app sẽ đồng bộ theo trạng thái.</p>
        </article>
      </section>

      <section className={styles.screenshotSection} id="screenshots">
        <div className={styles.sectionIntro}>
          <div>
            <Eyebrow>KHÁM PHÁ ỨNG DỤNG</Eyebrow>
            <h2>Một ứng dụng. Năm phần việc mỗi ngày.</h2>
          </div>
          <p>Ảnh chụp trực tiếp từ app với dữ liệu demo. Chọn một ảnh để xem rõ từng chi tiết; giao diện có thể thay đổi theo phiên bản.</p>
        </div>
        <div className={styles.screenshotRail}>
          {screenshots.map((screen) => (
            <article className={styles.screenshotCard} key={screen.src} id={screen.label === "Kiến thức" ? "knowledge" : undefined}>
              <a
                className={styles.screenshotLink}
                href={screen.src.replace(".webp", ".png")}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={`Xem ảnh ${screen.label} đầy đủ (mở tab mới)`}
              >
                <PhoneShot src={screen.src} alt={screen.alt} />
                <span className={styles.zoomHint}><Maximize2 size={13} aria-hidden="true" /> Xem ảnh</span>
              </a>
              <div className={styles.screenshotCopy}>
                <h3>{screen.label}</h3>
                <p>{screen.text}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className={styles.trustSection}>
        <div className={styles.trustPanel}>
          <div>
            <Eyebrow>RÕ RÀNG TỪ ĐẦU</Eyebrow>
            <h2>Dữ liệu, điều khoản và hỗ trợ đều có chỗ riêng.</h2>
          </div>
          <p>
            ANZEN TRADING là công cụ học tập và ghi chép. Đây không phải dịch vụ môi giới, không phải lời khuyên đầu tư
            và không cam kết kết quả giao dịch.
          </p>
          <div className={styles.trustLinks}>
            <Link href="/oauth/privacy">Đọc chính sách quyền riêng tư <ArrowRight size={15} aria-hidden="true" /></Link>
            <Link href="/oauth/terms">Đọc điều khoản sử dụng <ArrowRight size={15} aria-hidden="true" /></Link>
            <Link href="/oauth/support">Tìm câu trả lời hoặc liên hệ <ArrowRight size={15} aria-hidden="true" /></Link>
          </div>
        </div>
      </section>

      <section className={styles.legalStrip} aria-label="Thông tin pháp lý">
        <article id="privacy">
          <span className={styles.stripIndex}>PRIVACY</span>
          <h2>Quyền riêng tư</h2>
          <p>Biết dữ liệu nào được dùng để đăng nhập, đồng bộ và vận hành tính năng.</p>
          <MoreLink href="/oauth/privacy">Xem chính sách</MoreLink>
        </article>
        <article id="terms">
          <span className={styles.stripIndex}>TERMS</span>
          <h2>Điều khoản</h2>
          <p>Hiểu đúng phạm vi sử dụng app và trách nhiệm khi nhập dữ liệu giao dịch.</p>
          <MoreLink href="/oauth/terms">Xem điều khoản</MoreLink>
        </article>
        <article>
          <span className={styles.stripIndex}>SUPPORT</span>
          <h2>Hỗ trợ</h2>
          <p>Gửi câu hỏi về tài khoản, đồng bộ, ảnh hoặc dữ liệu qua email hỗ trợ.</p>
          <MoreLink href="/oauth/support">Đi tới hỗ trợ</MoreLink>
        </article>
      </section>

      <OAuthFooter />
    </main>
  );
}
