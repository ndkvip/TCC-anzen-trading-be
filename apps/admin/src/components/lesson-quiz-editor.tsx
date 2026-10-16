"use client";

import { ArrowDown, ArrowUp, ImagePlus, Plus, Trash2, X } from "lucide-react";
import { useRef, useState } from "react";
import styles from "./admin-app.module.css";
import { LessonMediaPreview, type LessonImage } from "./lesson-image-editor";

export type QuizOptionDraft = {
  text: string;
  image?: LessonImage;
};

export type QuizQuestionDraft = {
  key: string;
  question: string;
  image?: LessonImage;
  options: [QuizOptionDraft, QuizOptionDraft, QuizOptionDraft];
  correctIndex: number;
  explanation: string;
};

const emptyOption = (): QuizOptionDraft => ({ text: "" });

export function emptyQuizQuestion(): QuizQuestionDraft {
  return {
    key: crypto.randomUUID(),
    question: "",
    options: [emptyOption(), emptyOption(), emptyOption()],
    correctIndex: 0,
    explanation: "",
  };
}

function imageFrom(value: unknown): LessonImage | undefined {
  return typeof value === "string" && value
    ? { key: crypto.randomUUID(), imageUrl: value }
    : undefined;
}

export function quizDraftsFromApi(values: Record<string, unknown>[]): QuizQuestionDraft[] {
  return values.map((value) => {
    const rawOptions = Array.isArray(value.options) ? value.options : [];
    const options = Array.from({ length: 3 }, (_, index) => {
      const raw = rawOptions[index];
      const option = raw && typeof raw === "object" ? raw as Record<string, unknown> : {};
      return {
        text: typeof option.text === "string" ? option.text : "",
        image: imageFrom(option.imageUrl ?? option.imageLabel),
      };
    }) as [QuizOptionDraft, QuizOptionDraft, QuizOptionDraft];
    const rawCorrectIndex = Number(value.correctIndex);
    return {
      key: crypto.randomUUID(),
      question: typeof value.question === "string" ? value.question : "",
      image: imageFrom(value.imageUrl ?? value.imageLabel),
      options,
      correctIndex: Number.isInteger(rawCorrectIndex) && rawCorrectIndex >= 0 && rawCorrectIndex <= 2 ? rawCorrectIndex : 0,
      explanation: typeof value.explanation === "string" ? value.explanation : "",
    };
  });
}

function validateFile(file: File) {
  return ["image/jpeg", "image/png", "image/webp"].includes(file.type) && file.size <= 10 * 1024 * 1024;
}

function ImagePicker({ image, token, lessonId, label, onChange }: { image?: LessonImage; token: string; lessonId?: string; label: string; onChange: (image?: LessonImage) => void }) {
  const [error, setError] = useState("");
  const fileInputRef = useRef<HTMLInputElement>(null);
  return <div className={styles.quizImagePicker}>
    {image ? <div className={styles.quizImagePreview}>
      <LessonMediaPreview image={image} token={token} lessonId={lessonId} alt={label}/>
      <button type="button" onClick={() => onChange(undefined)} aria-label={`Xóa ${label}`}><X size={15}/></button>
    </div> : <>
      <button type="button" className={styles.quizImageAdd} onClick={() => fileInputRef.current?.click()}>
        <ImagePlus size={17}/>{label}
      </button>
      <input
        ref={fileInputRef}
        className={styles.fileInputHidden}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        onChange={(event) => {
          const file = event.currentTarget.files?.[0];
          event.currentTarget.value = "";
          if (!file) return;
          if (!validateFile(file)) { setError("Chỉ dùng JPEG, PNG, WebP tối đa 10 MB."); return; }
          setError("");
          onChange({ key: crypto.randomUUID(), file });
        }}
      />
    </>}
    {error && <small role="alert" className={styles.quizImageError}>{error}</small>}
  </div>;
}

export function LessonQuizEditor({ questions, onChange, token, lessonId }: { questions: QuizQuestionDraft[]; onChange: (questions: QuizQuestionDraft[]) => void; token: string; lessonId?: string }) {
  function patchQuestion(index: number, patch: Partial<QuizQuestionDraft>) {
    onChange(questions.map((question, current) => current === index ? { ...question, ...patch } : question));
  }
  function patchOption(questionIndex: number, optionIndex: number, patch: Partial<QuizOptionDraft>) {
    const question = questions[questionIndex];
    const options = question.options.map((option, current) => current === optionIndex ? { ...option, ...patch } : option) as QuizQuestionDraft["options"];
    patchQuestion(questionIndex, { options });
  }
  function move(index: number, direction: number) {
    const next = [...questions];
    [next[index], next[index + direction]] = [next[index + direction], next[index]];
    onChange(next);
  }

  return <section className={styles.quizEditor}>
    <div className={styles.quizEditorHeading}><div><h3>Bài tập trắc nghiệm</h3><p>Mỗi câu có đúng 3 đáp án. Câu hỏi và đáp án có thể dùng chữ, hình ảnh hoặc cả hai.</p></div><button type="button" onClick={() => onChange([...questions, emptyQuizQuestion()])}><Plus size={16}/>Thêm câu hỏi</button></div>
    {!questions.length && <div className={styles.quizEmpty}>Chưa có câu hỏi. Bài học vẫn có thể lưu dưới dạng bản nháp.</div>}
    <div className={styles.quizQuestionList}>{questions.map((question, questionIndex) => <article className={styles.quizQuestionCard} key={question.key}>
      <header><div><span>CÂU {questionIndex + 1}</span><strong>Thiết lập nội dung và đáp án đúng</strong></div><div>
        <button type="button" disabled={questionIndex === 0} onClick={() => move(questionIndex, -1)} aria-label="Đưa câu hỏi lên"><ArrowUp size={16}/></button>
        <button type="button" disabled={questionIndex === questions.length - 1} onClick={() => move(questionIndex, 1)} aria-label="Đưa câu hỏi xuống"><ArrowDown size={16}/></button>
        <button type="button" onClick={() => onChange(questions.filter((_, index) => index !== questionIndex))} aria-label="Xóa câu hỏi"><Trash2 size={16}/></button>
      </div></header>
      <div className={styles.quizQuestionContent}>
        <label>Nội dung câu hỏi<textarea rows={2} value={question.question} onChange={(event) => patchQuestion(questionIndex, { question: event.target.value })} placeholder="Nhập câu hỏi hoặc chỉ sử dụng hình ảnh..."/></label>
        <ImagePicker image={question.image} token={token} lessonId={lessonId} label="Thêm ảnh câu hỏi" onChange={(image) => patchQuestion(questionIndex, { image })}/>
      </div>
      <div className={styles.quizOptions}>{question.options.map((option, optionIndex) => <div className={`${styles.quizOptionRow} ${question.correctIndex === optionIndex ? styles.quizOptionCorrect : ""}`} key={optionIndex}>
        <label className={styles.quizCorrectChoice}><input type="radio" name={`correct-${question.key}`} checked={question.correctIndex === optionIndex} onChange={() => patchQuestion(questionIndex, { correctIndex: optionIndex })}/><span>{String.fromCharCode(65 + optionIndex)}</span></label>
        <label>Đáp án {optionIndex + 1}<input value={option.text} onChange={(event) => patchOption(questionIndex, optionIndex, { text: event.target.value })} placeholder="Nhập chữ hoặc chọn ảnh..."/></label>
        <ImagePicker image={option.image} token={token} lessonId={lessonId} label="Thêm ảnh" onChange={(image) => patchOption(questionIndex, optionIndex, { image })}/>
      </div>)}</div>
      <label className={styles.quizExplanation}>Giải thích sau khi trả lời<textarea rows={2} value={question.explanation} onChange={(event) => patchQuestion(questionIndex, { explanation: event.target.value })} placeholder="Giải thích ngắn gọn vì sao đáp án đúng..."/></label>
    </article>)}</div>
  </section>;
}
