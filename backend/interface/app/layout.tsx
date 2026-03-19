import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { ClerkProvider } from "@clerk/nextjs";
import { auth } from "@clerk/nextjs/server";
import { Header } from "@/components/Header";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Rapid Activity Log Admin",
  description: "Management portal for Rapid backend services",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  let userId = null;
  try {
    const authResult = await auth();
    userId = authResult.userId;
  } catch (error) {
    console.warn("auth() failed (likely due to accessing a path outside basePath):", error);
  }

  return (
    <ClerkProvider>
      <html lang="en">
        <body className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
          <Header isLoggedIn={!!userId} />
          <main>{children}</main>
        </body>
      </html>
    </ClerkProvider>
  );
}
