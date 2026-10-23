import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft, ArrowRight, Mail, MessageCircle, RefreshCw, ShieldAlert } from "lucide-react";
import { Eyebrow, ExternalMailLink, OAuthFooter, PageHeading, supportEmail } from "../components/oauth-shared";
import styles from "../oauth-page.module.css";

export const metadata: Metadata = {
  title: "Hỗ trợ | ANZEN TRADING",
  description: "Trung tâm hỗ trợ cho tài khoản và ứng dụng ANZEN TRADING.",
};

const faqs = [
  {
    question: "Tôi không đăng nhập được thì cần gửi gì?",
    answer: "Gửi email từ địa chỉ tài khoản, kèm mô tả lỗi, thời điểm xảy ra và ảnh chụp màn hình nếu có. Không gửi mật khẩu hoặc mã OTP.",
  },
  {
    question: "Vì sao dữ liệu offline chưa xuất hiện ở thiết bị khác?",
    answer: "Dữ liệu được nhập khi offline cần kết nối mạng để đồng bộ. Hãy mở app khi có mạng và kiểm tra trạng thái đồng bộ. Nếu vẫn báo lỗi, giữ lại dữ liệu trên máy và liên hệ hỗ trợ; đừng gỡ app hoặc xóa dữ liệu khi còn thay đổi chưa đồng bộ.",
  },
  {
    question: "Ảnh trong plan hoặc nhật ký không hiển thị?",
    answer: "Kiểm tra kết nối mạng và thử mở lại màn hình. Nếu vẫn lỗi, gửi tên màn hình, thời điểm tải ảnh và ảnh chụp lỗi để đội hỗ trợ kiểm tra.",
  },
  {
    question: "Tôi muốn yêu cầu xóa tài khoản hoặc dữ liệu?",
    answer: "Gửi yêu cầu từ email đã đăng ký. Chúng tôi sẽ xác minh chủ tài khoản và phản hồi hướng xử lý phù hợp.",
  },
  {
    question: "Có thể học và ghi chép khi không có internet không?",
    answer: "Bạn có thể sử dụng nội dung và dữ liệu đã có trên máy, đồng thời tiếp tục ghi chép trong các phần hỗ trợ offline. Bài học hoặc hình ảnh chưa tải, đăng nhập lần đầu và việc đồng bộ lên máy chủ vẫn cần internet.",
  },
  {
    question: "Làm sao nhận ứng dụng hoặc hỏi về quyền truy cập bài học?",
    answer: "Liên hệ email hỗ trợ để được hướng dẫn về bản cài đặt và quyền truy cập phù hợp. Nội dung khả dụng trong app phụ thuộc vào tài khoản của bạn.",
  },
];

export default function SupportPage() {
  return (
    <main className={styles.page}>
      <PageHeading
        active="support"
        eyebrow="SUPPORT CENTER"
        title="Không bị bỏ lại một mình khi app gặp vấn đề."
        description="Tìm câu trả lời nhanh cho đăng nhập, offline, đồng bộ, hình ảnh và dữ liệu tài khoản. Nếu chưa đủ, gửi email trực tiếp cho đội hỗ trợ."
      />
      <section className={styles.supportLayout}>
        <div className={styles.supportMain}>
          <div className={styles.supportContactCard}>
            <div className={styles.supportContactIcon}><Mail size={23} aria-hidden="true" /></div>
            <div>
              <Eyebrow>EMAIL SUPPORT</Eyebrow>
              <h2>Gửi câu hỏi cho chúng tôi.</h2>
              <p>Thường gửi được nhiều thông tin nhất nếu bạn mô tả bước thao tác, thiết bị và thời điểm lỗi xảy ra.</p>
              <a className={styles.supportEmail} href={`mailto:${supportEmail}`}>{supportEmail}</a>
              <ExternalMailLink subject="Hỗ trợ ANZEN TRADING">Soạn email tới đội hỗ trợ</ExternalMailLink>
              <p className={styles.emailNote}>Nút mở ứng dụng email trên thiết bị. Bạn cũng có thể gửi thủ công tới địa chỉ trên.</p>
            </div>
          </div>
          <div className={styles.supportSteps}>
            <div><span>01</span><strong>Nêu vấn đề</strong><p>Bạn đang ở màn hình nào? Thao tác nào làm lỗi xuất hiện?</p></div>
            <div><span>02</span><strong>Đính kèm bằng chứng</strong><p>Ảnh chụp màn hình hoặc thời điểm xảy ra giúp kiểm tra nhanh hơn.</p></div>
            <div><span>03</span><strong>Không gửi bí mật</strong><p>Không gửi mật khẩu, mã OTP hoặc token trong email hỗ trợ.</p></div>
          </div>
        </div>
        <aside className={styles.supportAside}>
          <div className={styles.supportAsideIcon}><MessageCircle size={18} aria-hidden="true" /></div>
          <h2>Trước khi gửi</h2>
          <p>Kiểm tra mạng và trạng thái đồng bộ. Không gỡ app hoặc xóa dữ liệu khi còn nội dung chưa đồng bộ.</p>
          <div className={styles.supportChecks}><span><RefreshCw size={15} aria-hidden="true" /> Kiểm tra kết nối</span><span><ShieldAlert size={15} aria-hidden="true" /> Không chia sẻ OTP</span></div>
        </aside>
      </section>
      <section className={styles.faqSection}>
        <div className={styles.sectionIntro}>
          <div><Eyebrow>FAQ</Eyebrow><h2>Câu hỏi thường gặp</h2></div>
          <p>Từ đăng nhập đến dữ liệu offline, những điều bạn thường cần biết khi sử dụng ANZEN TRADING.</p>
        </div>
        <div className={styles.faqList}>
          {faqs.map((faq) => <details key={faq.question}><summary>{faq.question}<ArrowRight size={17} aria-hidden="true" /></summary><p>{faq.answer}</p></details>)}
        </div>
      </section>
      <section className={styles.supportBottom}>
        <Link href="/oauth"><ArrowLeft size={16} aria-hidden="true" /> Về trang tổng quan</Link>
        <span>Hoặc đọc <Link href="/oauth/privacy">chính sách quyền riêng tư</Link> và <Link href="/oauth/terms">điều khoản sử dụng</Link>.</span>
      </section>
      <OAuthFooter />
    </main>
  );
}
