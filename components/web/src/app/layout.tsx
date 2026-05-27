import type { Metadata } from "next";
import { Navbar } from "@/components/Navbar";
import "./globals.css";

export const metadata: Metadata = {
  title: "MediChain — Registros Médicos en Stellar",
  description:
    "Registros médicos inmutables y de solo añadir asegurados en la blockchain Stellar. Los pacientes controlan el acceso; los doctores autorizados añaden registros.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="es">
      <body>
        <Navbar />
        <main className="max-w-6xl mx-auto px-4 py-8">{children}</main>
      </body>
    </html>
  );
}
