import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft, ArrowRight, Check, Mail } from "lucide-react";
import { Eyebrow, OAuthFooter, PageHeading, supportEmail } from "../components/oauth-shared";
import styles from "../oauth-page.module.css";

export const metadata: Metadata = {
  title: "Điều khoản sử dụng | ANZEN TRADING",
  description: "Điều khoản sử dụng ứng dụng ANZEN TRADING.",
};

const sections = [
  ["pham-vi", "Phạm vi dịch vụ"],
  ["tai-khoan", "Tài khoản"],
  ["noi-dung", "Nội dung và dữ liệu"],
  ["quyen-su-dung", "Quyền sử dụng app"],
  ["gioi-han", "Giới hạn trách nhiệm"],
  ["cap-nhat", "Cập nhật điều khoản"],
] as const;

export default function TermsPage() {
  return (
    <main className={styles.page}>
      <PageHeading
        active="terms"
        eyebrow="TERMS OF SERVICE"
        title="Dùng app đúng mục đích, quyết định vẫn là của bạn."
        description="Các điều khoản dưới đây đặt phạm vi sử dụng cho ANZEN TRADING — một công cụ học tập, lập kế hoạch và ghi chép cá nhân."
      />
      <div className={styles.policyLayout}>
        <aside className={styles.policyToc} aria-label="Mục lục điều khoản">
          <span>Mục lục</span>
          {sections.map(([href, label]) => <a key={href} href={`#${href}`}>{label}</a>)}
          <span className={styles.policyUpdated}>Cập nhật: 22/10/2026</span>
        </aside>
        <article className={styles.policyDocument}>
          <section id="pham-vi">
            <Eyebrow>TÓM TẮT</Eyebrow>
            <h2>ANZEN TRADING không phải công ty môi giới.</h2>
            <p>
              App cung cấp bài học, công cụ lập plan, nhật ký và các chức năng theo dõi cá nhân. Nội dung trong app chỉ nhằm
              hỗ trợ học tập và tự đánh giá; không phải tư vấn đầu tư, khuyến nghị mua bán, dịch vụ quản lý tài sản hay cam
              kết lợi nhuận.
            </p>
            <div className={styles.callout}><Check size={17} aria-hidden="true" /><span>Luôn tự kiểm tra thông tin và chịu trách nhiệm với quyết định giao dịch của bạn.</span></div>
          </section>
          <section id="tai-khoan">
            <Eyebrow>01 / TÀI KHOẢN</Eyebrow>
            <h2>Giữ tài khoản của bạn an toàn.</h2>
            <p>Bạn chịu trách nhiệm cung cấp thông tin chính xác, bảo vệ mật khẩu và không chia sẻ thông tin đăng nhập.</p>
            <ul>
              <li>Mỗi tài khoản chỉ được sử dụng cho mục đích cá nhân, hợp pháp.</li>
              <li>Không truy cập, thu thập hoặc can thiệp vào tài khoản và dữ liệu của người khác.</li>
              <li>Nếu nghi ngờ tài khoản bị truy cập trái phép, hãy liên hệ hỗ trợ sớm nhất có thể.</li>
            </ul>
          </section>
          <section id="noi-dung">
            <Eyebrow>02 / NỘI DUNG</Eyebrow>
            <h2>Bạn giữ quyền với nội dung mình tạo.</h2>
            <p>
              Bạn chịu trách nhiệm với plan, nhật ký, hình ảnh và dữ liệu bạn nhập. Bạn cần có quyền sử dụng mọi nội dung tải
              lên và không được dùng app để lưu trữ nội dung vi phạm pháp luật hoặc xâm phạm quyền của người khác.
            </p>
            <p>ANZEN TRADING có thể xử lý nội dung đó để hiển thị, sao lưu, đồng bộ và hỗ trợ tính năng mà bạn yêu cầu.</p>
            <p>
              Không đăng nội dung trái pháp luật, phát tán mã độc, khai thác lỗ hổng, gây gián đoạn hệ thống hoặc sử dụng
              công cụ tự động để thu thập nội dung và dữ liệu ngoài phạm vi được cho phép.
            </p>
          </section>
          <section id="quyen-su-dung">
            <Eyebrow>03 / QUYỀN SỬ DỤNG</Eyebrow>
            <h2>Quyền truy cập phụ thuộc vào tài khoản.</h2>
            <p>
              Bài học và tính năng có thể được phân quyền theo tài khoản. Quyền sử dụng app không đồng nghĩa với quyền
              sao chép, phân phối lại hoặc bán nội dung đào tạo, nhận diện thương hiệu và phần mềm của ANZEN TRADING.
              Nếu cần sử dụng nội dung cho mục đích khác, hãy liên hệ để được xác nhận.
            </p>
            <p>
              Chúng tôi có thể hạn chế hoặc tạm ngừng quyền truy cập khi phát hiện lạm dụng, nguy cơ bảo mật hoặc vi phạm
              điều khoản. Bạn có thể liên hệ hỗ trợ để làm rõ vấn đề, ngừng sử dụng hoặc yêu cầu xử lý dữ liệu theo
              chính sách quyền riêng tư.
            </p>
          </section>
          <section id="gioi-han">
            <Eyebrow>04 / GIỚI HẠN</Eyebrow>
            <h2>Dịch vụ có thể thay đổi hoặc gián đoạn.</h2>
            <p>
              Chúng tôi cố gắng duy trì app ổn định nhưng không đảm bảo mọi tính năng luôn không gián đoạn, không lỗi hoặc luôn
              có kết nối. Nội dung chưa đồng bộ khi offline có thể cần được gửi lại khi mạng khôi phục.
            </p>
            <p>
              Trong phạm vi pháp luật cho phép, ANZEN TRADING không chịu trách nhiệm cho quyết định giao dịch, khoản lỗ, mất
              cơ hội hoặc thiệt hại phát sinh từ việc sử dụng thông tin trong app.
            </p>
            <p>Các giới hạn này không loại bỏ quyền mà pháp luật áp dụng không cho phép hạn chế.</p>
          </section>
          <section id="cap-nhat">
            <Eyebrow>05 / CẬP NHẬT</Eyebrow>
            <h2>Thay đổi sẽ được công bố trên trang này.</h2>
            <p>
              Khi sản phẩm, tính năng hoặc yêu cầu vận hành thay đổi, chúng tôi có thể cập nhật điều khoản. Việc tiếp tục sử
              dụng app sau ngày có hiệu lực nghĩa là bạn chấp nhận phiên bản cập nhật.
            </p>
            <div className={styles.policyActions}>
              <Link href="/oauth/privacy"><ArrowLeft size={16} aria-hidden="true" /> Quyền riêng tư</Link>
              <a href={`mailto:${supportEmail}?subject=${encodeURIComponent("Hỏi về điều khoản ANZEN TRADING")}`}><Mail size={16} aria-hidden="true" /> Hỏi về điều khoản</a>
            </div>
          </section>
          <p className={styles.policyDisclaimer}>Nếu có phần nào chưa rõ, hãy gửi câu hỏi trước khi sử dụng tính năng liên quan.</p>
        </article>
      </div>
      <div className={styles.policyBottomNav}><Link href="/oauth"><ArrowLeft size={16} aria-hidden="true" /> Trang tổng quan</Link><Link href="/oauth/support">Đi tới hỗ trợ <ArrowRight size={16} aria-hidden="true" /></Link></div>
      <OAuthFooter />
    </main>
  );
}
