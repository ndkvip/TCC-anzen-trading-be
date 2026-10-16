"use client";

import { useEffect, useRef, useState } from "react";
import { ArrowLeft, ArrowRight, Trash2 } from "lucide-react";
import { api } from "@/lib/api";
import styles from "./admin-app.module.css";

export type LessonImage = { key: string; imageUrl?: string; file?: File };

function driveFileId(value?: string) {
  if (!value) return "";
  // Support both URLs returned by Drive's upload API and older /file/d/... URLs.
  try {
    const url = new URL(value);
    const queryId = url.searchParams.get("id");
    if (queryId) return queryId;
    const match = url.pathname.match(/\/file\/d\/([^/]+)/);
    return match?.[1] ?? "";
  } catch {
    // A previously saved record may contain the raw Drive file ID.
    return /^[A-Za-z0-9_-]{10,}$/.test(value) ? value : "";
  }
}

export function LessonMediaPreview({ image, token, alt, lessonId }: { image: LessonImage; token: string; alt: string; lessonId?: string }) {
  const [blobPreview, setBlobPreview] = useState<{ key: string; source: string; failed: boolean }>({
    key: "",
    source: "",
    failed: false,
  });
  const imageUrl = image.imageUrl;
  const driveId = driveFileId(imageUrl);
  const proxyUrl = driveId && lessonId
    ? `/learning/lessons/${lessonId}/drive-images/${encodeURIComponent(driveId)}`
    : imageUrl;
  const directSource = !image.file && proxyUrl && !proxyUrl.startsWith("/learning/") ? proxyUrl : "";

  useEffect(() => {
    let cancelled = false;
    let objectUrl = "";
    // Drive blocks cross-origin image embedding with CORP headers. Fetching
    // through the authenticated API keeps previews reliable and private.
    if (directSource) return () => { cancelled = true; };
    const load = async () => {
      try {
        const blob = image.file ?? await api.lessonImage(token, proxyUrl!);
        objectUrl = URL.createObjectURL(blob);
        if (!cancelled) setBlobPreview({ key: image.key, source: objectUrl, failed: false });
        else URL.revokeObjectURL(objectUrl);
      } catch {
        if (!cancelled) setBlobPreview({ key: image.key, source: "", failed: true });
      }
    };
    void load();
    return () => { cancelled = true; if (objectUrl) URL.revokeObjectURL(objectUrl); };
  }, [directSource, image.file, image.key, proxyUrl, token]);

  const source = directSource || (blobPreview.key === image.key ? blobPreview.source : "");
  const failed = !directSource && blobPreview.key === image.key && blobPreview.failed;
  // Blob previews include authenticated lesson images; Next image optimization cannot fetch them.
  // eslint-disable-next-line @next/next/no-img-element
  return source ? <img src={source} alt={alt} /> : <span>{failed ? "Không tải được ảnh" : "Đang tải ảnh..."}</span>;
}

export function LessonImageEditor({ images, onChange, token, lessonId }: { images: LessonImage[]; onChange: (images: LessonImage[]) => void; token: string; lessonId?: string }) {
  const [error, setError] = useState("");
  const fileInputRef = useRef<HTMLInputElement>(null);
  function move(index: number, direction: number) {
    const next = [...images];
    [next[index], next[index + direction]] = [next[index + direction], next[index]];
    onChange(next);
  }
  return <section className={styles.mediaEditor}>
    <h3>Ảnh kiến thức</h3>
    <p>Mỗi ảnh là một thẻ. Tải ảnh lên và sắp xếp thứ tự, không cần nhập nội dung chữ.</p>
    <button
      type="button"
      className={styles.mediaUploadButton} aria-label="Chọn ảnh từ máy"
      onClick={() => fileInputRef.current?.click()}
    >
      Chọn ảnh từ máy
    </button>
    <input
      ref={fileInputRef}
      className={styles.fileInputHidden}
      type="file"
      accept="image/jpeg,image/png,image/webp"
      multiple
      onChange={(event) => {
        const files = Array.from(event.currentTarget.files ?? []);
        event.currentTarget.value = "";
        if (!files.length) return;
        if (files.some((file) => !["image/jpeg", "image/png", "image/webp"].includes(file.type) || file.size > 10 * 1024 * 1024)) {
          setError("Chỉ chọn ảnh JPEG, PNG, WebP không quá 10 MB mỗi ảnh."); return;
        }
        if (files.length + images.length > 60) { setError("Mỗi bài tối đa 60 ảnh."); return; }
        setError("");
        onChange([...images, ...files.map((file) => ({ key: crypto.randomUUID(), file }))]);
      }}
    />
    {error && <p role="alert">{error}</p>}
    {!images.length && <p>Chưa có ảnh. Thêm ít nhất một ảnh để xuất bản bài học.</p>}
    <div className={styles.mediaPreview}>{images.map((image, index) => <article className={styles.mediaThumb} key={image.key}>
      <LessonMediaPreview image={image} token={token} lessonId={lessonId} alt={`Ảnh kiến thức ${index + 1}`}/>
      <small>Thẻ {index + 1}{image.file ? ` · ${image.file.name}` : ""}</small>
      <div><button type="button" aria-label={`Đưa ảnh ${index + 1} lên trước`} disabled={index === 0} onClick={() => move(index, -1)}><ArrowLeft size={16}/></button>
        <button type="button" aria-label={`Đưa ảnh ${index + 1} ra sau`} disabled={index === images.length - 1} onClick={() => move(index, 1)}><ArrowRight size={16}/></button>
        <button type="button" aria-label={`Xóa ảnh ${index + 1}`} onClick={() => onChange(images.filter((_, i) => i !== index))}><Trash2 size={16}/></button></div>
    </article>)}</div>
  </section>;
}
