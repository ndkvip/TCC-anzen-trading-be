export type LearningTier = "BASIC" | "ADVANCED";
export type AccountTier = "STANDARD" | "VIP1" | "VIP2";
export type UserRole = "ADMIN" | "STUDENT";

export type User = {
  id: string;
  email: string;
  name: string;
  role: UserRole;
  accountTier: AccountTier;
  learningTier: LearningTier;
  emailVerified: boolean;
  isActive: boolean;
  createdAt: string;
};

export type Session = {
  accessToken: string;
  refreshToken: string;
  user: User;
};

export type RedNews = {
  id: string;
  title: string;
  description: string | null;
  currency: string | null;
  impact: "LOW" | "MEDIUM" | "HIGH";
  source: "MANUAL" | "FOREX_FACTORY_CALENDAR";
  releaseAt: string;
  isActive: boolean;
};

export type Lesson = {
  id: string;
  slug: string;
  title: string;
  description: string;
  tier: LearningTier;
  position: number;
  durationMinutes: number;
  isPublished: boolean;
  knowledgeCards: Record<string, unknown>[];
  questions: Record<string, unknown>[];
  updatedAt?: string;
};

export type TradeJournal = {
  id: string;
  userId: string;
  mode: "INTRA_DAY" | "SWING";
  tradeDate: string | null;
  symbol: string;
  direction: "LONG" | "SHORT";
  pnl: number | null;
  riskReward: number | null;
  timeframePair: string | null;
  priceMovement: string | null;
  management: string;
  updatedAt: string;
  idea?: string | null;
  execution?: string | null;
  result?: string | null;
  notesDelta?: Record<string, unknown>[];
  processImageUrls?: string[];
};

export type TradingPlan = {
  id: string;
  userId: string;
  scope: "DAY" | "WEEK" | "MONTH";
  periodKey: string;
  title: string;
  status?: "DRAFT" | "COMPLETED";
  timeframePairs: string[];
  updatedAt: string;
};

export type FeaturedTradeBlock = {
  type: "text" | "image";
  text?: string;
  imageUrl?: string;
};

export type FeaturedTrade = {
  id: string;
  weekStart: string;
  title: string;
  summary: string | null;
  coverImageUrl: string | null;
  contentBlocks: FeaturedTradeBlock[];
  imageUrls: string[];
  isActive: boolean;
  createdAt?: string;
  updatedAt?: string;
};

export type DailyCheckin = {
  id: string;
  userId: string;
  checkinDate: string;
  scores: number[];
  totalScore: number;
};

export type MediaContextType =
  | "LEARNING_LESSON"
  | "LEARNING_QUESTION"
  | "LEARNING_ANSWER"
  | "JOURNAL"
  | "PLAN"
  | "FEATURED_TRADE"
  | "GENERAL";

export type MediaAsset = {
  id: string;
  ownerId: string;
  driveFileId: string | null;
  driveFolderId: string | null;
  folderPath: string;
  name: string;
  mimeType: string;
  remoteUrl: string;
  thumbnailUrl: string | null;
  localReference: string | null;
  sizeBytes: string | number;
  contextType: MediaContextType;
  contextId: string | null;
  createdAt: string;
  owner: { id: string; name: string | null; email: string | null };
  storageStatus: "DRIVE" | "EXTERNAL";
  previewPath: string | null;
};

export type MediaListResponse = {
  data: MediaAsset[];
  total: number;
  page: number;
  pageSize: number;
};

export type DashboardData = {
  studentCount: number;
  lessonCount: number;
  startedLessons: number;
  completedLessons: number;
  draftLessons: number;
  incompleteLessons: number;
  inactiveStudents: number;
  unverifiedStudents: number;
  completionRate: number;
  activity: { date: string; activeStudents: number }[];
  timezone: string;
  generatedAt: string;
};

export const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:3001/api";
const ACCESS_KEY = "ttc_admin_access_token";
const REFRESH_KEY = "ttc_admin_refresh_token";
const DEVICE_KEY = "ttc_admin_device_id";
const authListeners = new Set<(session: Session | null) => void>();

function notifyAuthListeners(session: Session | null) {
  authListeners.forEach((listener) => listener(session));
}

function deviceId() {
  let value = localStorage.getItem(DEVICE_KEY);
  if (!value) {
    value = `admin-${crypto.randomUUID()}`;
    localStorage.setItem(DEVICE_KEY, value);
  }
  return value;
}

async function parseResponse<T>(response: Response): Promise<T> {
  if (response.ok && response.headers.get("content-type")?.startsWith("image/"))
    return (await response.blob()) as T;
  const data = (await response.json().catch(() => ({}))) as Record<
    string,
    unknown
  >;
  if (response.ok) return data as T;
  const rawMessage = data.message;
  const message = Array.isArray(rawMessage)
    ? rawMessage.join(". ")
    : typeof rawMessage === "string"
      ? rawMessage
      : "Không thể kết nối máy chủ";
  throw new ApiError(message, response.status);
}

async function rawRequest<T>(
  path: string,
  init?: RequestInit,
  token?: string,
): Promise<T> {
  return parseResponse<T>(
    await fetch(`${API_BASE_URL}${path}`, {
      ...init,
      headers: {
        ...(init?.body instanceof FormData
          ? {}
          : { "Content-Type": "application/json" }),
        ...init?.headers,
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
    }),
  );
}

async function request<T>(
  path: string,
  init?: RequestInit,
  token?: string,
): Promise<T> {
  if (!token) return rawRequest<T>(path, init);

  const activeToken = authStore.access() ?? token;
  try {
    return await rawRequest<T>(path, init, activeToken);
  } catch (error) {
    if (!(error instanceof ApiError) || error.status !== 401) throw error;
    const refreshToken = authStore.refresh();
    if (!refreshToken) {
      authStore.clear();
      throw error;
    }
    try {
      const session = await rawRequest<Session>("/auth/refresh", {
        method: "POST",
        body: JSON.stringify({ refreshToken, deviceId: deviceId() }),
      });
      authStore.save(session);
      return await rawRequest<T>(path, init, session.accessToken);
    } catch (refreshError) {
      authStore.clear();
      throw refreshError;
    }
  }
}

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}

export function mediaUrl(path: string) {
  if (/^(https?:|blob:|data:)/i.test(path)) return path;
  return `${API_BASE_URL}${path.startsWith("/") ? path : `/${path}`}`;
}

export const authStore = {
  save(session: Session) {
    localStorage.setItem(ACCESS_KEY, session.accessToken);
    localStorage.setItem(REFRESH_KEY, session.refreshToken);
    notifyAuthListeners(session);
  },
  clear() {
    localStorage.removeItem(ACCESS_KEY);
    localStorage.removeItem(REFRESH_KEY);
    notifyAuthListeners(null);
  },
  subscribe(listener: (session: Session | null) => void) {
    authListeners.add(listener);
    return () => {
      authListeners.delete(listener);
    };
  },
  access() {
    return localStorage.getItem(ACCESS_KEY);
  },
  refresh() {
    return localStorage.getItem(REFRESH_KEY);
  },
};

export const api = {
  login(email: string, password: string) {
    return request<Session>("/auth/login", {
      method: "POST",
      body: JSON.stringify({ email, password, deviceId: deviceId() }),
    });
  },
  forgotPassword(email: string) {
    return request<{ message: string }>("/auth/forgot-password", {
      method: "POST",
      body: JSON.stringify({ email }),
    });
  },
  resetPassword(token: string, newPassword: string) {
    return request<{ success: true }>("/auth/reset-password", {
      method: "POST",
      body: JSON.stringify({ token, newPassword }),
    });
  },
  changePassword(
    accessToken: string,
    currentPassword: string,
    newPassword: string,
  ) {
    return request<Session>(
      "/auth/change-password",
      {
        method: "POST",
        body: JSON.stringify({ currentPassword, newPassword }),
      },
      accessToken,
    );
  },
  async restoreSession(): Promise<Session | null> {
    const accessToken = authStore.access();
    const refreshToken = authStore.refresh();
    if (!accessToken || !refreshToken) return null;
    try {
      const user = await request<User>("/auth/me", undefined, accessToken);
      return { accessToken, refreshToken, user };
    } catch (error) {
      if (!(error instanceof ApiError) || error.status !== 401) throw error;
      try {
        const session = await request<Session>("/auth/refresh", {
          method: "POST",
          body: JSON.stringify({ refreshToken, deviceId: deviceId() }),
        });
        authStore.save(session);
        return session;
      } catch {
        authStore.clear();
        return null;
      }
    }
  },
  async logout(accessToken: string | null) {
    if (accessToken) {
      await request("/auth/logout", { method: "POST" }, accessToken).catch(
        () => undefined,
      );
    }
    authStore.clear();
  },
  users(accessToken: string) {
    return request<User[]>("/users", undefined, accessToken);
  },
  createUser(
    accessToken: string,
    payload: {
      email: string;
      name: string;
      password: string;
      accountTier: AccountTier;
    },
  ) {
    return request<User>(
      "/users",
      { method: "POST", body: JSON.stringify(payload) },
      accessToken,
    );
  },
  updateUser(
    accessToken: string,
    id: string,
    payload: { name?: string; accountTier?: AccountTier; isActive?: boolean },
  ) {
    return request<User>(
      `/users/${id}`,
      { method: "PATCH", body: JSON.stringify(payload) },
      accessToken,
    );
  },
  redNews(accessToken: string) {
    return request<RedNews[]>("/red-news/admin", undefined, accessToken);
  },
  syncRedNews(accessToken: string) {
    return request<{ synced: number; skipped: boolean }>(
      "/red-news/sync",
      { method: "POST" },
      accessToken,
    );
  },
  createRedNews(
    accessToken: string,
    payload: { title: string; description?: string; releaseAt: string },
  ) {
    return request<RedNews>(
      "/red-news",
      { method: "POST", body: JSON.stringify(payload) },
      accessToken,
    );
  },
  updateRedNews(
    accessToken: string,
    id: string,
    payload: {
      title?: string;
      description?: string;
      releaseAt?: string;
      isActive?: boolean;
    },
  ) {
    return request<RedNews>(
      `/red-news/${id}`,
      { method: "PATCH", body: JSON.stringify(payload) },
      accessToken,
    );
  },
  deleteRedNews(accessToken: string, id: string) {
    return request<{ success: true }>(
      `/red-news/${id}`,
      { method: "DELETE" },
      accessToken,
    );
  },
  lessons(accessToken: string) {
    return request<Lesson[]>("/learning/admin/lessons", undefined, accessToken);
  },
  createLesson(accessToken: string, payload: Partial<Lesson>) {
    return request<Lesson>(
      "/learning/admin/lessons",
      { method: "POST", body: JSON.stringify(payload) },
      accessToken,
    );
  },
  uploadLessonImage(accessToken: string, lessonId: string, file: File) {
    const form = new FormData();
    form.append("file", file);
    return request<{ imageUrl: string }>(
      `/learning/admin/lessons/${lessonId}/images`,
      { method: "POST", body: form },
      accessToken,
    );
  },
  uploadLessonExerciseImage(
    accessToken: string,
    lessonId: string,
    file: File,
    mediaContext: "LEARNING_QUESTION" | "LEARNING_ANSWER" = "LEARNING_QUESTION",
  ) {
    const form = new FormData();
    form.append("file", file);
    form.append("mediaContext", mediaContext);
    return request<{ imageUrl: string }>(
      `/learning/admin/lessons/${lessonId}/exercise-images`,
      { method: "POST", body: form },
      accessToken,
    );
  },
  lessonImage(accessToken: string, imageUrl: string): Promise<Blob> {
    if (imageUrl.startsWith("/learning/"))
      return request<Blob>(imageUrl, undefined, accessToken);
    return fetch(imageUrl).then((response) => {
      if (!response.ok) throw new Error("Không tải được ảnh");
      return response.blob();
    });
  },
  updateLesson(accessToken: string, id: string, payload: Partial<Lesson>) {
    return request<Lesson>(
      `/learning/admin/lessons/${id}`,
      { method: "PATCH", body: JSON.stringify(payload) },
      accessToken,
    );
  },
  deleteLesson(accessToken: string, id: string) {
    return request<{ success: true }>(
      `/learning/admin/lessons/${id}`,
      { method: "DELETE" },
      accessToken,
    );
  },
  studentJournals(accessToken: string, userId: string) {
    return request<TradeJournal[]>(
      `/journal/admin/all?userId=${encodeURIComponent(userId)}`,
      undefined,
      accessToken,
    );
  },
  journalImage(accessToken: string, fileId: string) {
    return request<Blob>(
      `/media/drive-images/${encodeURIComponent(fileId)}`,
      undefined,
      accessToken,
    );
  },
  mediaLibrary(
    accessToken: string,
    input: {
      page: number;
      pageSize: number;
      search?: string;
      ownerId?: string;
      contextType?: MediaContextType;
    },
  ) {
    const params = new URLSearchParams({
      page: String(input.page),
      pageSize: String(input.pageSize),
    });
    if (input.search?.trim()) params.set("search", input.search.trim());
    if (input.ownerId) params.set("ownerId", input.ownerId);
    if (input.contextType) params.set("contextType", input.contextType);
    return request<MediaListResponse>(
      `/media/admin/all?${params.toString()}`,
      undefined,
      accessToken,
    );
  },
  mediaImage(accessToken: string, path: string) {
    return request<Blob>(path, undefined, accessToken);
  },
  dashboard(accessToken: string) {
    return request<DashboardData>("/admin/dashboard", undefined, accessToken);
  },
  studentPlans(accessToken: string, userId: string) {
    return request<TradingPlan[]>(
      `/plans/admin/all?userId=${encodeURIComponent(userId)}`,
      undefined,
      accessToken,
    );
  },
  studentCheckins(accessToken: string, userId: string) {
    return request<DailyCheckin[]>(
      `/checkins/admin/all?userId=${encodeURIComponent(userId)}`,
      undefined,
      accessToken,
    );
  },
  featuredTrades(accessToken: string) {
    return request<FeaturedTrade[]>(
      "/featured-trades/admin",
      undefined,
      accessToken,
    );
  },
  uploadFeaturedTradeImages(
    accessToken: string,
    files: File[],
    weekStart: string,
  ) {
    const form = new FormData();
    form.append("weekStart", weekStart);
    files.forEach((file) => form.append("files", file));
    return request<{ imageUrls: string[] }>(
      "/featured-trades/uploads",
      { method: "POST", body: form },
      accessToken,
    );
  },
  createFeaturedTrade(
    accessToken: string,
    payload: {
      weekStart: string;
      title: string;
      summary?: string;
      coverImageUrl?: string;
      contentBlocks: FeaturedTradeBlock[];
      isActive?: boolean;
    },
  ) {
    return request<FeaturedTrade>(
      "/featured-trades",
      { method: "POST", body: JSON.stringify(payload) },
      accessToken,
    );
  },
  updateFeaturedTrade(
    accessToken: string,
    id: string,
    payload: Partial<{
      weekStart: string;
      title: string;
      summary: string;
      coverImageUrl: string;
      contentBlocks: FeaturedTradeBlock[];
      isActive: boolean;
    }>,
  ) {
    return request<FeaturedTrade>(
      `/featured-trades/${id}`,
      { method: "PATCH", body: JSON.stringify(payload) },
      accessToken,
    );
  },
  deleteFeaturedTrade(accessToken: string, id: string) {
    return request<{ success: true }>(
      `/featured-trades/${id}`,
      { method: "DELETE" },
      accessToken,
    );
  },
};
