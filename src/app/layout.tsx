import type { Metadata } from "next";
import { Navbar } from "@/components/Navbar";
import "./globals.css";

export const metadata: Metadata = {
  title: "MediChain — Medical Records on Stellar",
  description:
    "Immutable, append-only medical records secured on the Stellar blockchain. Patients control access; authorized doctors append records.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <Navbar />
        <main className="max-w-6xl mx-auto px-4 py-8">{children}</main>
      </body>
    </html>
  );
}
