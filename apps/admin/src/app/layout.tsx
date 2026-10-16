import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ANZEN TRADING Admin",
  description: "Bảng điều khiển vận hành ANZEN TRADING",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="vi">
      <body>{children}</body>
    </html>
  );
}
