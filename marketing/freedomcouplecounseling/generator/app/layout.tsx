import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Freedom Couple Counselling — Marketing Generator",
  description:
    "AI-powered marketing copy and image prompt generator for Freedom Couple Counselling by Jill Dzadey.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
