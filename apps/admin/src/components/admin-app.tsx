"use client";

import {
  Bell,
  BookOpen,
  CalendarClock,
  Check,
  ChevronDown,
  CircleUserRound,
  Database,
  FileText,
  GraduationCap,
  LoaderCircle,
  LayoutDashboard,
  LockKeyhole,
  LogOut,
  Menu,
  MoreHorizontal,
  Plus,
  Search,
  Settings,
  Star,
  Save,
  Trash2,
  ShieldCheck,
  Users,
  Upload,
  X,
} from "lucide-react";
import Image from "next/image";
import {
  FormEvent,
  type ReactNode,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { createPortal } from "react-dom";
import {
  api,
  ApiError,
  authStore,
  AccountTier,
  DashboardData,
  DailyCheckin,
  FeaturedTrade,
  FeaturedTradeBlock,
  Lesson,
  mediaUrl,
  MediaAsset,
  MediaContextType,
  RedNews,
  Session,
  TradeJournal,
  TradingPlan,
  User,
} from "@/lib/api";
import styles from "./admin-app.module.css";
import { LessonImageEditor, type LessonImage } from "./lesson-image-editor";
import {
  LessonQuizEditor,
  quizDraftsFromApi,
  type QuizQuestionDraft,
} from "./lesson-quiz-editor";

type Section =
  | "dashboard"
  | "users"
  | "courses"
  | "journal"
  | "media"
  | "featured-trades"
  | "red-news"
  | "settings";

const navigation: {
  id: Section;
  label: string;
  icon: typeof LayoutDashboard;
}[] = [
  { id: "dashboard", label: "Tổng quan", icon: LayoutDashboard },
  { id: "users", label: "Học viên", icon: Users },
  { id: "courses", label: "Khóa học", icon: GraduationCap },
  { id: "journal", label: "Nhật ký giao dịch", icon: BookOpen },
  { id: "media", label: "Thư viện media", icon: Database },
  { id: "featured-trades", label: "Giao dịch nổi bật", icon: Star },
  { id: "red-news", label: "Tin quan trọng trong tuần", icon: CalendarClock },
  { id: "settings", label: "Cài đặt", icon: Settings },
];

export default function AdminApp() {
  const [session, setSession] = useState<Session | null>(null);
  const [initializing, setInitializing] = useState(true);
  const [section, setSection] = useState<Section>("dashboard");
  const [mobileNav, setMobileNav] = useState(false);
  const [studentCount, setStudentCount] = useState<number | null>(null);
  const [lessonCount, setLessonCount] = useState<number | null>(null);

  useEffect(() => {
    if (!session) return;
    let cancelled = false;
    Promise.all([
      api.users(session.accessToken),
      api.lessons(session.accessToken),
    ])
      .then(([users, lessons]) => {
        if (!cancelled) setLessonCount(lessons.length);
        if (!cancelled)
          setStudentCount(
            users.filter((user) => user.role === "STUDENT").length,
          );
      })
      .catch(() => {
        if (!cancelled) {
          setStudentCount(null);
          setLessonCount(null);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [session]);

  useEffect(() => authStore.subscribe(setSession), []);

  useEffect(() => {
    api
      .restoreSession()
      .then((restored) => {
        if (restored?.user.role === "ADMIN") setSession(restored);
        else if (restored) authStore.clear();
      })
      .finally(() => setInitializing(false));
  }, []);

  if (initializing) return <AdminSplash />;
  if (!session) return <LoginPanel onLogin={setSession} />;

  const active =
    navigation.find((item) => item.id === section) ?? navigation[0];

  return (
    <div className={styles.adminShell}>
      <aside
        className={`${styles.sidebar} ${mobileNav ? styles.sidebarOpen : ""}`}
      >
        <div className={styles.brand}>
          <Image
            src="/branding/anzen-trading-mark.png"
            alt="ANZEN TRADING"
            width={128}
            height={128}
            priority
          />
          <div>
            <strong>ANZEN TRADING</strong>
            <small>Control room</small>
          </div>
          <button
            className={styles.mobileClose}
            onClick={() => setMobileNav(false)}
            aria-label="Đóng menu"
          >
            <X />
          </button>
        </div>
        <nav>
          <p className={styles.navLabel}>Quản lý</p>
          {navigation.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.id}
                className={section === item.id ? styles.navActive : ""}
                onClick={() => {
                  setSection(item.id);
                  setMobileNav(false);
                }}
              >
                <Icon size={19} />
                <span>{item.label}</span>
                {item.id === "users" && (
                  <em>{studentCount === null ? "…" : studentCount}</em>
                )}
              </button>
            );
          })}
        </nav>
        <div className={styles.sidebarFoot}>
          <div className={styles.securityBadge}>
            <ShieldCheck />
            <div>
              <strong>Auth đang hoạt động</strong>
              <small>1 thiết bị / tài khoản</small>
            </div>
          </div>
          <button
            className={styles.profileButton}
            onClick={async () => {
              await api.logout(session.accessToken);
              setSession(null);
            }}
          >
            <span className={styles.avatar}>
              {session.user.name.slice(0, 1).toUpperCase()}
            </span>
            <span>
              <strong>{session.user.name}</strong>
              <small>{session.user.email}</small>
            </span>
            <LogOut size={17} />
          </button>
        </div>
      </aside>

      {mobileNav && (
        <button
          className={styles.backdrop}
          onClick={() => setMobileNav(false)}
          aria-label="Đóng menu"
        />
      )}

      <main className={styles.workspace}>
        <header className={styles.topbar}>
          <button
            className={styles.menuButton}
            onClick={() => setMobileNav(true)}
            aria-label="Mở menu"
          >
            <Menu />
          </button>
          <div>
            <small>ANZEN TRADING ADMIN</small>
            <h1>{active.label}</h1>
          </div>
          <div className={styles.topActions}>
            <label className={styles.globalSearch}>
              <Search size={17} />
              <input placeholder="Tìm nhanh..." />
            </label>
            <button className={styles.iconButton} aria-label="Thông báo">
              <Bell size={19} />
              <span />
            </button>
            <span className={styles.online}>
              <i />
              Đang hoạt động
            </span>
          </div>
        </header>
        <div className={styles.pageBody}>
          {section === "dashboard" && (
            <Dashboard
              session={session}
              studentCount={studentCount}
              lessonCount={lessonCount}
              onOpenUsers={() => setSection("users")}
              onOpenCourses={() => setSection("courses")}
            />
          )}
          {section === "users" && (
            <UsersPanel
              session={session}
              onStudentCountChange={setStudentCount}
            />
          )}
          {section === "courses" && (
            <CoursesPanel session={session} onCountChange={setLessonCount} />
          )}
          {section === "journal" && <StudentDataPanel session={session} />}
          {section === "media" && <MediaLibraryPanel session={session} />}
          {section === "featured-trades" && (
            <FeaturedTradesPanel session={session} />
          )}
          {section === "red-news" && <RedNewsPanel session={session} />}
          {section === "settings" && <SettingsPanel session={session} />}
        </div>
      </main>
    </div>
  );
}

function AdminSplash() {
  return (
    <div className={styles.splash}>
      <Image
        src="/branding/anzen-trading-mark.png"
        alt="ANZEN TRADING"
        width={128}
        height={128}
        priority
      />
      <div />
    </div>
  );
}

function LoginPanel({ onLogin }: { onLogin: (session: Session) => void }) {
  const [email, setEmail] = useState("admin@ttc-ict.vn");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");
  const [forgot, setForgot] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setMessage("");
    try {
      if (forgot) {
        const response = await api.forgotPassword(email);
        setMessage(response.message);
      } else {
        const result = await api.login(email, password);
        if (result.user.role !== "ADMIN")
          throw new ApiError("Tài khoản này không có quyền quản trị", 403);
        authStore.save(result);
        onLogin(result);
      }
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Đăng nhập thất bại");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className={styles.loginPage}>
      <section className={styles.loginStory}>
        <div className={styles.storyBrand}>
          <Image
            src="/branding/anzen-trading-logo.png"
            alt="ANZEN TRADING"
            width={424}
            height={112}
            priority
          />
        </div>
        <div className={styles.storyCopy}>
          <p>CONTROL ROOM · 2026</p>
          <h1>Một nơi để vận hành toàn bộ hành trình học.</h1>
          <div className={styles.storyStats}>
            <div>
              <strong>05</strong>
              <span>khu vực sản phẩm chính</span>
            </div>
            <div>
              <strong>01</strong>
              <span>nguồn dữ liệu duy nhất</span>
            </div>
            <div>
              <strong>24/7</strong>
              <span>theo dõi hệ thống</span>
            </div>
          </div>
        </div>
        <div className={styles.orbit}>
          <span />
          <span />
          <span />
        </div>
      </section>
      <section className={styles.loginFormWrap}>
        <form className={styles.loginForm} onSubmit={submit}>
          <div className={styles.loginMark}>
            {forgot ? <LockKeyhole /> : <ShieldCheck />}
          </div>
          <p className={styles.eyebrow}>
            {forgot ? "KHÔI PHỤC TÀI KHOẢN" : "ĐĂNG NHẬP QUẢN TRỊ"}
          </p>
          <h2>{forgot ? "Quên mật khẩu?" : "Chào mừng trở lại."}</h2>
          <p className={styles.formIntro}>
            {forgot
              ? "Nhập email quản trị, hệ thống sẽ gửi liên kết đặt lại mật khẩu."
              : "Sử dụng tài khoản quản trị được cấu hình trên hệ thống."}
          </p>
          <label>
            Email
            <input
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
          </label>
          {!forgot && (
            <label>
              Mật khẩu
              <input
                type="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                minLength={8}
                required
              />
            </label>
          )}
          {message && <div className={styles.formMessage}>{message}</div>}
          <button className={styles.primaryButton} disabled={loading}>
            {loading ? "Đang xử lý..." : forgot ? "Gửi hướng dẫn" : "Đăng nhập"}
          </button>
          <button
            type="button"
            className={styles.textButton}
            onClick={() => {
              setForgot(!forgot);
              setMessage("");
            }}
          >
            {forgot ? "Quay lại đăng nhập" : "Quên mật khẩu?"}
          </button>
          <small className={styles.loginNote}>
            <LockKeyhole size={14} />
            Phiên cũ tự động hết hiệu lực khi đăng nhập ở thiết bị khác.
          </small>
        </form>
      </section>
    </main>
  );
}

function Dashboard({
  session,
  studentCount,
  lessonCount,
  onOpenUsers,
  onOpenCourses,
}: {
  session: Session;
  studentCount: number | null;
  lessonCount: number | null;
  onOpenUsers: () => void;
  onOpenCourses: () => void;
}) {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");

  useEffect(() => {
    let cancelled = false;
    api
      .dashboard(session.accessToken)
      .then((result) => {
        if (!cancelled) setData(result);
      })
      .catch((error) => {
        if (!cancelled)
          setMessage(
            error instanceof Error
              ? error.message
              : "Không tải được số liệu tổng quan",
          );
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [session.accessToken]);

  const count = (value: number | undefined, fallback: number | null) =>
    loading ? "…" : (value ?? fallback ?? "—");
  const activity = data?.activity ?? [];
  const maxActivity = Math.max(
    ...activity.map((item) => item.activeStudents),
    1,
  );
  const dateLabel = (value: string) =>
    new Intl.DateTimeFormat("vi-VN", { weekday: "short" })
      .format(new Date(`${value}T12:00:00`))
      .replace(".", "");
  return (
    <div className={styles.dashboardGrid}>
      <section className={styles.heroCard}>
        <div>
          <p className={styles.eyebrow}>TỔNG QUAN HÔM NAY</p>
          <h2>
            Nội dung rõ ràng.
            <br />
            Học viên đi đúng lộ trình.
          </h2>
          <p>
            Theo dõi những phần quan trọng nhất của học viện từ một bảng điều
            khiển duy nhất.
          </p>
          <button onClick={onOpenUsers}>
            Quản lý học viên <span>→</span>
          </button>
        </div>
        <div className={styles.heroVisual}>
          <Image
            src="/branding/anzen-trading-mark.png"
            alt="ANZEN TRADING"
            width={128}
            height={128}
            priority
          />
          <i />
          <i />
          <i />
        </div>
      </section>
      <section className={styles.metricCard}>
        <span className={styles.metricIcon}>
          <Users />
        </span>
        <p>Tổng số học viên</p>
        <strong>{count(data?.studentCount, studentCount)}</strong>
        <small>Dữ liệu cập nhật từ hệ thống</small>
      </section>
      <section className={styles.metricCard}>
        <span className={`${styles.metricIcon} ${styles.blue}`}>
          <GraduationCap />
        </span>
        <p>Tỷ lệ hoàn thành</p>
        <strong>{loading ? "…" : `${data?.completionRate ?? 0}%`}</strong>
        <small>Đã hoàn thành / lượt học viên bắt đầu bài học đã publish</small>
      </section>
      <section className={styles.metricCard}>
        <span className={`${styles.metricIcon} ${styles.coral}`}>
          <FileText />
        </span>
        <p>Bài học đang quản lý</p>
        <strong>{count(data?.lessonCount, lessonCount)}</strong>
        <small>
          {data?.draftLessons ?? 0} bản nháp · {data?.incompleteLessons ?? 0}{" "}
          chưa đủ nội dung
        </small>
      </section>
      {message && (
        <div className={styles.dashboardMessage}>
          {message}
          <button onClick={() => setMessage("")}>
            <X size={15} />
          </button>
        </div>
      )}
      <section className={styles.activityCard}>
        <div className={styles.cardHeading}>
          <div>
            <p className={styles.eyebrow}>7 NGÀY GẦN ĐÂY</p>
            <h3>Hoạt động đã đồng bộ</h3>
          </div>
          <span className={styles.cardNote}>
            {data?.timezone ?? "Asia/Ho_Chi_Minh"}
          </span>
        </div>
        <div className={styles.chart}>
          {activity.map((item) => (
            <div
              key={item.date}
              title={`${item.date}: ${item.activeStudents} học viên`}
            >
              <span
                className={
                  item.activeStudents === 0 ? styles.chartZero : undefined
                }
                style={{
                  height: `${item.activeStudents ? Math.max((item.activeStudents / maxActivity) * 100, 8) : 0}%`,
                }}
              />
              <strong>{item.activeStudents}</strong>
              <small>{dateLabel(item.date)}</small>
            </div>
          ))}
          {!activity.length && (
            <div className={styles.chartEmpty}>
              {loading
                ? "Đang tải..."
                : "Chưa có hoạt động trong 7 ngày gần đây."}
            </div>
          )}
        </div>
      </section>
      <section className={styles.quickCard}>
        <div className={styles.cardHeading}>
          <div>
            <p className={styles.eyebrow}>CẦN CHÚ Ý</p>
            <h3>Công việc nhanh</h3>
          </div>
          <MoreHorizontal />
        </div>
        <button onClick={onOpenCourses}>
          <span className={styles.limeDot}>
            <Plus />
          </span>
          <div>
            <strong>Hoàn thiện bài học</strong>
            <small>
              {loading
                ? "Đang kiểm tra..."
                : `${data?.incompleteLessons ?? 0} bản nháp chưa đủ nội dung`}
            </small>
          </div>
          <b>→</b>
        </button>
        <button onClick={onOpenCourses}>
          <span className={styles.coralDot}>
            <BookOpen />
          </span>
          <div>
            <strong>Kiểm tra bản nháp</strong>
            <small>
              {loading
                ? "Đang kiểm tra..."
                : `${data?.draftLessons ?? 0} bài học chưa publish`}
            </small>
          </div>
          <b>→</b>
        </button>
        <button onClick={onOpenUsers}>
          <span className={styles.blueDot}>
            <Users />
          </span>
          <div>
            <strong>Duyệt học viên mới</strong>
            <small>
              {loading
                ? "Đang kiểm tra..."
                : `${data?.unverifiedStudents ?? 0} tài khoản chưa xác minh email`}
            </small>
          </div>
          <b>→</b>
        </button>
      </section>
    </div>
  );
}

const mediaContextLabels: Record<MediaContextType, string> = {
  LEARNING_LESSON: "Bài học",
  LEARNING_QUESTION: "Câu hỏi",
  LEARNING_ANSWER: "Câu trả lời",
  JOURNAL: "Nhật ký",
  PLAN: "Kế hoạch",
  FEATURED_TRADE: "Giao dịch nổi bật",
  GENERAL: "Khác",
};

function formatBytes(value: string | number) {
  const bytes = Number(value);
  if (!Number.isFinite(bytes) || bytes <= 0) return "—";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
}

function MediaLibraryPanel({ session }: { session: Session }) {
  const pageSize = 24;
  const [items, setItems] = useState<MediaAsset[]>([]);
  const [owners, setOwners] = useState<User[]>([]);
  const [query, setQuery] = useState("");
  const [search, setSearch] = useState("");
  const [ownerId, setOwnerId] = useState("");
  const [contextType, setContextType] = useState<MediaContextType | "">("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [selected, setSelected] = useState<MediaAsset | null>(null);

  useEffect(() => {
    api
      .users(session.accessToken)
      .then(setOwners)
      .catch(() => undefined);
  }, [session.accessToken]);

  useEffect(() => {
    let cancelled = false;
    api
      .mediaLibrary(session.accessToken, {
        page,
        pageSize,
        search,
        ownerId: ownerId || undefined,
        contextType: contextType || undefined,
      })
      .then((result) => {
        if (cancelled) return;
        setItems(result.data);
        setTotal(result.total);
      })
      .catch((error) => {
        if (!cancelled)
          setMessage(
            error instanceof Error
              ? error.message
              : "Không tải được thư viện media",
          );
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [contextType, ownerId, page, search, session.accessToken]);

  const pageCount = Math.max(1, Math.ceil(total / pageSize));
  const submitSearch = (event: FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setMessage("");
    setPage(1);
    setSearch(query.trim());
  };
  const changeFilter = (setter: (value: string) => void, value: string) => {
    setLoading(true);
    setMessage("");
    setter(value);
    setPage(1);
  };

  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <div>
          <p className={styles.eyebrow}>TÀI SẢN ĐÃ ĐỒNG BỘ</p>
          <h2>Thư viện media</h2>
          <p>
            Tra cứu các hình ảnh đã được máy chủ ghi nhận và lưu trong Google
            Drive.
          </p>
        </div>
        <span className={styles.mediaTotal}>{total} tài sản</span>
      </div>
      <form className={styles.mediaToolbar} onSubmit={submitSearch}>
        <label className={styles.mediaSearch}>
          <Search size={17} />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Tìm tên, Drive ID, thư mục, học viên..."
          />
        </label>
        <select
          value={ownerId}
          onChange={(event) => changeFilter(setOwnerId, event.target.value)}
          aria-label="Lọc theo học viên"
        >
          <option value="">Tất cả học viên</option>
          {owners
            .filter((user) => user.role === "STUDENT")
            .map((owner) => (
              <option value={owner.id} key={owner.id}>
                {owner.name} · {owner.email}
              </option>
            ))}
        </select>
        <select
          value={contextType}
          onChange={(event) => {
            setLoading(true);
            setMessage("");
            setContextType(event.target.value as MediaContextType | "");
            setPage(1);
          }}
          aria-label="Lọc theo module"
        >
          <option value="">Tất cả module</option>
          {Object.entries(mediaContextLabels).map(([value, label]) => (
            <option value={value} key={value}>
              {label}
            </option>
          ))}
        </select>
        <button className={styles.mediaActionButton} type="submit">
          <Search size={15} />
          Tìm kiếm
        </button>
      </form>
      {message && (
        <div className={styles.panelMessage}>
          {message}
          <button onClick={() => setMessage("")}>
            <X size={15} />
          </button>
        </div>
      )}
      {loading ? (
        <div className={styles.emptyCell}>Đang tải thư viện media...</div>
      ) : items.length === 0 ? (
        <div className={styles.emptyCell}>
          Không có tài sản phù hợp. Các tệp đang chờ đồng bộ trên thiết bị sẽ
          chưa xuất hiện ở đây.
        </div>
      ) : (
        <div className={styles.mediaGrid}>
          {items.map((item) => (
            <article className={styles.mediaCard} key={item.id}>
              <div className={styles.mediaCardPreview}>
                {item.previewPath ? (
                  <span>
                    <Database size={27} />
                    <small>Preview tải khi mở</small>
                  </span>
                ) : (
                  <span>
                    <X size={23} />
                    <small>Không có preview được xác thực</small>
                  </span>
                )}
              </div>
              <div className={styles.mediaCardBody}>
                <div className={styles.mediaCardTitle}>
                  <strong title={item.name}>{item.name}</strong>
                  <span
                    className={`${styles.mediaStatus} ${item.storageStatus === "DRIVE" ? styles.mediaStatusDrive : styles.mediaStatusExternal}`}
                  >
                    {item.storageStatus === "DRIVE" ? "Drive" : "External"}
                  </span>
                </div>
                <dl>
                  <div>
                    <dt>Module</dt>
                    <dd>{mediaContextLabels[item.contextType]}</dd>
                  </div>
                  <div>
                    <dt>Chủ sở hữu</dt>
                    <dd title={item.owner.email ?? undefined}>
                      {item.owner.name || item.owner.email || "Không rõ"}
                    </dd>
                  </div>
                  <div>
                    <dt>Định dạng / dung lượng</dt>
                    <dd>
                      {item.mimeType} · {formatBytes(item.sizeBytes)}
                    </dd>
                  </div>
                  <div>
                    <dt>Drive ID</dt>
                    <dd title={item.driveFileId ?? undefined}>
                      {item.driveFileId || "—"}
                    </dd>
                  </div>
                </dl>
                <footer>
                  <small>
                    {new Intl.DateTimeFormat("vi-VN", {
                      dateStyle: "medium",
                    }).format(new Date(item.createdAt))}
                  </small>
                  <button
                    className={styles.mediaActionButton}
                    type="button"
                    disabled={!item.previewPath}
                    onClick={() => setSelected(item)}
                  >
                    Xem preview
                  </button>
                </footer>
              </div>
            </article>
          ))}
        </div>
      )}
      {pageCount > 1 && (
        <div className={styles.pagination}>
          <span>
            Trang {page} / {pageCount}
          </span>
          <div>
            <button
              type="button"
              className={styles.rowAction}
              disabled={page <= 1}
              onClick={() => setPage((current) => current - 1)}
            >
              ←
            </button>
            <button
              type="button"
              className={styles.rowAction}
              disabled={page >= pageCount}
              onClick={() => setPage((current) => current + 1)}
            >
              →
            </button>
          </div>
        </div>
      )}
      {selected && (
        <MediaPreviewModal
          asset={selected}
          token={session.accessToken}
          onClose={() => setSelected(null)}
        />
      )}
    </section>
  );
}

function MediaPreviewModal({
  asset,
  token,
  onClose,
}: {
  asset: MediaAsset;
  token: string;
  onClose: () => void;
}) {
  const [source, setSource] = useState("");
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    let cancelled = false;
    let objectUrl = "";
    if (asset.previewPath) {
      api
        .mediaImage(token, asset.previewPath)
        .then((blob) => {
          objectUrl = URL.createObjectURL(blob);
          if (!cancelled) setSource(objectUrl);
          else URL.revokeObjectURL(objectUrl);
        })
        .catch(() => {
          if (!cancelled) setFailed(true);
        });
    }
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [asset.id, asset.previewPath, token]);

  return (
    <ModalBackdrop onClose={onClose}>
      <section
        className={`${styles.modal} ${styles.mediaPreviewModal}`}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <button
          type="button"
          className={styles.modalClose}
          onClick={onClose}
          aria-label="Đóng"
        >
          <X />
        </button>
        <p className={styles.eyebrow}>PREVIEW ĐÃ XÁC THỰC</p>
        <h2>{asset.name}</h2>
        <p className={styles.mediaPreviewMeta}>
          {asset.owner.name || asset.owner.email || "Không rõ chủ sở hữu"} ·{" "}
          {mediaContextLabels[asset.contextType]} · {asset.mimeType}
        </p>
        <div className={styles.mediaPreviewFrame}>
          {source && !failed ? (
            <Image
              src={source}
              alt={asset.name}
              width={1400}
              height={1000}
              unoptimized
              onError={() => {
                setFailed(true);
                setSource("");
              }}
            />
          ) : (
            <span>
              {failed
                ? "Không tải được ảnh từ Google Drive."
                : "Đang tải preview..."}
            </span>
          )}
        </div>
        <small className={styles.mediaPreviewNote}>
          Preview đi qua proxy có xác thực của API; thư viện không tải toàn bộ
          ảnh khi chưa được mở.
        </small>
      </section>
    </ModalBackdrop>
  );
}

function UsersPanel({
  session,
  onStudentCountChange,
}: {
  session: Session;
  onStudentCountChange: (count: number) => void;
}) {
  const [users, setUsers] = useState<User[]>([]);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [createOpen, setCreateOpen] = useState(false);

  useEffect(() => {
    let cancelled = false;
    api
      .users(session.accessToken)
      .then((data) => {
        if (!cancelled) {
          setUsers(data);
          onStudentCountChange(
            data.filter((user) => user.role === "STUDENT").length,
          );
        }
      })
      .catch((error: unknown) => {
        if (!cancelled)
          setMessage(
            error instanceof Error ? error.message : "Không tải được học viên",
          );
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [onStudentCountChange, session.accessToken]);

  const visible = useMemo(
    () =>
      users.filter((user) =>
        `${user.name} ${user.email}`
          .toLowerCase()
          .includes(query.toLowerCase()),
      ),
    [query, users],
  );
  const students = visible.filter((user) => user.role === "STUDENT");

  async function patch(
    user: User,
    payload: { accountTier?: AccountTier; isActive?: boolean },
  ) {
    try {
      const updated = await api.updateUser(
        session.accessToken,
        user.id,
        payload,
      );
      setUsers((current) => {
        const next = current.map((item) =>
          item.id === updated.id ? updated : item,
        );
        onStudentCountChange(
          next.filter((item) => item.role === "STUDENT").length,
        );
        return next;
      });
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Cập nhật thất bại");
    }
  }

  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <div>
          <p className={styles.eyebrow}>PHÂN QUYỀN & TRUY CẬP</p>
          <h2>Danh sách học viên</h2>
          <p>Quản lý trạng thái tài khoản và quyền học cơ bản / nâng cao.</p>
        </div>
        <button
          className={styles.primaryButton}
          onClick={() => setCreateOpen(true)}
        >
          <Plus size={18} />
          Thêm học viên
        </button>
      </div>
      <div className={styles.toolbar}>
        <label>
          <Search size={17} />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Tìm theo tên hoặc email..."
          />
        </label>
        <div className={styles.userSummary}>
          <span>
            <i className={styles.activeDot} />
            {
              users.filter((user) => user.isActive && user.role === "STUDENT")
                .length
            }{" "}
            hoạt động
          </span>
          <span>
            <i className={styles.advancedDot} />
            {
              users.filter(
                (user) =>
                  user.accountTier !== "STANDARD" && user.role === "STUDENT",
              ).length
            }{" "}
            nâng cao
          </span>
        </div>
      </div>
      {message && (
        <div className={styles.panelMessage}>
          {message}
          <button onClick={() => setMessage("")}>
            <X size={15} />
          </button>
        </div>
      )}
      <div className={styles.tableWrap}>
        <table>
          <thead>
            <tr>
              <th>Học viên</th>
              <th>Gói tài khoản</th>
              <th>Trạng thái</th>
              <th>Ngày tạo</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={5} className={styles.emptyCell}>
                  Đang tải dữ liệu...
                </td>
              </tr>
            ) : students.length === 0 ? (
              <tr>
                <td colSpan={5} className={styles.emptyCell}>
                  Chưa có học viên phù hợp.
                </td>
              </tr>
            ) : (
              students.map((user) => (
                <tr key={user.id}>
                  <td>
                    <div className={styles.userCell}>
                      <span>{user.name.slice(0, 1).toUpperCase()}</span>
                      <div>
                        <strong>{user.name}</strong>
                        <small>{user.email}</small>
                      </div>
                    </div>
                  </td>
                  <td>
                    <select
                      value={user.accountTier}
                      onChange={(event) =>
                        void patch(user, {
                          accountTier: event.target.value as AccountTier,
                        })
                      }
                    >
                      <option value="STANDARD">Thường</option>
                      <option value="VIP1">VIP 1</option>
                      <option value="VIP2">VIP 2</option>
                    </select>
                  </td>
                  <td>
                    <button
                      className={`${styles.statusPill} ${user.isActive ? styles.statusActive : styles.statusLocked}`}
                      onClick={() =>
                        void patch(user, { isActive: !user.isActive })
                      }
                    >
                      <i />
                      {user.isActive ? "Hoạt động" : "Đã khóa"}
                    </button>
                  </td>
                  <td>
                    {new Intl.DateTimeFormat("vi-VN").format(
                      new Date(user.createdAt),
                    )}
                  </td>
                  <td>
                    <button className={styles.rowAction}>
                      <MoreHorizontal size={18} />
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
      {createOpen && (
        <CreateUserModal
          session={session}
          onClose={() => setCreateOpen(false)}
          onCreated={(user) => {
            setUsers((current) => {
              const next = [user, ...current];
              onStudentCountChange(
                next.filter((item) => item.role === "STUDENT").length,
              );
              return next;
            });
            setCreateOpen(false);
          }}
        />
      )}
    </section>
  );
}

function ModalBackdrop({
  children,
  onClose,
}: {
  children: ReactNode;
  onClose: () => void;
}) {
  useEffect(() => {
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = overflow;
    };
  }, []);

  // Animated panels establish a containing block for fixed descendants.
  if (typeof document === "undefined") return null;
  return createPortal(
    <div
      className={styles.modalBackdrop}
      role="dialog"
      aria-modal="true"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      {children}
    </div>,
    document.body,
  );
}

function CreateUserModal({
  session,
  onClose,
  onCreated,
}: {
  session: Session;
  onClose: () => void;
  onCreated: (user: User) => void;
}) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [accountTier, setAccountTier] = useState<AccountTier>("STANDARD");
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setMessage("");
    try {
      onCreated(
        await api.createUser(session.accessToken, {
          name,
          email,
          password,
          accountTier,
        }),
      );
    } catch (error) {
      setMessage(
        error instanceof Error ? error.message : "Không tạo được học viên",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <ModalBackdrop onClose={onClose}>
      <form
        className={styles.modal}
        onSubmit={submit}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <button type="button" className={styles.modalClose} onClick={onClose}>
          <X />
        </button>
        <div className={styles.modalIcon}>
          <CircleUserRound />
        </div>
        <p className={styles.eyebrow}>TÀI KHOẢN MỚI</p>
        <h2>Thêm học viên</h2>
        <p>Tạo thông tin đăng nhập và phân quyền khóa học ngay từ đầu.</p>
        <label>
          Họ và tên
          <input
            value={name}
            onChange={(event) => setName(event.target.value)}
            minLength={2}
            required
          />
        </label>
        <label>
          Email
          <input
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />
        </label>
        <label>
          Mật khẩu tạm
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            minLength={8}
            required
          />
        </label>
        <fieldset className={styles.accountTierOptions}>
          <legend>Gói tài khoản</legend>
          <button
            type="button"
            className={accountTier === "STANDARD" ? styles.tierSelected : ""}
            onClick={() => setAccountTier("STANDARD")}
          >
            <Check />
            Thường<small>3 bài cơ bản + 1 bài nâng cao</small>
          </button>
          <button
            type="button"
            className={accountTier === "VIP1" ? styles.tierSelected : ""}
            onClick={() => setAccountTier("VIP1")}
          >
            <Check />
            VIP 1<small>Full cơ bản + 3 bài nâng cao</small>
          </button>
          <button
            type="button"
            className={accountTier === "VIP2" ? styles.tierSelected : ""}
            onClick={() => setAccountTier("VIP2")}
          >
            <Check />
            VIP 2<small>Truy cập toàn bộ</small>
          </button>
        </fieldset>
        {message && <div className={styles.formMessage}>{message}</div>}
        <button className={styles.primaryButton} disabled={loading}>
          {loading ? "Đang tạo..." : "Tạo tài khoản"}
        </button>
      </form>
    </ModalBackdrop>
  );
}

function CoursesPanel({
  session,
  onCountChange,
}: {
  session: Session;
  onCountChange: (count: number) => void;
}) {
  const emptyLesson = (): Partial<Lesson> => ({
    title: "",
    slug: "",
    description: "",
    tier: "BASIC",
    position: 0,
    durationMinutes: 10,
    isPublished: false,
    knowledgeCards: [],
    questions: [],
  });
  const [items, setItems] = useState<Lesson[]>([]);
  const [editing, setEditing] = useState<Partial<Lesson> | null>(null);
  const [images, setImages] = useState<LessonImage[]>([]);
  const [saving, setSaving] = useState(false);
  const [saveStatus, setSaveStatus] = useState("");
  const [uploadProgress, setUploadProgress] = useState({ done: 0, total: 0 });
  const [quizQuestions, setQuizQuestions] = useState<QuizQuestionDraft[]>([]);
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    api
      .lessons(session.accessToken)
      .then((values) => {
        if (!cancelled) {
          setItems(values);
          onCountChange(values.length);
        }
      })
      .catch((error) => {
        if (!cancelled)
          setMessage(
            error instanceof Error ? error.message : "Không tải được bài học",
          );
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [onCountChange, session.accessToken]);
  function open(item?: Lesson) {
    const value = item ?? emptyLesson();
    setEditing(value);
    setImages(
      (value.knowledgeCards ?? []).flatMap((card) =>
        typeof card.imageUrl === "string"
          ? [{ key: crypto.randomUUID(), imageUrl: card.imageUrl }]
          : [],
      ),
    );
    setQuizQuestions(quizDraftsFromApi(value.questions ?? []));
    setMessage("");
    setSaveStatus("");
    setUploadProgress({ done: 0, total: 0 });
  }
  async function save(event: FormEvent) {
    event.preventDefault();
    if (!editing || saving) return;
    setSaving(true);
    setMessage("");
    setSaveStatus("Đang chuẩn bị dữ liệu...");
    setUploadProgress({ done: 0, total: 0 });
    try {
      if (editing.isPublished && !images.length)
        throw new Error("Thêm ít nhất một ảnh trước khi xuất bản.");
      if (editing.isPublished && !quizQuestions.length)
        throw new Error("Thêm ít nhất một câu hỏi trước khi xuất bản.");
      quizQuestions.forEach((question, questionIndex) => {
        if (!question.question.trim() && !question.image)
          throw new Error(`Câu ${questionIndex + 1} cần có chữ hoặc hình ảnh.`);
        question.options.forEach((option, optionIndex) => {
          if (!option.text.trim() && !option.image)
            throw new Error(
              `Đáp án ${optionIndex + 1} của câu ${questionIndex + 1} cần có chữ hoặc hình ảnh.`,
            );
        });
      });
      const metadata = {
        title: editing.title,
        slug: editing.slug,
        description: editing.description,
        tier: editing.tier,
        position: editing.position,
        durationMinutes: editing.durationMinutes,
      };
      let id = editing.id;
      if (!id) {
        setSaveStatus("Đang tạo bản nháp bài học...");
        const draft = await api.createLesson(session.accessToken, {
          ...metadata,
          isPublished: false,
        });
        id = draft.id;
        setEditing({ ...editing, id });
        setItems((current) => [...current, draft]);
        onCountChange(items.length + 1);
      }
      const uploadedImages = [...images];
      const totalUploads =
        uploadedImages.filter((image) => image.file).length +
        quizQuestions.filter((question) => question.image?.file).length +
        quizQuestions.reduce(
          (total, question) =>
            total +
            question.options.filter((option) => option.image?.file).length,
          0,
        );
      let completedUploads = 0;
      setUploadProgress({ done: 0, total: totalUploads });
      // Keep successful uploads in the editor so a retry does not upload them again.
      for (let index = 0; index < uploadedImages.length; index++) {
        const image = uploadedImages[index];
        if (!image.file) continue;
        setSaveStatus(
          `Đang tải ảnh kiến thức ${completedUploads + 1}/${totalUploads}...`,
        );
        const uploaded = await api.uploadLessonImage(
          session.accessToken,
          id,
          image.file,
        );
        uploadedImages[index] = { key: image.key, imageUrl: uploaded.imageUrl };
        setImages([...uploadedImages]);
        completedUploads += 1;
        setUploadProgress({ done: completedUploads, total: totalUploads });
      }
      const uploadedQuestions = quizQuestions.map((question) => ({
        ...question,
        options: question.options.map((option) => ({
          ...option,
        })) as QuizQuestionDraft["options"],
      }));
      for (
        let questionIndex = 0;
        questionIndex < uploadedQuestions.length;
        questionIndex++
      ) {
        const question = uploadedQuestions[questionIndex];
        if (question.image?.file) {
          setSaveStatus(
            `Đang tải ảnh câu hỏi ${completedUploads + 1}/${totalUploads}...`,
          );
          const uploaded = await api.uploadLessonExerciseImage(
            session.accessToken,
            id,
            question.image.file,
            "LEARNING_QUESTION",
          );
          question.image = {
            key: question.image.key,
            imageUrl: uploaded.imageUrl,
          };
          setQuizQuestions([...uploadedQuestions]);
          completedUploads += 1;
          setUploadProgress({ done: completedUploads, total: totalUploads });
        }
        for (
          let optionIndex = 0;
          optionIndex < question.options.length;
          optionIndex++
        ) {
          const option = question.options[optionIndex];
          if (!option.image?.file) continue;
          setSaveStatus(
            `Đang tải ảnh đáp án ${completedUploads + 1}/${totalUploads}...`,
          );
          const uploaded = await api.uploadLessonExerciseImage(
            session.accessToken,
            id,
            option.image.file,
            "LEARNING_ANSWER",
          );
          option.image = { key: option.image.key, imageUrl: uploaded.imageUrl };
          setQuizQuestions([...uploadedQuestions]);
          completedUploads += 1;
          setUploadProgress({ done: completedUploads, total: totalUploads });
        }
      }
      const questions = uploadedQuestions.map((question) => ({
        question: question.question.trim(),
        ...(question.image?.imageUrl
          ? { imageUrl: question.image.imageUrl }
          : {}),
        options: question.options.map((option) => ({
          ...(option.text.trim() ? { text: option.text.trim() } : {}),
          ...(option.image?.imageUrl
            ? { imageUrl: option.image.imageUrl }
            : {}),
        })),
        correctIndex: question.correctIndex,
        explanation: question.explanation.trim(),
      }));
      setSaveStatus("Đang lưu nội dung bài học...");
      const saved = await api.updateLesson(session.accessToken, id, {
        ...metadata,
        isPublished: editing.isPublished,
        knowledgeCards: uploadedImages.map((image) => ({
          imageUrl: image.imageUrl,
        })),
        questions,
      });
      setItems((current) =>
        current.some((item) => item.id === saved.id)
          ? current.map((item) => (item.id === saved.id ? saved : item))
          : [...current, saved],
      );
      setEditing(null);
    } catch (error) {
      setMessage(
        error instanceof Error ? error.message : "Không lưu được bài học",
      );
      setSaveStatus("");
    } finally {
      setSaving(false);
    }
  }
  async function remove(item: Lesson) {
    if (!window.confirm(`Xóa bài học “${item.title}”?`)) return;
    try {
      await api.deleteLesson(session.accessToken, item.id);
      setItems((values) => values.filter((value) => value.id !== item.id));
      onCountChange(items.length - 1);
    } catch (error) {
      setMessage(
        error instanceof Error ? error.message : "Không xóa được bài học",
      );
    }
  }
  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <div>
          <p className={styles.eyebrow}>KIẾN THỨC & BÀI TẬP</p>
          <h2>Thư viện bài học</h2>
          <p>
            Quản lý thẻ kiến thức, câu hỏi trắc nghiệm và quyền Cơ bản / Nâng
            cao.
          </p>
        </div>
        <button className={styles.primaryButton} onClick={() => open()}>
          <Plus size={18} />
          Thêm bài học
        </button>
      </div>
      {message && (
        <div className={styles.panelMessage}>
          {message}
          <button onClick={() => setMessage("")}>
            <X size={15} />
          </button>
        </div>
      )}
      <div className={styles.contentGrid}>
        {loading ? (
          <div className={styles.emptyCell}>Đang tải bài học...</div>
        ) : (
          items.map((item) => (
            <article className={styles.lessonAdminCard} key={item.id}>
              <div>
                <span
                  className={`${styles.tierTag} ${item.tier === "ADVANCED" ? styles.tierAdvanced : ""}`}
                >
                  {item.tier === "ADVANCED" ? "Nâng cao" : "Cơ bản"}
                </span>
                <span
                  className={item.isPublished ? styles.published : styles.draft}
                >
                  {item.isPublished ? "Đã xuất bản" : "Bản nháp"}
                </span>
              </div>
              <h3>{item.title}</h3>
              <p>{item.description || "Chưa có mô tả"}</p>
              <small>
                {item.knowledgeCards.length} thẻ kiến thức ·{" "}
                {item.questions.length} câu hỏi · {item.durationMinutes} phút
              </small>
              <footer>
                <button onClick={() => open(item)}>
                  <FileText size={15} />
                  Sửa nội dung
                </button>
                <button onClick={() => void remove(item)}>
                  <Trash2 size={15} />
                </button>
              </footer>
            </article>
          ))
        )}
      </div>
      {editing && (
        <ModalBackdrop
          onClose={() => {
            if (!saving) setEditing(null);
          }}
        >
          <form
            className={`${styles.modal} ${styles.lessonModal}`}
            onSubmit={save}
            onMouseDown={(event) => event.stopPropagation()}
          >
            <button
              type="button"
              disabled={saving}
              className={styles.modalClose}
              onClick={() => setEditing(null)}
            >
              <X />
            </button>
            <p className={styles.eyebrow}>BIÊN TẬP BÀI HỌC</p>
            <h2>{editing.id ? "Sửa bài học" : "Thêm bài học"}</h2>
            <fieldset className={styles.lessonFields} disabled={saving}>
              <div className={styles.lessonFormGrid}>
                <label>
                  Tên bài
                  <input
                    value={editing.title ?? ""}
                    onChange={(e) =>
                      setEditing({ ...editing, title: e.target.value })
                    }
                    required
                  />
                </label>
                <label>
                  Mã bài
                  <input
                    value={editing.slug ?? ""}
                    onChange={(e) =>
                      setEditing({ ...editing, slug: e.target.value })
                    }
                    required
                  />
                </label>
                <label>
                  Nhóm
                  <select
                    value={editing.tier}
                    onChange={(e) =>
                      setEditing({
                        ...editing,
                        tier: e.target.value as "BASIC" | "ADVANCED",
                      })
                    }
                  >
                    <option value="BASIC">Cơ bản</option>
                    <option value="ADVANCED">Nâng cao</option>
                  </select>
                </label>
                <label>
                  Thứ tự
                  <input
                    type="number"
                    value={editing.position ?? 0}
                    onChange={(e) =>
                      setEditing({
                        ...editing,
                        position: Number(e.target.value),
                      })
                    }
                  />
                </label>
                <label>
                  Thời lượng
                  <input
                    type="number"
                    min="1"
                    value={editing.durationMinutes ?? 10}
                    onChange={(e) =>
                      setEditing({
                        ...editing,
                        durationMinutes: Number(e.target.value),
                      })
                    }
                  />
                </label>
                <label className={styles.checkLabel}>
                  <input
                    type="checkbox"
                    checked={editing.isPublished ?? false}
                    onChange={(e) =>
                      setEditing({ ...editing, isPublished: e.target.checked })
                    }
                  />
                  Xuất bản trên ứng dụng
                </label>
              </div>
              <label>
                Mô tả
                <textarea
                  rows={3}
                  value={editing.description ?? ""}
                  onChange={(e) =>
                    setEditing({ ...editing, description: e.target.value })
                  }
                />
              </label>
              {(editing.knowledgeCards ?? []).some(
                (card) => !card.imageUrl,
              ) && (
                <p className={styles.formMessage}>
                  Bài cũ có nội dung chữ. Khi lưu, phần kiến thức sẽ được thay
                  bằng các ảnh bạn chọn dưới đây; bài tập vẫn giữ nguyên.
                </p>
              )}
              <LessonImageEditor
                images={images}
                onChange={setImages}
                token={session.accessToken}
                lessonId={editing.id}
              />
              <LessonQuizEditor
                questions={quizQuestions}
                onChange={setQuizQuestions}
                token={session.accessToken}
                lessonId={editing.id}
              />
              {saving && (
                <div
                  className={styles.saveProgress}
                  role="status"
                  aria-live="polite"
                >
                  <div className={styles.saveProgressHeader}>
                    <LoaderCircle className={styles.spin} size={16} />
                    <strong>{saveStatus || "Đang xử lý..."}</strong>
                    {uploadProgress.total > 0 && (
                      <span>
                        {uploadProgress.done}/{uploadProgress.total}
                      </span>
                    )}
                  </div>
                  {uploadProgress.total > 0 && (
                    <div className={styles.saveProgressTrack}>
                      <span
                        style={{
                          width: `${Math.round((uploadProgress.done / uploadProgress.total) * 100)}%`,
                        }}
                      />
                    </div>
                  )}
                  <small>Vui lòng giữ cửa sổ này mở đến khi hoàn tất.</small>
                </div>
              )}
              {message && (
                <p role="alert" className={styles.formMessage}>
                  {message}
                </p>
              )}
              <button className={styles.primaryButton} disabled={saving}>
                {saving ? (
                  <LoaderCircle className={styles.spin} size={16} />
                ) : (
                  <Save size={16} />
                )}{" "}
                {saving
                  ? saveStatus || "Đang tải ảnh và lưu..."
                  : "Lưu bài học"}
              </button>
            </fieldset>
          </form>
        </ModalBackdrop>
      )}
    </section>
  );
}

type StudentDataTab = "journal" | "plans" | "checkins";
function StudentDataPanel({ session }: { session: Session }) {
  const [users, setUsers] = useState<User[]>([]);
  const [userId, setUserId] = useState("");
  const [tab, setTab] = useState<StudentDataTab>("journal");
  const [journals, setJournals] = useState<TradeJournal[]>([]);
  const [plans, setPlans] = useState<TradingPlan[]>([]);
  const [checkins, setCheckins] = useState<DailyCheckin[]>([]);
  const [selectedJournal, setSelectedJournal] = useState<TradeJournal | null>(
    null,
  );
  const [message, setMessage] = useState("");
  useEffect(() => {
    api
      .users(session.accessToken)
      .then((values) => {
        const students = values.filter((v) => v.role === "STUDENT");
        setUsers(students);
        setUserId((id) => id || students[0]?.id || "");
      })
      .catch((error) =>
        setMessage(
          error instanceof Error ? error.message : "Không tải được học viên",
        ),
      );
  }, [session.accessToken]);
  useEffect(() => {
    if (!userId) return;
    let cancelled = false;
    Promise.all([
      api.studentJournals(session.accessToken, userId),
      api.studentPlans(session.accessToken, userId),
      api.studentCheckins(session.accessToken, userId),
    ])
      .then(([j, p, c]) => {
        if (!cancelled) {
          setMessage("");
          setSelectedJournal(null);
          setJournals(j);
          setPlans(p);
          setCheckins(c);
        }
      })
      .catch((error) => {
        if (!cancelled)
          setMessage(
            error instanceof Error
              ? error.message
              : "Không tải được dữ liệu học viên",
          );
      });
    return () => {
      cancelled = true;
    };
  }, [session.accessToken, userId]);
  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <div>
          <p className={styles.eyebrow}>DỮ LIỆU HỌC VIÊN</p>
          <h2>Nhật ký, kế hoạch & điểm danh</h2>
          <p>Xem dữ liệu đã đồng bộ theo từng tài khoản.</p>
        </div>
        <label className={styles.studentPicker}>
          Học viên
          <select value={userId} onChange={(e) => setUserId(e.target.value)}>
            {users.map((user) => (
              <option value={user.id} key={user.id}>
                {user.name} · {user.email}
              </option>
            ))}
          </select>
        </label>
      </div>
      {message && <div className={styles.panelMessage}>{message}</div>}
      <div className={styles.dataTabs}>
        {(
          [
            ["journal", "Nhật ký giao dịch"],
            ["plans", "Kế hoạch giao dịch"],
            ["checkins", "Điểm danh"],
          ] as [StudentDataTab, string][]
        ).map(([value, label]) => (
          <button
            className={tab === value ? styles.dataTabActive : ""}
            onClick={() => setTab(value)}
            key={value}
          >
            {label}
          </button>
        ))}
      </div>
      <div className={styles.dataList}>
        {tab === "journal" &&
          (journals.length ? (
            journals.map((item) => (
              <button
                type="button"
                className={styles.dataListRowButton}
                key={item.id}
                onClick={() => setSelectedJournal(item)}
              >
                <span
                  className={
                    item.pnl === null
                      ? styles.running
                      : item.pnl >= 0
                        ? styles.positive
                        : styles.negative
                  }
                >
                  {item.pnl === null
                    ? "RUNNING"
                    : `${item.pnl >= 0 ? "+" : ""}${item.pnl}`}
                </span>
                <div>
                  <strong>
                    {item.symbol} ·{" "}
                    {item.direction === "LONG" ? "Long" : "Short"}
                  </strong>
                  <small>
                    {item.mode === "SWING" ? "Swing" : item.tradeDate} ·{" "}
                    {item.timeframePair || "Chưa chọn khung"} ·{" "}
                    {item.management} · RR {item.riskReward ?? "—"}
                  </small>
                </div>
                <ChevronDown className={styles.rowChevron} size={16} />
              </button>
            ))
          ) : (
            <div className={styles.emptyCell}>Học viên chưa có nhật ký.</div>
          ))}
        {tab === "plans" &&
          (plans.length ? (
            plans.map((item) => (
              <article key={item.id}>
                <span className={styles.planBadge}>
                  {item.scope === "DAY"
                    ? "Ngày"
                    : item.scope === "WEEK"
                      ? "Tuần"
                      : "Tháng"}
                </span>
                <div>
                  <strong>{item.title}</strong>
                  <small>
                    {item.periodKey} ·{" "}
                    {item.timeframePairs.join(", ") || "Không giới hạn khung"}
                  </small>
                </div>
                <span
                  className={
                    item.status === "COMPLETED"
                      ? styles.positive
                      : styles.medium
                  }
                >
                  {item.status === "COMPLETED" ? "Hoàn tất" : "Bản nháp"}
                </span>
              </article>
            ))
          ) : (
            <div className={styles.emptyCell}>Học viên chưa có kế hoạch.</div>
          ))}
        {tab === "checkins" &&
          (checkins.length ? (
            checkins.map((item) => (
              <article key={item.id}>
                <span
                  className={
                    item.totalScore < 4
                      ? styles.negative
                      : item.totalScore < 7
                        ? styles.medium
                        : styles.positive
                  }
                >
                  {item.totalScore.toFixed(1)}/10
                </span>
                <div>
                  <strong>
                    {new Intl.DateTimeFormat("vi-VN").format(
                      new Date(`${item.checkinDate}T12:00:00`),
                    )}
                  </strong>
                  <small>5 tiêu chí · {item.scores.join(" · ")}</small>
                </div>
              </article>
            ))
          ) : (
            <div className={styles.emptyCell}>Học viên chưa điểm danh.</div>
          ))}
      </div>
      {selectedJournal && (
        <JournalDetailModal
          journal={selectedJournal}
          token={session.accessToken}
          onClose={() => setSelectedJournal(null)}
        />
      )}
    </section>
  );
}

function JournalMediaPreview({
  url,
  token,
  alt,
}: {
  url: string;
  token: string;
  alt: string;
}) {
  const [preview, setPreview] = useState<{
    url: string;
    source: string;
    failed: boolean;
  } | null>(null);
  let driveId = "";
  try {
    const parsed = new URL(url);
    if (parsed.hostname === "drive.google.com")
      driveId =
        parsed.searchParams.get("id") ??
        parsed.pathname.match(/\/file\/d\/([^/]+)/)?.[1] ??
        "";
  } catch {
    /* Relative images use the API base. */
  }
  useEffect(() => {
    if (!driveId) return;
    let cancelled = false;
    let objectUrl = "";
    api
      .journalImage(token, driveId)
      .then((blob) => {
        objectUrl = URL.createObjectURL(blob);
        if (!cancelled) setPreview({ url, source: objectUrl, failed: false });
        else URL.revokeObjectURL(objectUrl);
      })
      .catch(() => {
        if (!cancelled) setPreview({ url, source: "", failed: true });
      });
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [driveId, token, url]);
  const source = driveId
    ? preview?.url === url
      ? preview.source
      : ""
    : mediaUrl(url);
  const failed = preview?.url === url && preview.failed;
  return source && !failed ? (
    <Image
      src={source}
      alt={alt}
      width={1000}
      height={650}
      unoptimized
      onError={() => setPreview({ url, source: "", failed: true })}
    />
  ) : (
    <span className={styles.journalImagePlaceholder}>
      {failed ? "Không tải được ảnh" : "Đang tải ảnh..."}
    </span>
  );
}

function JournalDetailModal({
  journal,
  token,
  onClose,
}: {
  journal: TradeJournal;
  token: string;
  onClose: () => void;
}) {
  const noteImages = (journal.notesDelta ?? []).flatMap((operation) => {
    const insert = operation.insert;
    return insert &&
      typeof insert === "object" &&
      "image" in insert &&
      typeof insert.image === "string"
      ? [insert.image]
      : [];
  });
  const images = [...new Set(journal.processImageUrls ?? [])].filter(
    (url) => !noteImages.includes(url),
  );
  return (
    <ModalBackdrop onClose={onClose}>
      <section
        className={`${styles.modal} ${styles.journalDetailModal}`}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <button
          type="button"
          className={styles.modalClose}
          onClick={onClose}
          aria-label="Đóng"
        >
          <X />
        </button>
        <p className={styles.eyebrow}>CHI TIẾT NHẬT KÝ</p>
        <h2>
          {journal.symbol} · {journal.direction === "LONG" ? "Long" : "Short"}
        </h2>
        <p className={styles.journalDetailStatus}>
          <span
            className={
              journal.pnl === null
                ? styles.running
                : journal.pnl >= 0
                  ? styles.positive
                  : styles.negative
            }
          >
            {journal.pnl === null
              ? "ĐANG CHẠY"
              : `PNL ${journal.pnl >= 0 ? "+" : ""}${journal.pnl}`}
          </span>
          <b>RR {journal.riskReward ?? "—"}</b>
          <span>
            {journal.mode === "SWING"
              ? "Swing"
              : journal.tradeDate || "Chưa có ngày"}
          </span>
        </p>
        <div className={styles.journalDetailGrid}>
          <div>
            <small>Mã tài sản</small>
            <strong>{journal.symbol}</strong>
          </div>
          <div>
            <small>Quản lý lệnh</small>
            <strong>{journal.management}</strong>
          </div>
          <div>
            <small>Khung thời gian</small>
            <strong>{journal.timeframePair || "—"}</strong>
          </div>
          <div>
            <small>Thiết lập</small>
            <strong>{journal.priceMovement || "—"}</strong>
          </div>
        </div>
        {journal.idea && (
          <div className={styles.journalDetailSection}>
            <h3>Ý tưởng</h3>
            <p>{journal.idea}</p>
          </div>
        )}
        {journal.execution && (
          <div className={styles.journalDetailSection}>
            <h3>Thực thi</h3>
            <p>{journal.execution}</p>
          </div>
        )}
        {journal.result && (
          <div className={styles.journalDetailSection}>
            <h3>Kết quả</h3>
            <p>{journal.result}</p>
          </div>
        )}
        {!!journal.notesDelta?.length && (
          <div className={styles.journalDetailSection}>
            <h3>Ghi chú</h3>
            <div className={styles.journalNoteText}>
              {journal.notesDelta.map((operation, index) => {
                if (typeof operation.insert === "string") {
                  const attributes = operation.attributes as
                    Record<string, unknown> | undefined;
                  return (
                    <span
                      key={index}
                      style={{
                        fontWeight: attributes?.bold ? 700 : undefined,
                        fontStyle: attributes?.italic ? "italic" : undefined,
                        textDecoration: attributes?.underline
                          ? "underline"
                          : attributes?.strike
                            ? "line-through"
                            : undefined,
                      }}
                    >
                      {operation.insert}
                    </span>
                  );
                }
                const insert = operation.insert;
                return insert &&
                  typeof insert === "object" &&
                  "image" in insert &&
                  typeof insert.image === "string" ? (
                  <div className={styles.journalInlineImage} key={index}>
                    <JournalMediaPreview
                      url={insert.image}
                      token={token}
                      alt={`Ảnh trong ghi chú ${index + 1}`}
                    />
                  </div>
                ) : null;
              })}
            </div>
          </div>
        )}
        {images.length > 0 && (
          <div className={styles.journalDetailSection}>
            <h3>Ảnh quá trình ({images.length})</h3>
            <div className={styles.journalDetailImages}>
              {images.map((url, index) => (
                <JournalMediaPreview
                  key={url}
                  url={url}
                  token={token}
                  alt={`Ảnh giao dịch ${index + 1}`}
                />
              ))}
            </div>
          </div>
        )}
      </section>
    </ModalBackdrop>
  );
}

type FeaturedTradeEditorBlock = FeaturedTradeBlock & {
  file?: File;
  previewUrl?: string;
};
type FeaturedTradeDraft = Omit<FeaturedTrade, "contentBlocks"> & {
  contentBlocks: FeaturedTradeEditorBlock[];
  coverImageFile?: File;
  coverImagePreviewUrl?: string;
};

function FeaturedTradesPanel({ session }: { session: Session }) {
  const [items, setItems] = useState<FeaturedTrade[]>([]);
  const [editing, setEditing] = useState<FeaturedTradeDraft | null>(null);
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const previews = useRef(new Set<string>());

  useEffect(() => {
    const urls = previews.current;
    return () => {
      urls.forEach((url) => URL.revokeObjectURL(url));
    };
  }, []);

  function releasePreviews() {
    previews.current.forEach((url) => URL.revokeObjectURL(url));
    previews.current.clear();
  }

  function articleBlocks(item: FeaturedTrade): FeaturedTradeBlock[] {
    return item.contentBlocks?.length
      ? item.contentBlocks
      : (item.imageUrls ?? []).map((imageUrl) => ({ type: "image", imageUrl }));
  }

  function featuredImageUrl(url: string) {
    try {
      const parsed = new URL(url);
      if (parsed.hostname === "drive.google.com") {
        const id =
          parsed.searchParams.get("id") ??
          parsed.pathname.match(/\/file\/d\/([^/]+)/)?.[1];
        if (id)
          return mediaUrl(
            `/featured-trades/drive-images/${encodeURIComponent(id)}`,
          );
      }
    } catch {
      /* Relative legacy image URLs use the API base. */
    }
    return mediaUrl(url);
  }

  function mondayKey(date = new Date()) {
    const monday = new Date(date);
    monday.setHours(12, 0, 0, 0);
    monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
    return monday.toISOString().slice(0, 10);
  }

  useEffect(() => {
    api
      .featuredTrades(session.accessToken)
      .then(setItems)
      .catch((error) =>
        setMessage(
          error instanceof Error
            ? error.message
            : "Không tải được giao dịch nổi bật",
        ),
      )
      .finally(() => setLoading(false));
  }, [session.accessToken]);

  function openEditor(item: FeaturedTrade) {
    releasePreviews();
    setEditing({
      ...item,
      contentBlocks: articleBlocks(item).map((block) => ({ ...block })),
    });
    setMessage("");
  }

  function emptyItem(): FeaturedTradeDraft {
    return {
      id: "",
      weekStart: mondayKey(),
      title: "",
      summary: null,
      coverImageUrl: null,
      contentBlocks: [],
      imageUrls: [],
      isActive: true,
    };
  }

  function closeEditor() {
    if (!saving) {
      releasePreviews();
      setEditing(null);
    }
  }

  function setField<K extends keyof FeaturedTradeDraft>(
    key: K,
    value: FeaturedTradeDraft[K],
  ) {
    setEditing((current) => (current ? { ...current, [key]: value } : current));
  }

  function addTextBlock() {
    setEditing((current) =>
      current
        ? {
            ...current,
            contentBlocks: [
              ...current.contentBlocks,
              { type: "text", text: "" },
            ],
          }
        : current,
    );
  }

  function addImages(files: FileList | null) {
    if (!files || !editing) return;
    const selected = Array.from(files);
    const invalid = selected.find((file) => !file.type.startsWith("image/"));
    if (invalid) {
      setMessage("Chỉ được chọn tệp hình ảnh.");
      return;
    }
    const tooLarge = selected.find((file) => file.size > 10 * 1024 * 1024);
    if (tooLarge) {
      setMessage("Mỗi hình ảnh không được vượt quá 10 MB.");
      return;
    }
    setMessage("");
    const blocks = selected.map((file) => {
      const previewUrl = URL.createObjectURL(file);
      previews.current.add(previewUrl);
      return { type: "image" as const, file, previewUrl };
    });
    setEditing({
      ...editing,
      contentBlocks: [...editing.contentBlocks, ...blocks],
    });
  }

  function addCoverImage(file: File | null) {
    if (!file || !editing) return;
    if (!file.type.startsWith("image/")) {
      setMessage("Chỉ được chọn tệp hình ảnh cho thumbnail.");
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      setMessage("Ảnh thumbnail không được vượt quá 10 MB.");
      return;
    }
    if (editing.coverImagePreviewUrl) {
      URL.revokeObjectURL(editing.coverImagePreviewUrl);
      previews.current.delete(editing.coverImagePreviewUrl);
    }
    const previewUrl = URL.createObjectURL(file);
    previews.current.add(previewUrl);
    setMessage("");
    setEditing({
      ...editing,
      coverImageFile: file,
      coverImagePreviewUrl: previewUrl,
    });
  }

  function patchBlock(index: number, patch: Partial<FeaturedTradeEditorBlock>) {
    setEditing((current) =>
      current
        ? {
            ...current,
            contentBlocks: current.contentBlocks.map((block, blockIndex) =>
              blockIndex === index ? { ...block, ...patch } : block,
            ),
          }
        : current,
    );
  }

  function removeBlock(index: number) {
    const url = editing?.contentBlocks[index]?.previewUrl;
    if (url) {
      URL.revokeObjectURL(url);
      previews.current.delete(url);
    }
    setEditing((current) =>
      current
        ? {
            ...current,
            contentBlocks: current.contentBlocks.filter(
              (_, blockIndex) => blockIndex !== index,
            ),
          }
        : current,
    );
  }

  function moveBlock(index: number, direction: -1 | 1) {
    setEditing((current) => {
      if (!current) return current;
      const nextIndex = index + direction;
      if (nextIndex < 0 || nextIndex >= current.contentBlocks.length)
        return current;
      const blocks = [...current.contentBlocks];
      [blocks[index], blocks[nextIndex]] = [blocks[nextIndex], blocks[index]];
      return { ...current, contentBlocks: blocks };
    });
  }

  async function save(event: FormEvent) {
    event.preventDefault();
    if (!editing) return;
    setMessage("");
    if (!editing.title.trim()) {
      setMessage("Vui lòng nhập tiêu đề bài.");
      return;
    }
    if (!editing.contentBlocks.length) {
      setMessage("Thêm ít nhất một khối chữ hoặc hình ảnh.");
      return;
    }
    if (!editing.coverImageFile && !editing.coverImageUrl?.trim()) {
      setMessage("Thêm ảnh thumbnail để hiển thị bài viết bên ngoài Home.");
      return;
    }
    if (
      editing.contentBlocks.some(
        (block) => block.type === "text" && !block.text?.trim(),
      )
    ) {
      setMessage("Khối chữ không được để trống.");
      return;
    }
    setSaving(true);
    try {
      let coverImageUrl = editing.coverImageUrl?.trim() ?? "";
      if (editing.coverImageFile) {
        setMessage("Đang tải ảnh thumbnail Home...");
        const uploaded = await api.uploadFeaturedTradeImages(
          session.accessToken,
          [editing.coverImageFile],
          editing.weekStart,
        );
        coverImageUrl = uploaded.imageUrls[0] ?? "";
        if (!coverImageUrl)
          throw new Error("Máy chủ chưa trả về ảnh thumbnail đã tải lên.");
        setEditing((current) =>
          current
            ? {
                ...current,
                coverImageUrl,
                coverImageFile: undefined,
              }
            : current,
        );
      }
      const uploadedBlocks: FeaturedTradeBlock[] = [];
      const uploadCount = editing.contentBlocks.filter(
        (block) => block.file,
      ).length;
      let uploadIndex = 0;
      for (let index = 0; index < editing.contentBlocks.length; index += 1) {
        const block = editing.contentBlocks[index];
        if (block.type === "text") {
          uploadedBlocks.push({ type: "text", text: block.text?.trim() ?? "" });
          continue;
        }
        if (block.file) {
          setMessage(`Đang tải hình ảnh ${++uploadIndex}/${uploadCount}...`);
          const uploaded = await api.uploadFeaturedTradeImages(
            session.accessToken,
            [block.file],
            editing.weekStart,
          );
          const imageUrl = uploaded.imageUrls[0];
          if (!imageUrl)
            throw new Error("Máy chủ chưa trả về hình ảnh đã tải lên.");
          uploadedBlocks.push({ type: "image", imageUrl });
          // Retain successful uploads so retrying a failed save does not upload twice.
          patchBlock(index, { imageUrl, file: undefined });
        } else if (block.imageUrl) {
          uploadedBlocks.push({ type: "image", imageUrl: block.imageUrl });
        }
      }
      const payload = {
        weekStart: editing.weekStart,
        title: editing.title.trim(),
        summary: editing.summary?.trim() || "",
        coverImageUrl,
        contentBlocks: uploadedBlocks,
        isActive: editing.isActive,
      };
      setMessage("Đang lưu bài viết...");
      const saved = editing.id
        ? await api.updateFeaturedTrade(
            session.accessToken,
            editing.id,
            payload,
          )
        : await api.createFeaturedTrade(session.accessToken, payload);
      setItems((current) =>
        editing.id
          ? current.map((item) => (item.id === saved.id ? saved : item))
          : [saved, ...current],
      );
      releasePreviews();
      setEditing(null);
      setMessage("Đã lưu bài viết.");
    } catch (error) {
      const detail =
        error instanceof Error
          ? error.message
          : "Không lưu được giao dịch nổi bật";
      setMessage(
        /invalid_grant|Token has been expired or revoked/i.test(detail)
          ? "Không tải được ảnh vì kết nối Google Drive đã hết hạn hoặc bị thu hồi. Cần kết nối lại Google Drive trên máy chủ. Nội dung đang sửa vẫn được giữ trong cửa sổ này."
          : detail,
      );
    } finally {
      setSaving(false);
    }
  }

  async function toggle(item: FeaturedTrade) {
    try {
      const saved = await api.updateFeaturedTrade(
        session.accessToken,
        item.id,
        { isActive: !item.isActive },
      );
      setItems((current) =>
        current.map((entry) => (entry.id === saved.id ? saved : entry)),
      );
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Không cập nhật được trạng thái",
      );
    }
  }

  async function remove(item: FeaturedTrade) {
    if (!window.confirm(`Xóa bài “${item.title || item.weekStart}”?`)) return;
    try {
      await api.deleteFeaturedTrade(session.accessToken, item.id);
      setItems((current) => current.filter((entry) => entry.id !== item.id));
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Không xóa được giao dịch nổi bật",
      );
    }
  }

  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <div>
          <p className={styles.eyebrow}>NỘI DUNG TRÊN ỨNG DỤNG</p>
          <h2>Giao dịch nổi bật trong tuần</h2>
          <p>
            Mỗi giao dịch là một bài viết riêng. Admin sắp xếp chữ và hình ảnh
            xen kẽ như một bài báo.
          </p>
        </div>
        <button
          className={styles.primaryButton}
          onClick={() => {
            setEditing(emptyItem());
            setMessage("");
          }}
        >
          <Plus size={17} />
          Thêm bài viết
        </button>
      </div>
      {message && !editing && (
        <div className={styles.panelMessage}>{message}</div>
      )}
      {loading ? (
        <div className={styles.emptyCell}>Đang tải nội dung...</div>
      ) : (
        <div className={styles.featuredTradeList}>
          {items.length ? (
            items.map((item) => (
              <article className={styles.featuredTradeAdminCard} key={item.id}>
                <div className={styles.featuredTradeAdminTop}>
                  <span>Tuần bắt đầu {item.weekStart}</span>
                  <button
                    className={`${styles.newsStatus} ${item.isActive ? styles.newsStatusActive : styles.newsStatusOff}`}
                    onClick={() => void toggle(item)}
                  >
                    {item.isActive ? "Đang hiển thị" : "Đang ẩn"}
                  </button>
                </div>
                <h3>{item.title || "Giao dịch nổi bật"}</h3>
                {item.summary && <p>{item.summary}</p>}
                {item.coverImageUrl && (
                  <Image
                    className={styles.featuredTradeCoverCardImage}
                    src={featuredImageUrl(item.coverImageUrl)}
                    alt="Thumbnail trên Home"
                    width={800}
                    height={420}
                    unoptimized
                  />
                )}
                <div className={styles.featuredTradeArticlePreview}>
                  {articleBlocks(item).map((block, index) =>
                    block.type === "text" ? (
                      <p key={index}>{block.text}</p>
                    ) : (
                      <Image
                        key={index}
                        src={featuredImageUrl(block.imageUrl ?? "")}
                        alt={`Ảnh nội dung ${index + 1}`}
                        width={800}
                        height={500}
                        unoptimized
                      />
                    ),
                  )}
                </div>
                <small>
                  {articleBlocks(item).length} khối nội dung ·{" "}
                  {
                    articleBlocks(item).filter(
                      (block) => block.type === "image",
                    ).length
                  }{" "}
                  hình ảnh
                </small>
                <footer>
                  <button onClick={() => openEditor(item)}>
                    <FileText size={15} />
                    Sửa bài viết
                  </button>
                  <button onClick={() => void remove(item)}>
                    <Trash2 size={15} />
                  </button>
                </footer>
              </article>
            ))
          ) : (
            <div className={styles.emptyCell}>
              Chưa có bài viết nào được admin đẩy lên.
            </div>
          )}
        </div>
      )}
      {editing && (
        <ModalBackdrop onClose={closeEditor}>
          <form
            className={`${styles.modal} ${styles.featuredTradeEditor}`}
            onSubmit={save}
            onMouseDown={(event) => event.stopPropagation()}
          >
            <button
              type="button"
              disabled={saving}
              className={styles.modalClose}
              onClick={closeEditor}
            >
              <X />
            </button>
            <p className={styles.eyebrow}>BIÊN TẬP BÀI VIẾT</p>
            <h2>
              {editing.id ? "Sửa giao dịch nổi bật" : "Thêm giao dịch nổi bật"}
            </h2>
            <label>
              Tiêu đề bài viết
              <input
                value={editing.title}
                onChange={(event) => setField("title", event.target.value)}
                required
                disabled={saving}
              />
            </label>
            <label>
              Tuần bắt đầu
              <input
                type="date"
                value={editing.weekStart}
                onChange={(event) => setField("weekStart", event.target.value)}
                required
                disabled={saving}
              />
            </label>
            <label>
              Tóm tắt
              <textarea
                rows={2}
                value={editing.summary ?? ""}
                onChange={(event) => setField("summary", event.target.value)}
                disabled={saving}
              />
            </label>
            <div className={styles.featuredTradeCoverPicker}>
              <div className={styles.featuredTradeCoverHeader}>
                <div>
                  <strong>Ảnh thumbnail trên Home</strong>
                  <span>
                    Ảnh này hiển thị ở thẻ bên ngoài; ảnh trong bài viết được
                    quản lý riêng bên dưới.
                  </span>
                </div>
                <label className={styles.secondaryButton}>
                  <Upload size={15} />
                  {editing.coverImageFile || editing.coverImageUrl
                    ? "Đổi thumbnail"
                    : "Chọn thumbnail"}
                  <input
                    type="file"
                    aria-label="Chọn ảnh thumbnail trên Home"
                    accept="image/jpeg,image/png,image/webp"
                    onChange={(event) => {
                      addCoverImage(event.target.files?.[0] ?? null);
                      event.currentTarget.value = "";
                    }}
                    disabled={saving}
                  />
                </label>
              </div>
              {editing.coverImagePreviewUrl || editing.coverImageUrl ? (
                <Image
                  className={styles.featuredTradeCoverPreview}
                  src={
                    editing.coverImagePreviewUrl ??
                    featuredImageUrl(editing.coverImageUrl ?? "")
                  }
                  alt="Ảnh thumbnail trên Home"
                  width={800}
                  height={420}
                  unoptimized
                />
              ) : (
                <div className={styles.featuredTradeCoverEmpty}>
                  Chưa có thumbnail. Hãy chọn một ảnh để hiển thị bài viết
                  trên Home.
                </div>
              )}
            </div>
            <div className={styles.featuredTradeBlockToolbar}>
              <strong>Nội dung bài viết</strong>
              <span>Thêm theo đúng thứ tự muốn hiển thị</span>
              <div>
                <button
                  type="button"
                  className={styles.secondaryButton}
                  onClick={addTextBlock}
                  disabled={saving}
                >
                  <FileText size={15} />
                  Thêm chữ
                </button>
                <label className={styles.secondaryButton}>
                  <Upload size={15} />
                  Thêm ảnh
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    multiple
                    onChange={(event) => {
                      addImages(event.target.files);
                      event.currentTarget.value = "";
                    }}
                    disabled={saving}
                  />
                </label>
              </div>
            </div>
            <div className={styles.featuredTradeBlocks}>
              {editing.contentBlocks.map((block, index) => (
                <div
                  className={styles.featuredTradeBlock}
                  key={`${block.imageUrl ?? "text"}-${index}`}
                >
                  <div className={styles.featuredTradeBlockHeader}>
                    <span>
                      {index + 1}.{" "}
                      {block.type === "text" ? "Đoạn chữ" : "Hình ảnh"}
                    </span>
                    <div>
                      <button
                        type="button"
                        onClick={() => moveBlock(index, -1)}
                        disabled={saving || index === 0}
                        aria-label="Đưa lên"
                      >
                        ↑
                      </button>
                      <button
                        type="button"
                        onClick={() => moveBlock(index, 1)}
                        disabled={
                          saving || index === editing.contentBlocks.length - 1
                        }
                        aria-label="Đưa xuống"
                      >
                        ↓
                      </button>
                      <button
                        type="button"
                        onClick={() => removeBlock(index)}
                        disabled={saving}
                        aria-label="Xóa khối"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                  {block.type === "text" ? (
                    <textarea
                      rows={5}
                      value={block.text ?? ""}
                      onChange={(event) =>
                        patchBlock(index, { text: event.target.value })
                      }
                      placeholder="Viết nội dung phân tích..."
                      disabled={saving}
                    />
                  ) : (
                    <div className={styles.featuredTradeBlockImage}>
                      <Image
                        src={
                          block.previewUrl ??
                          featuredImageUrl(block.imageUrl ?? "")
                        }
                        alt={`Ảnh khối ${index + 1}`}
                        width={800}
                        height={500}
                        unoptimized
                      />
                      <small>{block.file?.name ?? "Ảnh đã tải lên"}</small>
                    </div>
                  )}
                </div>
              ))}
            </div>
            {editing.contentBlocks.length === 0 && (
              <div className={styles.emptyCell}>
                Chưa có nội dung. Hãy thêm chữ hoặc ảnh.
              </div>
            )}
            <label className={styles.checkLabel}>
              <input
                type="checkbox"
                checked={editing.isActive}
                onChange={(event) => setField("isActive", event.target.checked)}
                disabled={saving}
              />
              Hiển thị trên app
            </label>
            {message && (
              <p role="alert" className={styles.formMessage}>
                {message}
              </p>
            )}
            <button className={styles.primaryButton} disabled={saving}>
              <Save size={16} />
              {saving ? "Đang tải và lưu bài viết..." : "Lưu và đẩy lên app"}
            </button>
          </form>
        </ModalBackdrop>
      )}
    </section>
  );
}
function RedNewsPanel({ session }: { session: Session }) {
  const [items, setItems] = useState<RedNews[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [releaseAt, setReleaseAt] = useState("");
  const [syncing, setSyncing] = useState(false);

  useEffect(() => {
    api
      .redNews(session.accessToken)
      .then(setItems)
      .catch((error) =>
        setMessage(
          error instanceof Error
            ? error.message
            : "Không tải được tin quan trọng",
        ),
      )
      .finally(() => setLoading(false));
  }, [session.accessToken]);

  async function syncCalendar() {
    setSyncing(true);
    setMessage("");
    try {
      const result = await api.syncRedNews(session.accessToken);
      const refreshed = await api.redNews(session.accessToken);
      setItems(refreshed);
      setMessage(
        `Đã tự động cập nhật ${result.synced} tin quan trọng từ lịch kinh tế.`,
      );
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Không đồng bộ được lịch kinh tế",
      );
    } finally {
      setSyncing(false);
    }
  }

  async function create(event: FormEvent) {
    event.preventDefault();
    setMessage("");
    try {
      const item = await api.createRedNews(session.accessToken, {
        title,
        description,
        releaseAt: new Date(releaseAt).toISOString(),
      });
      setItems((current) =>
        [...current, item].sort((a, b) =>
          a.releaseAt.localeCompare(b.releaseAt),
        ),
      );
      setTitle("");
      setDescription("");
      setReleaseAt("");
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Không tạo được tin quan trọng",
      );
    }
  }

  async function toggle(item: RedNews) {
    try {
      const updated = await api.updateRedNews(session.accessToken, item.id, {
        isActive: !item.isActive,
      });
      setItems((current) =>
        current.map((entry) => (entry.id === updated.id ? updated : entry)),
      );
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Không cập nhật được tin quan trọng",
      );
    }
  }

  async function remove(id: string) {
    if (!window.confirm("Xóa tin quan trọng này?")) return;
    try {
      await api.deleteRedNews(session.accessToken, id);
      setItems((current) => current.filter((item) => item.id !== id));
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Không xóa được tin quan trọng",
      );
    }
  }

  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <div>
          <p className={styles.eyebrow}>LỊCH CÔNG BỐ QUAN TRỌNG</p>
          <h2>Tin quan trọng trong tuần</h2>
          <p>
            Hệ thống tự lấy tên tin, mã tiền tệ và thời gian từ lịch kinh tế,
            chỉ giữ các tin mức độ cao. Không sao chép nội dung mô tả.
          </p>
        </div>
        <button
          type="button"
          className={styles.secondaryButton}
          onClick={() => void syncCalendar()}
          disabled={syncing}
        >
          <CalendarClock size={16} />
          {syncing ? "Đang cập nhật..." : "Cập nhật ngay"}
        </button>
      </div>
      <form className={styles.newsComposer} onSubmit={create}>
        <div className={styles.newsComposerHeading}>
          <div>
            <strong>Thêm tin thủ công (dự phòng)</strong>
            <small>Dùng khi cần bổ sung hoặc sửa lịch tự động.</small>
          </div>
          <CalendarClock />
        </div>
        <div className={styles.newsFormGrid}>
          <label>
            Tên tin
            <input
              value={title}
              onChange={(event) => setTitle(event.target.value)}
              placeholder="Ví dụ: CPI Hoa Kỳ"
              required
            />
          </label>
          <label>
            Thời gian tin ra
            <input
              type="datetime-local"
              value={releaseAt}
              onChange={(event) => setReleaseAt(event.target.value)}
              required
            />
          </label>
          <label className={styles.newsDescription}>
            Mô tả ngắn
            <textarea
              value={description}
              onChange={(event) => setDescription(event.target.value)}
              placeholder="Thông tin bổ sung cho học viên..."
              rows={3}
            />
          </label>
        </div>
        {message && (
          <div className={styles.panelMessage}>
            {message}
            <button type="button" onClick={() => setMessage("")}>
              <X size={15} />
            </button>
          </div>
        )}
        <button className={styles.primaryButton}>
          <Plus size={17} />
          Lưu tin thủ công
        </button>
      </form>
      <div className={styles.newsListHeader}>
        <div>
          <p className={styles.eyebrow}>DANH SÁCH ĐÃ LÊN LỊCH</p>
          <h3>Tuần này & các tin sắp tới</h3>
        </div>
        <span>{items.length} tin</span>
      </div>
      <div className={styles.newsList}>
        {loading ? (
          <div className={styles.emptyCell}>Đang tải dữ liệu...</div>
        ) : items.length === 0 ? (
          <div className={styles.emptyCell}>Chưa có tin quan trọng nào.</div>
        ) : (
          items.map((item) => (
            <article key={item.id} className={styles.newsItem}>
              <span className={styles.newsDate}>
                {new Intl.DateTimeFormat("vi-VN", {
                  weekday: "short",
                  day: "2-digit",
                  month: "2-digit",
                }).format(new Date(item.releaseAt))}
                <strong>
                  {new Intl.DateTimeFormat("vi-VN", {
                    hour: "2-digit",
                    minute: "2-digit",
                  }).format(new Date(item.releaseAt))}
                </strong>
              </span>
              <div>
                <strong>{item.title}</strong>
                <small>
                  {item.source === "FOREX_FACTORY_CALENDAR"
                    ? `Tự động · ${item.currency || "Không rõ mã"} · Mức độ cao`
                    : item.description || "Nhập thủ công"}
                </small>
              </div>
              <button
                type="button"
                className={`${styles.newsStatus} ${item.isActive ? styles.newsStatusActive : styles.newsStatusOff}`}
                onClick={() => void toggle(item)}
              >
                {item.isActive ? "Đang bật" : "Đã tắt"}
              </button>
              <button
                type="button"
                className={styles.rowAction}
                onClick={() => void remove(item.id)}
                aria-label={`Xóa ${item.title}`}
              >
                <X size={17} />
              </button>
            </article>
          ))
        )}
      </div>
    </section>
  );
}

function SettingsPanel({ session }: { session: Session }) {
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  async function changePassword(event: FormEvent) {
    event.preventDefault();
    if (saving) return;
    setMessage("");
    setError("");
    if (newPassword !== confirmPassword) {
      setError("Mật khẩu mới và phần xác nhận chưa trùng nhau.");
      return;
    }
    if (newPassword.length < 8) {
      setError("Mật khẩu mới cần có ít nhất 8 ký tự.");
      return;
    }

    setSaving(true);
    try {
      const nextSession = await api.changePassword(
        session.accessToken,
        currentPassword,
        newPassword,
      );
      authStore.save(nextSession);
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
      setMessage(
        "Đã đổi mật khẩu quản trị. Phiên đăng nhập hiện tại vẫn được giữ.",
      );
    } catch (changeError) {
      setError(
        changeError instanceof Error
          ? changeError.message
          : "Không đổi được mật khẩu",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <section className={styles.settingsPage}>
      <div className={styles.settingsIntro}>
        <div>
          <p className={styles.eyebrow}>BẢO MẬT QUẢN TRỊ</p>
          <h2>Cài đặt vận hành</h2>
          <p>
            Quản lý thông tin truy cập của tài khoản quản trị đang đăng nhập.
          </p>
        </div>
        <div className={styles.settingsAccount}>
          <ShieldCheck size={19} />
          <span>
            <strong>{session.user.email}</strong>
            <small>Đang đăng nhập với quyền quản trị</small>
          </span>
        </div>
      </div>
      <div className={styles.settingsGrid}>
        <form
          className={styles.settingsCard}
          onSubmit={changePassword}
          aria-busy={saving}
        >
          <div className={styles.settingsCardHeading}>
            <span className={styles.settingsIcon}>
              <LockKeyhole size={19} />
            </span>
            <div>
              <h3>Đổi mật khẩu quản trị</h3>
              <p>Dùng mật khẩu hiện tại để xác nhận thay đổi.</p>
            </div>
          </div>
          <label>
            Mật khẩu hiện tại
            <input
              type="password"
              value={currentPassword}
              onChange={(event) => setCurrentPassword(event.target.value)}
              autoComplete="current-password"
              required
              disabled={saving}
            />
          </label>
          <label>
            Mật khẩu mới
            <input
              type="password"
              value={newPassword}
              onChange={(event) => setNewPassword(event.target.value)}
              autoComplete="new-password"
              minLength={8}
              required
              disabled={saving}
            />
          </label>
          <label>
            Xác nhận mật khẩu mới
            <input
              type="password"
              value={confirmPassword}
              onChange={(event) => setConfirmPassword(event.target.value)}
              autoComplete="new-password"
              minLength={8}
              required
              disabled={saving}
            />
          </label>
          {error && (
            <div className={styles.formMessage} role="alert">
              {error}
            </div>
          )}
          {message && (
            <div className={styles.successMessage} role="status">
              {message}
            </div>
          )}
          <button className={styles.primaryButton} disabled={saving}>
            <Save size={16} />
            {saving ? "Đang cập nhật..." : "Đổi mật khẩu"}
          </button>
        </form>
        <div className={styles.settingsInfo}>
          <div className={styles.settingsInfoArt}>
            <ShieldCheck size={38} />
            <span />
            <span />
          </div>
          <div>
            <p className={styles.eyebrow}>LƯU Ý BẢO MẬT</p>
            <h3>Phiên đăng nhập được bảo vệ</h3>
            <p>
              Đổi mật khẩu sẽ làm mới phiên hiện tại. Các phiên cũ của tài khoản
              này sẽ không còn hợp lệ.
            </p>
            <div>
              <span>
                <Check size={15} />
                Mật khẩu tối thiểu 8 ký tự
              </span>
              <span>
                <Check size={15} />
                Không hiển thị mật khẩu trong hệ thống
              </span>
              <span>
                <Check size={15} />
                Có thể dùng quên mật khẩu qua email
              </span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
