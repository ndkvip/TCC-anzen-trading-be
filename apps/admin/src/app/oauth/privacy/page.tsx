import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft, ArrowRight, Check, Mail } from "lucide-react";
import { Eyebrow, OAuthFooter, PageHeading, supportEmail } from "../components/oauth-shared";
import styles from "../oauth-page.module.css";

export const metadata: Metadata = {
  title: "Quyền riêng tư | ANZEN TRADING",
  description: "Chính sách quyền riêng tư của ứng dụng ANZEN TRADING.",
};

const sections = [
  ["tong-quan", "Tổng quan"],
  ["du-lieu", "Dữ liệu được xử lý"],
  ["su-dung", "Cách sử dụng dữ liệu"],
  ["luu-tru", "Lưu trữ và đồng bộ"],
  ["chia-se", "Truy cập và chia sẻ"],
  ["bao-mat", "Bảo mật và lưu giữ"],
  ["quyen", "Quyền của bạn"],
] as const;

export default function PrivacyPage() {
  return (
    <main className={styles.page}>
      <PageHeading
        active="privacy"
        eyebrow="PRIVACY POLICY"
        title="Quyền riêng tư, viết bằng ngôn ngữ dễ hiểu."
        description="Chính sách này giải thích ANZEN TRADING xử lý dữ liệu nào để cung cấp tài khoản, bài học, plan, nhật ký và tính năng đồng bộ."
      />
      <div className={styles.policyLayout}>
        <aside className={styles.policyToc} aria-label="Mục lục chính sách">
          <span>Mục lục</span>
          {sections.map(([href, label]) => <a key={href} href={`#${href}`}>{label}</a>)}
          <span className={styles.policyUpdated}>Cập nhật: 22/10/2026</span>
        </aside>
        <article className={styles.policyDocument}>
          <section id="tong-quan">
            <Eyebrow>TÓM TẮT</Eyebrow>
            <h2>ANZEN TRADING là ứng dụng học tập và ghi chép giao dịch.</h2>
            <p>
              Chúng tôi chỉ xử lý thông tin cần thiết để tạo tài khoản, cho phép bạn sử dụng app, lưu tiến độ học tập,
              quản lý plan, ghi nhật ký và hỗ trợ đồng bộ dữ liệu. Chúng tôi không bán dữ liệu cá nhân và không dùng dữ liệu
              Google Drive cho quảng cáo.
            </p>
            <div className={styles.callout}><Check size={17} aria-hidden="true" /><span>Bạn có thể liên hệ <a href={`mailto:${supportEmail}`}>{supportEmail}</a> nếu cần giải thích, chỉnh sửa hoặc yêu cầu xử lý dữ liệu.</span></div>
          </section>
          <section id="du-lieu">
            <Eyebrow>01 / DỮ LIỆU</Eyebrow>
            <h2>Dữ liệu nào có thể được xử lý?</h2>
            <div className={styles.policyList}>
              <div><strong>Tài khoản</strong><p>Tên, email, mật khẩu đã được băm, trạng thái xác minh, vai trò và gói tài khoản.</p></div>
              <div><strong>Dữ liệu trong app</strong><p>Tiến độ bài học, plan, nhật ký, check-in, điểm số và nội dung bạn chủ động nhập.</p></div>
              <div><strong>Thiết bị và hoạt động</strong><p>Mã thiết bị, thông tin phiên đăng nhập và dữ liệu kỹ thuật cần để duy trì tài khoản, bảo mật và đồng bộ.</p></div>
              <div><strong>Hình ảnh</strong><p>Ảnh bạn chọn tải lên trong plan hoặc nhật ký, cùng thông tin cần để hiển thị ảnh trong app.</p></div>
            </div>
          </section>
          <section id="su-dung">
            <Eyebrow>02 / MỤC ĐÍCH</Eyebrow>
            <h2>Dữ liệu được dùng để app hoạt động.</h2>
            <p>Chúng tôi dùng dữ liệu để:</p>
            <ul>
              <li>Tạo và xác thực tài khoản, gửi email hoặc mã xác minh khi cần.</li>
              <li>Hiển thị bài học, lưu tiến độ, điểm số và nội dung cá nhân của bạn.</li>
              <li>Đồng bộ dữ liệu giữa app và hệ thống khi có kết nối mạng.</li>
              <li>Phát hiện lỗi, bảo vệ tài khoản và trả lời yêu cầu hỗ trợ.</li>
            </ul>
            <p>Không dùng dữ liệu của bạn để đưa ra cam kết lợi nhuận hoặc quảng cáo được cá nhân hóa.</p>
          </section>
          <section id="luu-tru">
            <Eyebrow>03 / LƯU TRỮ</Eyebrow>
            <h2>Offline và Google Drive hoạt động như thế nào?</h2>
            <p>
              App có thể lưu một phần dữ liệu cục bộ để bạn tiếp tục xem hoặc nhập liệu khi không có internet. Dữ liệu chưa
              đồng bộ có thể không đến máy chủ cho đến khi có mạng; việc gỡ app hoặc xóa dữ liệu app có thể làm mất dữ liệu
              cục bộ chưa đồng bộ.
            </p>
            <p>
              Hình ảnh được tải lên hệ thống lưu trữ Google Drive do ANZEN TRADING vận hành. Để app và màn hình quản trị có
              thể hiển thị ảnh mà không cần đăng nhập Drive, các file ảnh được cấp quyền đọc qua liên kết. Vì vậy, không nên
              tải lên ảnh chứa thông tin nhạy cảm mà bạn không muốn có thể truy cập bằng liên kết.
            </p>
            <p>
              Kết nối Drive này sử dụng tài khoản lưu trữ do đơn vị vận hành cấu hình, không phải quyền truy cập vào toàn bộ
              Google Drive cá nhân của mỗi người dùng mobile. Hệ thống dùng kết nối đó để tạo thư mục, tải lên, đọc và xóa
              file phục vụ các tính năng của ứng dụng.
            </p>
          </section>
          <section id="chia-se">
            <Eyebrow>04 / QUYỀN TRUY CẬP</Eyebrow>
            <h2>Ai có thể xử lý dữ liệu?</h2>
            <p>
              Dữ liệu tài khoản và nội dung được xử lý bởi hệ thống ANZEN TRADING. Nhân sự quản trị được phân quyền có thể
              truy cập dữ liệu cần thiết cho vận hành, quản lý nội dung hoặc giải quyết yêu cầu hỗ trợ, bao gồm hình ảnh
              được tải lên. Không nên xem việc lưu ảnh trong app là một hình thức lưu trữ bí mật.
            </p>
            <p>
              Các nhà cung cấp hạ tầng lưu trữ, Google Drive và dịch vụ gửi email có thể xử lý dữ liệu cần thiết để cung cấp
              chức năng tương ứng. Dữ liệu cũng có thể được cung cấp khi có yêu cầu pháp lý hợp lệ hoặc để xử lý hành vi
              lạm dụng, bảo vệ tài khoản và hệ thống.
            </p>
          </section>
          <section id="bao-mat">
            <Eyebrow>05 / BẢO MẬT VÀ LƯU GIỮ</Eyebrow>
            <h2>Lưu dữ liệu cho mục đích sử dụng, không cam kết bảo mật tuyệt đối.</h2>
            <p>
              Mật khẩu được lưu dưới dạng băm; API sử dụng xác thực và phân quyền cho các tài nguyên được bảo vệ.
              Không có phương thức lưu trữ hoặc truyền tải nào bảo đảm an toàn tuyệt đối. Bạn nên giữ kín thông tin
              đăng nhập, không gửi mã OTP và hạn chế đưa thông tin nhạy cảm vào nội dung hoặc ảnh.
            </p>
            <p>
              Dữ liệu được lưu để duy trì tài khoản, cung cấp chức năng, hỗ trợ và đáp ứng yêu cầu vận hành hoặc pháp lý
              liên quan. Khi yêu cầu xóa được xác minh, chúng tôi sẽ phản hồi về phạm vi xử lý và các dữ liệu cần tiếp tục
              lưu nếu có. Chính sách này không cam kết một thời hạn xóa cố định cho mọi loại dữ liệu hoặc bản sao lưu.
            </p>
          </section>
          <section id="quyen">
            <Eyebrow>06 / QUYỀN CỦA BẠN</Eyebrow>
            <h2>Bạn có thể hỏi, sửa hoặc yêu cầu xử lý dữ liệu.</h2>
            <p>
              Bạn có thể yêu cầu xem, chỉnh sửa hoặc xóa dữ liệu tài khoản bằng cách gửi email từ địa chỉ liên quan đến tài
              khoản. Chúng tôi có thể yêu cầu xác minh danh tính trước khi xử lý để bảo vệ bạn và người dùng khác.
            </p>
            <p>
              Hãy nêu rõ bạn muốn xóa toàn bộ tài khoản hay chỉ một loại dữ liệu. Gỡ app không tự động xóa tài khoản trên
              máy chủ; ngược lại, xóa dữ liệu máy chủ không bảo đảm mọi bản sao từng lưu trên thiết bị cũng được xóa từ xa.
              Bạn có thể quản lý quyền chọn ảnh trong cài đặt hệ điều hành và ngừng tải ảnh lên bất cứ lúc nào.
            </p>
            <div className={styles.policyActions}>
              <Link href="/oauth/support"><ArrowLeft size={16} aria-hidden="true" /> Đi tới hỗ trợ</Link>
              <a href={`mailto:${supportEmail}?subject=${encodeURIComponent("Yêu cầu về dữ liệu ANZEN TRADING")}`}><Mail size={16} aria-hidden="true" /> Gửi email</a>
            </div>
          </section>
          <p className={styles.policyDisclaimer}>Chính sách có thể được cập nhật khi sản phẩm hoặc cách vận hành thay đổi. Phiên bản mới sẽ được đăng trên trang này.</p>
        </article>
      </div>
      <div className={styles.policyBottomNav}><Link href="/oauth"><ArrowLeft size={16} aria-hidden="true" /> Trang tổng quan</Link><Link href="/oauth/terms">Điều khoản sử dụng <ArrowRight size={16} aria-hidden="true" /></Link></div>
      <OAuthFooter />
    </main>
  );
}
